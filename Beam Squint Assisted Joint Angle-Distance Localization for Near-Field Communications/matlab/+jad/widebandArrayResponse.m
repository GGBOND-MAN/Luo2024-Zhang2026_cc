function response = widebandArrayResponse(cfg, thetaDeg, rangeM)
%WIDEBANDARRAYRESPONSE Exact spherical-wave response over all carriers.

index = (0:cfg.numSubcarriers - 1).';
[~, ~, frequencyHz] = jad.trajectory(cfg, index);
x = cfg.elementIndex * cfg.elementSpacing;
distance = sqrt(rangeM^2 + x.^2 - 2 * rangeM * x * sind(thetaDeg));
response = exp(-1i * 2 * pi / cfg.c * distance * frequencyHz.');
response = response / sqrt(cfg.numAntennas);
end
