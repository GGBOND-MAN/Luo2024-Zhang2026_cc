function [angleRmseDeg, rangeRmseM] = projectedCrlb(cfg, thetaDeg, rangeM, snrDb)
%PROJECTEDCRLB CRLB after eliminating the unknown complex target amplitude.
% This is the standard deterministic-signal correction missing from (59).

thetaRad = deg2rad(thetaDeg);
x = cfg.elementIndex * cfg.elementSpacing;
scale = 2 * pi * cfg.fc / cfg.c;
phase = -scale * (rangeM - x * sin(thetaRad) ...
    + x.^2 * cos(thetaRad)^2 / (2 * rangeM));
a = exp(1i * phase);
dPhaseTheta = scale * (x * cos(thetaRad) ...
    - x.^2 * sin(2 * thetaRad) / (2 * rangeM));
dPhaseRange = -scale * (1 - x.^2 * cos(thetaRad)^2 / (2 * rangeM^2));
derivative = [1i * dPhaseTheta .* a, 1i * dPhaseRange .* a];
projector = eye(cfg.numAntennas) - a * a' / (a' * a);
baseInformation = 2 * real(derivative' * projector * derivative);

angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for k = 1:numel(snrDb)
    covarianceBound = (10^(snrDb(k) / 10) * baseInformation) \ eye(2);
    angleRmseDeg(k) = rad2deg(sqrt(covarianceBound(1, 1)));
    rangeRmseM(k) = sqrt(covarianceBound(2, 2));
end
end
