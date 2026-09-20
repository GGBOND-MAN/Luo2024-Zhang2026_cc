function [results, hashes, environment] = loadCheckpoint( ...
    file, expectedIdentity, expectedDesign)
%LOADCHECKPOINT Reject stale or structurally incomplete shard checkpoints.

arguments
    file (1, 1) string
    expectedIdentity (1, 1) struct
    expectedDesign table
end

saved = load(file, "identity", "design", "results", ...
    "hashes", "environment");
required = ["identity", "design", "results", "hashes", "environment"];
if ~all(isfield(saved, required)) ...
        || ~isequaln(saved.identity, expectedIdentity) ...
        || ~isequaln(saved.design, expectedDesign) ...
        || numel(saved.results) ~= height(expectedDesign) ...
        || numel(saved.hashes) ~= height(expectedDesign)
    error("r34:StaleOrInvalidCheckpoint", ...
        "The checkpoint does not match the exact source, design, and config.");
end
results = saved.results;
hashes = saved.hashes;
environment = saved.environment;
end
