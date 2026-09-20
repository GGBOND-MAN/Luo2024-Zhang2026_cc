function result = fittedSnrDiagnostics(cfg, observation, snapshots, ...
    carrierIndex, front, music, scan)
%FITTEDSNRDIAGNOSTICS Estimate two truth-free residual SNR values.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    snapshots (:, :) double
    carrierIndex (:, 1) double
    front (1, 1) struct
    music (1, 1) struct
    scan (1, 1) struct = fsjad.prepareScan(cfg)
end

if numel(observation) ~= cfg.numSubcarriers
    error("fsjad:fittedSnrDiagnostics:ObservationSize", ...
        "The observation must contain cfg.numSubcarriers samples.");
end
if size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= numel(carrierIndex)
    error("fsjad:fittedSnrDiagnostics:SnapshotSize", ...
        "Snapshot dimensions do not match cfg and carrierIndex.");
end

frontResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(front.thetaDeg), front.rangeM, scan);
frontGain = frontResponse' * observation / real(frontResponse' * frontResponse);
frontResidual = observation - frontGain * frontResponse;
frontNoiseVariance = sum(abs(frontResidual).^2) ...
    / max(numel(observation) - 4, 1);
frontSignalPower = mean(abs(frontGain * frontResponse).^2);

[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
numCarriers = numel(carrierIndex);
snapshotResidualPower = 0;
snapshotSignalPower = 0;
for carrierPosition = 1:numCarriers
    signal = sqrt(cfg.numAntennas) * jad.steeringVector(cfg, ...
        music.thetaDeg, front.rangeM, frequencyHz(carrierPosition));
    gain = signal' * snapshots(:, carrierPosition) / real(signal' * signal);
    residual = snapshots(:, carrierPosition) - gain * signal;
    snapshotResidualPower = snapshotResidualPower + sum(abs(residual).^2);
    snapshotSignalPower = snapshotSignalPower + sum(abs(gain * signal).^2);
end
snapshotNoiseVariance = snapshotResidualPower ...
    / max((cfg.numAntennas - 1) * numCarriers, 1);
snapshotSignalPower = snapshotSignalPower / (cfg.numAntennas * numCarriers);

result.frontSnrDb = 10 * log10(max(frontSignalPower, eps) ...
    / max(frontNoiseVariance, eps));
result.snapshotSnrDb = 10 * log10(max(snapshotSignalPower, eps) ...
    / max(snapshotNoiseVariance, eps));
result.frontNoiseVariance = frontNoiseVariance;
result.snapshotNoiseVariance = snapshotNoiseVariance;
end
