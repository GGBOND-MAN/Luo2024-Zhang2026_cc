function weights = ttdBeamformer(cfg, startThetaDeg, startRangeM, endThetaDeg, endRangeM)
%TTDBEAMFORMER Ideal TTD/PS weights used by the public Lei et al. code.

index = (0:cfg.numSubcarriers - 1).';
[~, ~, frequencyHz] = jad.trajectory(cfg, index);
x = cfg.elementIndex * cfg.elementSpacing;
startDistance = sqrt(startRangeM^2 + x.^2 ...
    - 2 * startRangeM * x * sind(startThetaDeg));
endDistance = sqrt(endRangeM^2 + x.^2 ...
    - 2 * endRangeM * x * sind(endThetaDeg));
phaseCycles = frequencyHz(1) / cfg.c * startDistance;
delaySeconds = frequencyHz(end) / cfg.bandwidth / cfg.c * endDistance ...
    - phaseCycles / cfg.bandwidth;
weights = exp(-1i * 2 * pi * phaseCycles) ...
    .* exp(-1i * 2 * pi * delaySeconds * (frequencyHz - frequencyHz(1)).');
weights = weights / sqrt(cfg.numAntennas);
end
