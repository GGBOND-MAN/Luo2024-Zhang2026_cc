function cost = baselineComplexity(cfg, algorithm)
%BASELINECOMPLEXITY Paper-order and executable rank-one MUSIC cost units.

arguments
    cfg (1, 1) struct
    algorithm (1, 1) struct
end

carrierCount = algorithm.fusionCarrierCount;
subarraySize = algorithm.subarraySize;
numSubarrays = cfg.numAntennas-subarraySize+1;
gridPoints = sum(algorithm.gridSizes.^2);
cost.label = string(algorithm.label);
cost.carrierCount = carrierCount;
cost.subarraySize = subarraySize;
cost.numSubarrays = numSubarrays;
cost.gridPoints = gridPoints;
cost.paperCoarseUnits = cfg.numSubcarriers;
cost.paperCovarianceUnits = carrierCount*numSubarrays*subarraySize^2;
cost.paperEvdUnits = carrierCount*subarraySize^3;
cost.paperSpectrumUnits = carrierCount*gridPoints*subarraySize^2;
cost.paperDominantUnits = cost.paperCoarseUnits + cost.paperCovarianceUnits ...
    + cost.paperEvdUnits + cost.paperSpectrumUnits;
% This implementation uses the rank-one signal-vector identity. The same
% equivalent reduction must be available to every MUSIC method.
cost.executableSpectrumProjectionMacs = ...
    carrierCount*gridPoints*subarraySize;
end
