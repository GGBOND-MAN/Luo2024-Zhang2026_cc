function result = dftCodebookEstimate(cfg, thetaDeg, rangeM, snrDb, stream)
%DFTCODEBOOKESTIMATE Cascaded near-field matched-filter codebook baseline.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double
    rangeM (1, 1) double {mustBePositive}
    snrDb (1, 1) double
    stream = RandStream.getGlobalStream
end

signal = sqrt(cfg.numAntennas) * jad.steeringVector( ...
    cfg, thetaDeg, rangeM, cfg.fc);
noiseStd = 10^(-snrDb / 20);
noise = noiseStd / sqrt(2) * (randn(stream, cfg.numAntennas, 1) ...
    + 1i * randn(stream, cfg.numAntennas, 1));
observation = signal + noise;

thetaGrid = linspace(cfg.thetaLimitsDeg(1), cfg.thetaLimitsDeg(2), 1201);
nominalRange = mean(cfg.rangeLimitsM);
angleCodebook = steeringMatrix(cfg, thetaGrid, nominalRange * ones(size(thetaGrid)));
[~, peak] = max(abs(observation' * angleCodebook));
estimatedTheta = thetaGrid(peak);

rangeGrid = linspace(cfg.rangeLimitsM(1), cfg.rangeLimitsM(2), 701);
rangeCodebook = steeringMatrix(cfg, estimatedTheta * ones(size(rangeGrid)), rangeGrid);
[~, peak] = max(abs(observation' * rangeCodebook));

result.thetaDeg = estimatedTheta;
result.rangeM = rangeGrid(peak);
end

function matrix = steeringMatrix(cfg, thetaDeg, rangeM)
x = cfg.elementIndex * cfg.elementSpacing;
distance = rangeM - x * sind(thetaDeg) ...
    + x.^2 .* (cosd(thetaDeg).^2 ./ (2 * rangeM));
matrix = exp(-1i * 2 * pi * cfg.fc / cfg.c .* distance);
matrix = matrix / sqrt(cfg.numAntennas);
end
