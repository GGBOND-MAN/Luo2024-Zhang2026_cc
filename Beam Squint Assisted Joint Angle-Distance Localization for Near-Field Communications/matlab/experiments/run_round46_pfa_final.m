function output = run_round46_pfa_final(options)
%RUN_ROUND46_PFA_FINAL Execute the one authorized single-PC final run.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
locations = r46.paths(project);
saved = r46.validateProtocolPackage(project);
authorization = r46.assertAuthorized( ...
    locations.protocolFolder, saved.identity);
authorizationDigest = r41.structHash(authorization);
checkpointIdentity = struct( ...
    version="R46-PFA-final-checkpoint-v1", ...
    protocolVersion=saved.identity.protocolVersion, ...
    designHash=saved.identity.designHash, ...
    statisticsHash=saved.identity.statisticsHash, ...
    sourceDigest=saved.identity.sourceDigest, ...
    calibrationSourceDigest=saved.identity.calibrationSourceDigest, ...
    authorizationDigest=authorizationDigest, expectedRows=1400);
folder = locations.executionFolder;
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(saved.design), 1);
environment = struct();
if options.Resume
    if ~isfolder(folder) || ~isfile(checkpoint) ...
            || isfile(fullfile(folder, "COMPLETE.mat"))
        error("r46:MissingResumeCheckpoint", ...
            "Resume requires one incomplete exact R46 checkpoint.");
    end
    [results, environment] = r41.loadCheckpoint( ...
        checkpoint, checkpointIdentity, saved.design);
else
    if isfolder(folder)
        error("r46:ExistingFinalResultDirectory", ...
            "The R46 final output already exists; do not overwrite it.");
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
        batch{localIndex} = r46.finalTrial(cfg, scan, ...
            batchDesign(localIndex, :), indices(localIndex), trialProtocol);
    end
    results(indices) = batch;
    environment = environmentRecord(pool, options.BatchSize);
    r41.saveCheckpoint(checkpoint, checkpointIdentity, ...
        saved.design, results, environment);
    fprintf("R46 final: %d/%d rows complete\n", ...
        nnz(~cellfun(@isempty, results)), height(saved.design));
end

r46.validateProtocolPackage(project);
failureMask = cellfun(@(item) isempty(item) || ~item.success, results);
failures = failureTable(saved.design, results, failureMask);
writetable(failures, fullfile(folder, "failures.csv"));
if any(failureMask)
    save(fullfile(folder, "failed_result.mat"), "checkpointIdentity", ...
        "results", "failures", "environment", "-v7.3");
    error("r46:FinalTrialFailure", ...
        "At least one frozen R46 final row failed.");
end

summary = r46.summarize(saved.design, results, saved.protocol);
writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, fullfile(folder, "comparisons.csv"));
writetable(summary.bootstrap.angleFamily, ...
    fullfile(folder, "angle_primary_family.csv"));
writetable(summary.bootstrap.rangeFamily, ...
    fullfile(folder, "range_primary_family.csv"));
writetable(summary.bootstrap.aggregate, ...
    fullfile(folder, "aggregate_bootstrap.csv"));
writetable(summary.diagnostics, fullfile(folder, "diagnostics.csv"));
writetable(summary.decision, fullfile(folder, "decision.csv"));
identity = struct(version=saved.protocol.version, authorized=true, ...
    trialsExecuted=height(saved.design), failedTrials=0, ...
    protocolVersion=saved.identity.protocolVersion, ...
    designHash=saved.identity.designHash, ...
    statisticsHash=saved.identity.statisticsHash, ...
    sourceDigest=saved.identity.sourceDigest, ...
    calibrationSourceDigest=saved.identity.calibrationSourceDigest, ...
    authorizationDigest=authorizationDigest, ...
    primaryPass=summary.primaryPass, ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "identity", "saved", ...
    "results", "summary", "environment", "-v7.3");
save(fullfile(folder, "COMPLETE.mat"), "identity");
output = struct(folder=folder, identity=identity, summary=summary);
fprintf("ROUND46_FINAL_COMPLETE rows=1400 failures=0 pass=%d\n", ...
    summary.primaryPass);
disp(summary.decision);
disp(summary.bootstrap.angleFamily);
disp(summary.bootstrap.rangeFamily);
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

function output = environmentRecord(pool, batchSize)
output = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    timestamp=string(datetime("now", "TimeZone", "Asia/Shanghai")), ...
    serverThroughputIsAlgorithmRuntimeEvidence=false);
end

function failures = failureTable(design, results, failed)
failures = design(failed, :);
failures.errorIdentifier = strings(nnz(failed), 1);
failures.errorMessage = strings(nnz(failed), 1);
selected = find(failed);
for index = 1:numel(selected)
    item = results{selected(index)};
    if isempty(item)
        failures.errorIdentifier(index) = "r46:MissingResult";
        failures.errorMessage(index) = "The frozen row has no result.";
    else
        failures.errorIdentifier(index) = string(item.errorIdentifier);
        failures.errorMessage(index) = string(item.errorMessage);
    end
end
end
