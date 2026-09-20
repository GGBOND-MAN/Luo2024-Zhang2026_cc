function [q, derivative] = exactSpectralResponse(cfg, thetaRad, rangeM, scan)
%EXACTSPECTRALRESPONSE Complex scan response and exact spatial derivatives.

arguments
    cfg (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
end

x = scan.x;
distance = sqrt(rangeM^2 + x.^2 - 2 * rangeM * x * sin(thetaRad));
arrayResponse = exp(-1i * distance * scan.wavenumber.') ...
    / sqrt(cfg.numAntennas);

distanceTheta = -rangeM * x * cos(thetaRad) ./ distance;
distanceRange = (rangeM - x * sin(thetaRad)) ./ distance;
arrayDerivativeTheta = -1i * distanceTheta .* scan.wavenumber.' .* arrayResponse;
arrayDerivativeRange = -1i * distanceRange .* scan.wavenumber.' .* arrayResponse;

q = sum(conj(scan.beamformer) .* arrayResponse, 1).';
derivative = [sum(conj(scan.beamformer) .* arrayDerivativeTheta, 1).', ...
    sum(conj(scan.beamformer) .* arrayDerivativeRange, 1).'];
end
