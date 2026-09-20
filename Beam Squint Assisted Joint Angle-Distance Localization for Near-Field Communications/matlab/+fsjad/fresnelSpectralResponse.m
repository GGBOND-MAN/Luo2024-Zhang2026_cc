function [q, derivative] = fresnelSpectralResponse(cfg, thetaRad, rangeM, scan)
%FRESNELSPECTRALRESPONSE Fresnel channel model with actual known beams.

arguments
    cfg (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
end

x = scan.x;
cosine = cos(thetaRad);
distance = rangeM - x * sin(thetaRad) ...
    + x.^2 * cosine^2 / (2 * rangeM);
distanceTheta = -x * cosine ...
    - x.^2 * sin(2 * thetaRad) / (2 * rangeM);
distanceRange = 1 - x.^2 * cosine^2 / (2 * rangeM^2);

arrayResponse = exp(-1i * distance * scan.wavenumber.') ...
    / sqrt(cfg.numAntennas);
arrayDerivativeTheta = -1i * distanceTheta .* scan.wavenumber.' ...
    .* arrayResponse;
arrayDerivativeRange = -1i * distanceRange .* scan.wavenumber.' ...
    .* arrayResponse;

q = sum(conj(scan.beamformer) .* arrayResponse, 1).';
derivative = [sum(conj(scan.beamformer) .* arrayDerivativeTheta, 1).', ...
    sum(conj(scan.beamformer) .* arrayDerivativeRange, 1).'];
end
