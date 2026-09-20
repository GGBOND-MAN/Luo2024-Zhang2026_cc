function output = run_r41v2_schemeG_final_shard(shardId, options)
%RUN_R41V2_SCHEMEG_FINAL_SHARD Run one future authorized unchanged shard.

arguments
    shardId (1, 1) double {mustBeInteger, mustBeInRange(shardId, 1, 2)}
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 32
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
folder = r41statsv2.assertExecutionTarget(project, shardId, options.Resume);
saved = r41statsv2.validateProtocolPackage(project);
locations = r41statsv2.paths(project);
authorization = r41.assertAuthorized( ...
    locations.protocolFolder, saved.identity);
[design, globalRows] = r41.partitionDesign(saved.design, shardId);
identity = struct( ...
    version="R41-independent-final-shard-v2", ...
    protocolVersion=saved.identity.protocolVersion, ...
    designHash=saved.identity.designHash, ...
    shardDesignHash=r41.designHash(design), ...
    statisticsVersion=saved.identity.statisticsVersion, ...
    statisticsHash=saved.identity.statisticsHash, ...
    sourceDigest=saved.identity.sourceDigest, ...
    algorithmDigest=saved.identity.algorithmDigest, ...
    r33Digest=saved.identity.r33Digest, r34Digest=saved.identity.r34Digest, ...
    frozenDependencyDigest=saved.identity.frozenDependencyDigest, ...
    authorizationDigest=r41.structHash(authorization), authorized=true, ...
    shardId=shardId, shardCount=2, globalRows=globalRows, ...
    trialsExecuted=0);
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(design), 1);
environment = struct();
if options.Resume
    [results, environment] = r41.loadCheckpoint( ...
        checkpoint, identity, design);
else
    mkdir(folder);
end

% The unchanged R41 execution core starts only after all v2 identity gates.
cfg = jad.defaultConfig();
r41.validateFrozenSystem(cfg, saved.protocol);
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    indices = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(indices, :);
    batchGlobalRows = globalRows(indices);
    trialProtocol = saved.protocol;
    batch = cell(numel(indices), 1);
    parfor localIndex = 1:numel(indices)
        batch{localIndex} = r41.finalTrial(cfg, scan, ...
            batchDesign(localIndex, :), batchGlobalRows(localIndex), ...
            trialProtocol);
    end
    results(indices) = batch;
    environment = environmentRecord(pool, options.BatchSize);
    r41.saveCheckpoint(checkpoint, identity, design, results, environment);
    fprintf("R41 v2 final shard %d/2: %d/%d\n", shardId, ...
        nnz(~cellfun(@isempty, results)), height(design));
end
identity.trialsExecuted = nnz(~cellfun(@isempty, results));
identity.completedAt = string(datetime("now", "TimeZone", "Asia/Shanghai"));
failed = cellfun(@(item) ~item.success, results);
failures = failureTable(design, results, failed);
writetable(failures, fullfile(folder, "failed_rows.csv"));
save(fullfile(folder, "result.mat"), "identity", "design", ...
    "results", "environment", "failures", "-v7.3");
save(fullfile(folder, "COMPLETE.mat"), "identity", "failed");
output = struct(identity=identity, failures=failures, folder=folder);
fprintf("R41_V2_FINAL_SHARD_COMPLETE shard=%d rows=%d failures=%d\n", ...
    shardId, identity.trialsExecuted, nnz(failed));
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
    workers=pool.NumWorkers, poolClass=class(pool), ...
    batchSize=batchSize, timestamp=string(datetime( ...
    "now", "TimeZone", "Asia/Shanghai")), ...
    serverThroughputIsAlgorithmRuntimeEvidence=false);
end

function failures = failureTable(design, results, failed)
failures = design(failed, :);
if ~any(failed)
    failures.errorIdentifier = strings(0, 1);
    failures.errorMessage = strings(0, 1);
    return;
end
selected = results(failed);
failures.errorIdentifier = cellfun( ...
    @(item) string(item.errorIdentifier), selected);
failures.errorMessage = cellfun( ...
    @(item) string(item.errorMessage), selected);
end
