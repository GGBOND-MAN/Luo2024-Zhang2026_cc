function result = simulateSnrReleaseTrial(cfg, scan, snrDb, ...
    fusionCarriers, frontOffsetsDeg, baseSeed)
%SIMULATESNRRELEASETRIAL Simulate one front/MUSIC/SNR diagnostic trial.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    snrDb (1, 1) double
    fusionCarriers (1, 1) double {mustBeInteger, mustBePositive}
    frontOffsetsDeg (:, 1) double
    baseSeed (1, 1) double {mustBeInteger, mustBePositive}
end

truthThetaDeg = 15;
truthRangeM = 30;
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
noiseVariance = signalPower / 10^(snrDb / 10);
stream = RandStream("mt19937ar", Seed=baseSeed);
beta = exp(1i * 2 * pi * rand(stream));
noise = sqrt(noiseVariance / 2) * (randn(stream, ...
    cfg.numSubcarriers, 1) + 1i * randn(stream, ...
    cfg.numSubcarriers, 1));
observation = beta * truthResponse + noise;
[~, peakPosition] = max(abs(observation).^2);
carrierIndex = fixedCountWindow(peakPosition - 1, fusionCarriers, ...
    cfg.numSubcarriers);
front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
    frontOffsetsDeg);
snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, truthRangeM, ...
    snrDb, carrierIndex, stream);
music = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);
diagnostics = fsjad.fittedSnrDiagnostics(cfg, observation, snapshots, ...
    carrierIndex, front, music, scan);

result.frontAngleErrorDeg = front.thetaDeg - truthThetaDeg;
result.frontRangeErrorM = front.rangeM - truthRangeM;
result.musicAngleErrorDeg = music.thetaDeg - truthThetaDeg;
result.musicRangeErrorM = music.rangeM - truthRangeM;
result.frontSnrDb = diagnostics.frontSnrDb;
result.snapshotSnrDb = diagnostics.snapshotSnrDb;
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end
