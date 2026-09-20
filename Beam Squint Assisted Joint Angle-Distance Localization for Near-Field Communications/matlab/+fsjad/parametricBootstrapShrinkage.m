function result = parametricBootstrapShrinkage(cfg, observation, ...
    snapshots, carrierIndex, front, music, scan, bootstrapCount, ...
    bootstrapCarrierCount, stream)
%PARAMETRICBOOTSTRAPSHRINKAGE Estimate alpha from fitted-model replicates.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    snapshots (:, :) double
    carrierIndex (:, 1) double
    front (1, 1) struct
    music (1, 1) struct
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    bootstrapCount (1, 1) double {mustBeInteger, ...
        mustBeGreaterThanOrEqual(bootstrapCount, 4)} = 16
    bootstrapCarrierCount (1, 1) double {mustBeInteger, ...
        mustBePositive} = numel(carrierIndex)
    stream = RandStream.getGlobalStream
end

if numel(observation) ~= cfg.numSubcarriers
    error("fsjad:parametricBootstrapShrinkage:ObservationSize", ...
        "The observation must contain cfg.numSubcarriers samples.");
end
if size(snapshots, 1) ~= cfg.numAntennas
    error("fsjad:parametricBootstrapShrinkage:SnapshotSize", ...
        "Snapshots must contain cfg.numAntennas rows.");
end
if size(snapshots, 2) ~= numel(carrierIndex)
    error("fsjad:parametricBootstrapShrinkage:CarrierCount", ...
        "Snapshot columns and carrierIndex must have equal length.");
end
if bootstrapCarrierCount > numel(carrierIndex)
    error("fsjad:parametricBootstrapShrinkage:BootstrapCarrierCount", ...
        "bootstrapCarrierCount cannot exceed the available carriers.");
end

snrDiagnostics = fsjad.fittedSnrDiagnostics(cfg, observation, ...
    snapshots, carrierIndex, front, music, scan);
frontResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(front.thetaDeg), front.rangeM, scan);
frontGain = frontResponse' * observation / real(frontResponse' * frontResponse);
frontResidual = observation - frontGain * frontResponse;
frontDegreesOfFreedom = max(numel(observation) - 4, 1);
frontNoiseVariance = sum(abs(frontResidual).^2) / frontDegreesOfFreedom;

% The current best hybrid point supplies a truth-free common bootstrap center.
centerThetaDeg = music.thetaDeg;
centerRangeM = front.rangeM;
centerResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(centerThetaDeg), centerRangeM, scan);
[~, ~, fullFrequencyHz] = jad.trajectory(cfg, carrierIndex);
numCarriers = numel(carrierIndex);
bootstrapCarrierPosition = unique(round(linspace( ...
    1, numCarriers, bootstrapCarrierCount))).';
bootstrapCarrierIndex = carrierIndex(bootstrapCarrierPosition);
bootstrapCarrierCount = numel(bootstrapCarrierPosition);
snapshotSignal = complex(zeros(cfg.numAntennas, numCarriers));
snapshotGain = complex(zeros(numCarriers, 1));
snapshotResidualPower = 0;
for carrierPosition = 1:numCarriers
    signal = sqrt(cfg.numAntennas) * jad.steeringVector(cfg, ...
        centerThetaDeg, centerRangeM, fullFrequencyHz(carrierPosition));
    gain = signal' * snapshots(:, carrierPosition) / real(signal' * signal);
    residual = snapshots(:, carrierPosition) - gain * signal;
    snapshotSignal(:, carrierPosition) = signal;
    snapshotGain(carrierPosition) = gain;
    snapshotResidualPower = snapshotResidualPower + sum(abs(residual).^2);
end
snapshotDegreesOfFreedom = max((cfg.numAntennas - 1) * numCarriers, 1);
snapshotNoiseVariance = snapshotResidualPower / snapshotDegreesOfFreedom;
bootstrapSignal = snapshotSignal(:, bootstrapCarrierPosition);
bootstrapGain = snapshotGain(bootstrapCarrierPosition);

frontRangeReplicateM = zeros(bootstrapCount, 1);
musicRangeReplicateM = zeros(bootstrapCount, 1);
frontThetaReplicateDeg = zeros(bootstrapCount, 1);
musicThetaReplicateDeg = zeros(bootstrapCount, 1);
sampleIndex = (1:cfg.numSubcarriers).';
snapshotMean = bootstrapSignal .* bootstrapGain.';
for bootstrapIndex = 1:bootstrapCount
    frontNoise = sqrt(frontNoiseVariance / 2) * (randn(stream, ...
        cfg.numSubcarriers, 1) + 1i * randn(stream, ...
        cfg.numSubcarriers, 1));
    bootstrapObservation = frontGain * centerResponse + frontNoise;
    snapshotNoise = sqrt(snapshotNoiseVariance / 2) * (randn(stream, ...
        cfg.numAntennas, bootstrapCarrierCount) + 1i * randn(stream, ...
        cfg.numAntennas, bootstrapCarrierCount));
    bootstrapSnapshots = snapshotMean + snapshotNoise;
    frontReplicate = fsjad.subsetProfileEstimate(cfg, ...
        bootstrapObservation, sampleIndex, centerThetaDeg, centerRangeM, scan);
    musicReplicate = jad.localMusicEstimate(cfg, bootstrapSnapshots, ...
        bootstrapCarrierIndex, frontReplicate.thetaDeg, ...
        frontReplicate.rangeM);
    frontRangeReplicateM(bootstrapIndex) = frontReplicate.rangeM;
    musicRangeReplicateM(bootstrapIndex) = musicReplicate.rangeM;
    frontThetaReplicateDeg(bootstrapIndex) = frontReplicate.thetaDeg;
    musicThetaReplicateDeg(bootstrapIndex) = musicReplicate.thetaDeg;
end

result = fsjad.covarianceRangeShrinkage( ...
    frontRangeReplicateM, musicRangeReplicateM);
[scaledRawAlpha, scaledIndependentAlpha, regressionTransfer, ...
    scaledMusicInnovationVariance] = carrierScaledAlpha( ...
    frontRangeReplicateM, musicRangeReplicateM, ...
    bootstrapCarrierCount / numCarriers);
result.scaledRawAlpha = scaledRawAlpha;
result.scaledIndependentAlpha = scaledIndependentAlpha;
result.regressionTransfer = regressionTransfer;
result.scaledMusicInnovationVariance = scaledMusicInnovationVariance;
result.frontNoiseVariance = frontNoiseVariance;
result.snapshotNoiseVariance = snapshotNoiseVariance;
result.frontSnrDb = snrDiagnostics.frontSnrDb;
result.snapshotSnrDb = snrDiagnostics.snapshotSnrDb;
result.centerThetaDeg = centerThetaDeg;
result.centerRangeM = centerRangeM;
result.frontThetaReplicateDeg = frontThetaReplicateDeg;
result.musicThetaReplicateDeg = musicThetaReplicateDeg;
result.bootstrapCount = bootstrapCount;
result.bootstrapCarrierCount = bootstrapCarrierCount;
result.fullCarrierCount = numCarriers;
end

function [rawAlpha, independentAlpha, transfer, innovationVariance] = ...
    carrierScaledAlpha(frontRangeM, musicRangeM, carrierFraction)
frontCentered = frontRangeM - mean(frontRangeM);
musicCentered = musicRangeM - mean(musicRangeM);
frontVariance = mean(frontCentered.^2);
if frontVariance <= eps
    rawAlpha = 0;
    independentAlpha = 0;
    transfer = 0;
    innovationVariance = 0;
    return;
end
frontMusicCovariance = mean(frontCentered .* musicCentered);
transfer = frontMusicCovariance / frontVariance;
innovation = musicCentered - transfer * frontCentered;
innovationVariance = carrierFraction * mean(innovation.^2);
musicVariance = transfer^2 * frontVariance + innovationVariance;
rawNumerator = frontVariance * (1 - transfer);
rawDenominator = frontVariance * (1 - transfer)^2 ...
    + innovationVariance;
rawAlpha = min(max(rawNumerator / max(rawDenominator, eps), 0), 1);
independentAlpha = min(max(frontVariance / ...
    max(frontVariance + musicVariance, eps), 0), 1);
end
