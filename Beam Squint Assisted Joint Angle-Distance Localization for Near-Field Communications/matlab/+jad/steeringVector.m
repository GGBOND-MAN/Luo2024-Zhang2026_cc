function a = steeringVector(cfg, thetaDeg, rangeM, frequencyHz, elementIndex)
%STEERINGVECTOR Normalized Fresnel near-field response in (27).

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double
    rangeM (1, 1) double {mustBePositive}
    frequencyHz (1, 1) double {mustBePositive}
    elementIndex (:, 1) double = cfg.elementIndex
end

thetaRad = deg2rad(thetaDeg);
x = elementIndex * cfg.elementSpacing;
distanceM = rangeM - x * sin(thetaRad) ...
    + x.^2 * cos(thetaRad)^2 / (2 * rangeM);
a = exp(-1i * 2 * pi * frequencyHz / cfg.c .* distanceM);
a = a / norm(a);
end
