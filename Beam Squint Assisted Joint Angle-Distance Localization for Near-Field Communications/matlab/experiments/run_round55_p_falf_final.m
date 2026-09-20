function output = run_round55_p_falf_final(options)
%RUN_ROUND55_P_FALF_FINAL Execute the manually authorized final run.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
locations = r55.paths(project);
saved = r55.validateProtocolPackage(project);
authorization = r55.assertAuthorized(project, saved.identity);
authorizationDigest = r41.structHash(authorization);
checkpointIdentity = struct(version="R55-PFALF-final-checkpoint-v1", ...
    protocolVersion=saved.identity.protocolVersion, ...
    designHash=saved.identity.designHash, ...
    statisticsHash=saved.identity.statisticsHash, ...
    sourceDigest=saved.identity.sourceDigest, ...
    authorizationDigest=authorizationDigest, ...
    expectedRows=saved.protocol.design.expectedRows);
folder = locations.executionFolder;
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(saved.design), 1);
if options.Resume
    if ~isfile(checkpoint) || isfile(fullfile(folder, "COMPLETE.mat"))
        error("r55:MissingResumeCheckpoint", ...
            "Resume requires one incomplete exact R55 checkpoint.");
    end
    loaded = load(checkpoint, "checkpointIdentity", "results");
    if ~isequal(loaded.checkpointIdentity, checkpointIdentity) ...
            || numel(loaded.results) ~= height(saved.design)
        error("r55:CheckpointIdentityMismatch", ...
            "The R55 checkpoint identity is invalid.");
    end
    results = loaded.results;
else
    if isfolder(folder)
        error("r55:ExistingFinalResultDirectory", ...
            "The R55 final output already exists; do not overwrite it.");
    end
    mkdir(folder);
end

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    indices = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = saved.design(indices, :);
    batch = cell(numel(indices), 1);
    trialProtocol = saved.protocol;
    parfor localIndex = 1:numel(indices)
        batch{localIndex} = r55.finalTrial(cfg, scan, ...
            batchDesign(localIndex, :), indices(localIndex), trialProtocol);
    end
    results(indices) = batch;
    saveCheckpoint(checkpoint, checkpointIdentity, results);
    fprintf("R55 final: %d/%d rows complete\n", ...
        nnz(~cellfun(@isempty, results)), height(saved.design));
end

r55.validateProtocolPackage(project);
failed = cellfun(@(item) isempty(item) || ~item.success, results);
failures = failureTable(saved.design, results, failed);
writetable(failures, fullfile(folder, "failures.csv"));
if any(failed)
    save(fullfile(folder, "failed_result.mat"), ...
        "checkpointIdentity", "results", "failures", "-v7");
    error("r55:FinalTrialFailure", ...
        "At least one frozen R55 final row failed.");
end

summary = r55.summarize(saved.design, results, saved.protocol);
writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, fullfile(folder, "comparisons.csv"));
writetable(summary.primaryBootstrap.family, ...
    fullfile(folder, "range_primary_family.csv"));
writetable(summary.primaryBootstrap.aggregate, ...
    fullfile(folder, "range_aggregate_primary.csv"));
writetable(summary.pfaBootstrap.family, ...
    fullfile(folder, "range_vs_pfa_family.csv"));
writetable(summary.pfaBootstrap.aggregate, ...
    fullfile(folder, "range_vs_pfa_aggregate.csv"));
writetable(summary.diagnostics, fullfile(folder, "diagnostics.csv"));
writetable(summary.decision, fullfile(folder, "decision.csv"));
identity = struct(version=saved.protocol.version, authorized=true, ...
    trialsExecuted=height(saved.design), failedTrials=0, ...
    protocolVersion=saved.identity.protocolVersion, ...
    designHash=saved.identity.designHash, ...
    statisticsHash=saved.identity.statisticsHash, ...
    sourceDigest=saved.identity.sourceDigest, ...
    authorizationDigest=authorizationDigest, ...
    primaryPass=summary.primaryPass, workers=pool.NumWorkers, ...
    poolClass=class(pool), ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "identity", "saved", ...
    "results", "summary", "-v7");
save(fullfile(folder, "COMPLETE.mat"), "identity");
output = struct(folder=folder, identity=identity, summary=summary);
fprintf("ROUND55_FINAL_COMPLETE rows=1400 failures=0 pass=%d\n", ...
    summary.primaryPass);
disp(summary.decision);
disp(summary.primaryBootstrap.family);
disp(summary.primaryBootstrap.aggregate);
end

function saveCheckpoint(file, checkpointIdentity, results)
temporary = file+".tmp";
save(temporary, "checkpointIdentity", "results", "-v7");
movefile(temporary, file, "f");
end

function output = failureTable(design, results, failed)
output = design(failed, :);
output.errorIdentifier = strings(nnz(failed), 1);
output.errorMessage = strings(nnz(failed), 1);
indices = find(failed);
for index = 1:numel(indices)
    item = results{indices(index)};
    if isempty(item)
        output.errorIdentifier(index) = "r55:MissingResult";
        output.errorMessage(index) = "The frozen row has no result.";
    else
        output.errorIdentifier(index) = item.errorIdentifier;
        output.errorMessage(index) = item.errorMessage;
    end
end
end

function pool = preparePool(poolType, workers)
pool = gcp("nocreate");
requiredClass = "parallel.ThreadPool";
if poolType == "Processes"
    requiredClass = "parallel.ProcessPool";
end
if ~isempty(pool) && (pool.NumWorkers ~= workers ...
        || string(class(pool)) ~= requiredClass)
    delete(pool);
    pool = [];
end
if isempty(pool)
    pool = parpool(poolType, workers);
end
end
