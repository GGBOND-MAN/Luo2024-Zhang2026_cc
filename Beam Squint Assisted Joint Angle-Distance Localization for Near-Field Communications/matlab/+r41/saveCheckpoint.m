function saveCheckpoint(file, identity, design, results, environment)
%SAVECHECKPOINT Persist exact resumable final-shard state.

arguments
    file (1, 1) string
    identity (1, 1) struct
    design table
    results cell
    environment (1, 1) struct
end

if numel(results) ~= height(design)
    error("r41:CheckpointSizeMismatch", ...
        "A checkpoint requires one result cell per frozen design row.");
end
save(file, "identity", "design", "results", "environment", "-v7.3");
end
