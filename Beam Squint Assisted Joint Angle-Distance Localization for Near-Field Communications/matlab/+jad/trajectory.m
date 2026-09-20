function [thetaDeg, rangeM, frequencyHz] = trajectory(cfg, carrierIndex)
%TRAJECTORY Evaluate the controllable beam-squint path in (14)-(15).
% carrierIndex is zero-based, matching the paper.

arguments
    cfg (1, 1) struct
    carrierIndex (:, 1) double = (0:cfg.numSubcarriers - 1).'
end

fLow = cfg.fc - cfg.bandwidth / 2;
frequencyOffset = carrierIndex * cfg.bandwidth / cfg.numSubcarriers;
frequencyHz = fLow + frequencyOffset;

startWeight = (cfg.bandwidth - frequencyOffset) .* fLow ...
    ./ (cfg.bandwidth .* frequencyHz);
endWeight = (cfg.bandwidth + fLow) .* frequencyOffset ...
    ./ (cfg.bandwidth .* frequencyHz);

thetaStart = deg2rad(cfg.thetaLimitsDeg(1));
thetaEnd = deg2rad(cfg.thetaLimitsDeg(2));
sinTheta = startWeight * sin(thetaStart) + endWeight * sin(thetaEnd);
sinTheta = min(max(sinTheta, -1), 1);
thetaRad = asin(sinTheta);

inverseRange = startWeight / cfg.rangeLimitsM(1) ...
    .* cos(thetaStart)^2 ./ cos(thetaRad).^2 ...
    + endWeight / cfg.rangeLimitsM(2) ...
    .* cos(thetaEnd)^2 ./ cos(thetaRad).^2;

thetaDeg = rad2deg(thetaRad);
rangeM = 1 ./ inverseRange;
end
