function [output, thetaDeg, rangeM] = runBaseline(cfg, replay, front, algorithm)
%RUNBASELINE Run one explicitly labeled two-dimensional MUSIC baseline.

arguments
    cfg (1, 1) struct
    replay (1, 1) struct
    front (1, 1) struct
    algorithm (1, 1) struct
end

musicCfg = cfg;
musicCfg.subarraySize = algorithm.subarraySize;
musicCfg.numSubarrays = cfg.numAntennas - algorithm.subarraySize + 1;
musicCfg.localHalfWidthDeg = algorithm.localHalfWidthDeg;
musicCfg.localHalfWidthM = algorithm.localHalfWidthM;
musicCfg.gridSizes = algorithm.gridSizes;
carrierIndex = r30.selectLocalCarriers(cfg.numSubcarriers, ...
    algorithm.fusionCarrierCount, replay.peakCarrierIndex);
timer = tic;
estimate = jad.localMusicEstimate(musicCfg, ...
    replay.snapshots(:, carrierIndex+1), carrierIndex, ...
    front.thetaDeg, front.rangeM, ConstrainToInitialWindow=true);
label = "explicit-fixed-MUSIC-baseline";
if isfield(algorithm, "label")
    label = string(algorithm.label);
end
output = struct(label=label, estimate=estimate, ...
    carrierIndex=carrierIndex, seconds=toc(timer), ...
    gridPoints=sum(algorithm.gridSizes.^2), ...
    carrierGridPoints=numel(carrierIndex)*sum(algorithm.gridSizes.^2));
thetaDeg = estimate.thetaDeg;
rangeM = estimate.rangeM;
end
