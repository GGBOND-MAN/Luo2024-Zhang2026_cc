function output = splitContexts(cfg, observation, scan)
%SPLITCONTEXTS Build fixed interlaced odd/even carrier q contexts.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
end

oddPosition = (1:2:cfg.numSubcarriers).';
evenPosition = (2:2:cfg.numSubcarriers).';
oddCarrierIndex = oddPosition-1;
evenCarrierIndex = evenPosition-1;
oddScan = r30.subsetScan(scan, oddCarrierIndex);
evenScan = r30.subsetScan(scan, evenCarrierIndex);
output = struct(version="R51-fixed-interlaced-spectrum-split-v1", ...
    oddCarrierIndex=oddCarrierIndex, evenCarrierIndex=evenCarrierIndex, ...
    odd=r33.prepareResponseContext( ...
        cfg, oddScan, observation(oddPosition)), ...
    even=r33.prepareResponseContext( ...
        cfg, evenScan, observation(evenPosition)));
end
