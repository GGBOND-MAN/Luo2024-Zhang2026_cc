function folder = assertExecutionTarget(project, shardId, resume)
%ASSERTEXECUTIONTARGET Reject ambiguous pre-existing final output.

arguments
    project (1, 1) string
    shardId (1, 1) double {mustBeInteger, mustBeInRange(shardId, 1, 2)}
    resume (1, 1) logical = false
end

locations = r41.paths(project);
folder = fullfile(locations.executionFolder, ...
    sprintf("shard_%02d_of_02", shardId));
if ~resume && isfolder(locations.executionFolder)
    error("r41:ExistingFinalResultDirectory", ...
        "The R41 final result directory already exists. " + ...
        "Stop and resolve it manually before authorization or trials.");
end
if resume && (~isfolder(folder) ...
        || ~isfile(fullfile(folder, "checkpoint.mat")))
    error("r41:MissingResumeCheckpoint", ...
        "Resume requires the exact existing shard checkpoint.");
end
if resume && isfile(fullfile(folder, "COMPLETE.mat"))
    error("r41:CompletedShardCannotRerun", ...
        "A completed final shard cannot be rerun or replaced.");
end
end
