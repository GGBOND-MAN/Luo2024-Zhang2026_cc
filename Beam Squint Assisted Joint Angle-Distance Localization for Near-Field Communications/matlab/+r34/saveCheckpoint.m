function saveCheckpoint(file, identity, design, results, hashes, environment)
%SAVECHECKPOINT Persist a resumable shard state with exact identity fields.

arguments
    file (1, 1) string
    identity (1, 1) struct
    design table
    results cell
    hashes cell
    environment (1, 1) struct
end

if numel(results) ~= height(design) || numel(hashes) ~= height(design)
    error("r34:CheckpointSizeMismatch", ...
        "Checkpoint cells must have one entry per design row.");
end
save(file, "identity", "design", "results", "hashes", ...
    "environment", "-v7.3");
end
