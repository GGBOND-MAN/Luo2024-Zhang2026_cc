function snapshots = simulateSnapshots(cfg, thetaDeg, rangeM, snrDb, carrierIndex, stream)
%SIMULATESNAPSHOTS Create array-level observations following (28).

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double
    rangeM (1, 1) double {mustBePositive}
    snrDb (1, 1) double
    carrierIndex (:, 1) double
    stream = RandStream.getGlobalStream
end

[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
numCarriers = numel(carrierIndex);
snapshots = complex(zeros(cfg.numAntennas, numCarriers));
noiseStd = 10^(-snrDb / 20);
for k = 1:numCarriers
    signal = sqrt(cfg.numAntennas) * jad.steeringVector( ...
        cfg, thetaDeg, rangeM, frequencyHz(k));
    noise = noiseStd / sqrt(2) * (randn(stream, cfg.numAntennas, 1) ...
        + 1i * randn(stream, cfg.numAntennas, 1));
    snapshots(:, k) = signal + noise;
end
end
