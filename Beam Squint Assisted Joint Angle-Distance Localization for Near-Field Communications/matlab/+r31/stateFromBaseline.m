function [state, musicCfg] = stateFromBaseline( ...
    cfg, estimate, carrierIndex, coarseThetaDeg, coarseRangeM, subarraySize)
%STATEFROMBASELINE Reconstruct frozen-state metadata without rebuilding EVDs.

arguments
    cfg (1, 1) struct
    estimate (1, 1) struct
    carrierIndex (:, 1) double {mustBeInteger, mustBeNonnegative}
    coarseThetaDeg (1, 1) double {mustBeFinite}
    coarseRangeM (1, 1) double {mustBeFinite, mustBePositive}
    subarraySize (1, 1) double {mustBeInteger, mustBePositive}
end

if ~isfield(estimate, "signalVectors") ...
        || size(estimate.signalVectors, 2) ~= numel(carrierIndex)
    error("r31:MissingBaselineSubspace", ...
        "The saved baseline does not contain the expected signal vectors.");
end
musicCfg = cfg;
musicCfg.subarraySize = subarraySize;
musicCfg.numSubarrays = cfg.numAntennas-subarraySize+1;
[~, ~, frequencyHz] = jad.trajectory(musicCfg, carrierIndex);
referenceStart = floor((musicCfg.numSubarrays+1)/2);
referenceIds = referenceStart:(referenceStart+subarraySize-1);
state = struct(signalVectors=estimate.signalVectors, ...
    carrierIndex=carrierIndex, frequencyHz=frequencyHz, ...
    referenceIds=referenceIds, ...
    referencePositionM=cfg.elementIndex(referenceIds)*cfg.elementSpacing, ...
    subarraySize=subarraySize, coarseThetaDeg=coarseThetaDeg, ...
    coarseRangeM=coarseRangeM);
end
