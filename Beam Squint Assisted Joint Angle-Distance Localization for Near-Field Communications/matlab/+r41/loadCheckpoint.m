function [results, environment] = loadCheckpoint( ...
    file, expectedIdentity, expectedDesign)
%LOADCHECKPOINT Reject stale or structurally incomplete shard checkpoints.

arguments
    file (1, 1) string
    expectedIdentity (1, 1) struct
    expectedDesign table
end

saved = load(file, "identity", "design", "results", "environment");
required = ["identity", "design", "results", "environment"];
valid = all(isfield(saved, required)) ...
    && isequaln(saved.identity, expectedIdentity) ...
    && isequaln(saved.design, expectedDesign) ...
    && numel(saved.results) == height(expectedDesign);
if ~valid
    error("r41:StaleOrInvalidCheckpoint", ...
        "Checkpoint source, design, authorization, statistics, or shard drifted.");
end
results = saved.results;
environment = saved.environment;
end
