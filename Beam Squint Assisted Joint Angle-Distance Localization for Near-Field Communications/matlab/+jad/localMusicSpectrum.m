function spectrum = localMusicSpectrum(cfg, signalVectors, ...
    carrierIndex, thetaGridDeg, rangeGridM)
%LOCALMUSICSPECTRUM Evaluate the fused MUSIC spectrum on a supplied grid.

arguments
    cfg (1, 1) struct
    signalVectors (:, :) double
    carrierIndex (:, 1) double
    thetaGridDeg (1, :) double {mustBeFinite}
    rangeGridM (1, :) double {mustBeFinite, mustBePositive}
end

if size(signalVectors, 1) ~= cfg.subarraySize
    error("jad:InvalidSignalVectorSize", ...
        "signalVectors must have cfg.subarraySize rows.");
end
if size(signalVectors, 2) ~= numel(carrierIndex)
    error("jad:InvalidCarrierCount", ...
        "One carrier index is required per signal-vector column.");
end

[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
[thetaMesh, rangeMesh] = meshgrid(thetaGridDeg, rangeGridM);
thetaVector = thetaMesh(:).';
rangeVector = rangeMesh(:).';
numSubarrays = cfg.numSubarrays;
referenceStart = floor((numSubarrays + 1) / 2);
ids = referenceStart:(referenceStart + cfg.subarraySize - 1);
x = cfg.elementIndex(ids) * cfg.elementSpacing;
logSpectrum = zeros(1, numel(thetaVector));

for carrier = 1:numel(frequencyHz)
    thetaRad = deg2rad(thetaVector);
    distance = rangeVector - x * sin(thetaRad) ...
        + x.^2 * (cos(thetaRad).^2 ./ (2 * rangeVector));
    steering = exp(-1i * 2 * pi * frequencyHz(carrier) / cfg.c ...
        .* distance) / sqrt(cfg.subarraySize);
    denominator = 1 - abs( ...
        signalVectors(:, carrier)' * steering).^2;
    denominator = max(real(denominator), eps);
    logSpectrum = logSpectrum - log(denominator);
end

spectrum = reshape(exp(logSpectrum / numel(frequencyHz)), ...
    size(thetaMesh));
spectrum = spectrum / max(spectrum, [], "all");
end
