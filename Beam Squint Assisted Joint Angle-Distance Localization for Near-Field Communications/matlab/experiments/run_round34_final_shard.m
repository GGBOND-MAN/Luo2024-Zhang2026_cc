function run_round34_final_shard(shardIndex, shardCount, options)
%RUN_ROUND34_FINAL_SHARD Run one future authorized position-cluster shard.

arguments
    shardIndex (1, 1) double {mustBeInteger, mustBePositive}
    shardCount (1, 1) double {mustBeInteger, mustBePositive}
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 32
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 16
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
packageFolder = fullfile(project, "results", "full_spectrum", ...
    "round34_final_test_protocol_v1");
protocolFile = fullfile(packageFolder, "protocol.mat");
if ~isfile(protocolFile)
    error("r34:MissingFinalProtocol", ...
        "The reviewed R34 final protocol is missing.");
end
saved = load(protocolFile, "identity", "design", "source");

% The authorization gate is checked before cfg/scan creation, observation
% replay, input hashing, pool creation, or estimation.
r34.assertFinalTestAuthorized(packageFolder, saved.identity);
if shardCount ~= saved.identity.protocol.finalTest.expectedShardCount ...
        || shardIndex > shardCount
    error("r34:FrozenShardLayoutMismatch", ...
        "The final protocol requires exactly two position-cluster shards.");
end
currentSource = r34.manifest(project);
currentDigest = r32.sourceDigest(currentSource);
if currentDigest ~= saved.identity.sourceDigest ...
        || r32.designHash(saved.design) ~= saved.identity.designHash ...
        || saved.identity.designHash ...
        ~= saved.identity.protocol.finalTest.designHash
    error("r34:FinalSourceOrDesignDrift", ...
        "Executable source or the frozen design changed after authorization.");
end

[design, globalRowIndex] = r34.partitionDesign( ...
    saved.design, shardIndex, shardCount);
expectedRows = saved.identity.protocol.finalTest.expectedRowsPerShard;
expectedPositions = ...
    saved.identity.protocol.finalTest.expectedPositionsPerShard;
if height(design) ~= expectedRows ...
        || numel(unique(design.positionId)) ~= expectedPositions
    error("r34:FrozenShardBalanceMismatch", ...
        "Each server must receive 100 positions and 700 paired rows.");
end
for snrDb = saved.identity.protocol.finalTest.snrDb
    if nnz(design.snrDb == snrDb) ~= expectedPositions
        error("r34:FrozenShardSnrBalanceMismatch", ...
            "Each shard must contain 100 rows at every frozen SNR.");
    end
end

shardIdentity = struct(version="R34-final-position-cluster-shard-v1", ...
    protocolVersion=saved.identity.version, ...
    protocolDesignHash=saved.identity.designHash, ...
    sourceDigest=saved.identity.sourceDigest, ...
    estimatorVersion=saved.identity.protocol.estimatorVersion, ...
    statisticsVersion=saved.identity.protocol.statisticsVersion, ...
    shardIndex=shardIndex, shardCount=shardCount, ...
    globalRowIndex=globalRowIndex, ...
    shardDesignHash=r32.designHash(design));
folder = fullfile(project, "results", "full_spectrum", ...
    "round34_final_test_v1", sprintf("shard_%02d_of_%02d", ...
    shardIndex, shardCount));
if ~isfolder(folder)
    mkdir(folder);
end
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(design), 1);
hashes = cell(height(design), 1);
if isfile(checkpoint)
    [results, hashes, ~] = r34.loadCheckpoint( ...
        checkpoint, shardIdentity, design);
end

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
protocol = saved.identity.protocol;
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    indices = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(indices, :);
    missingHash = cellfun(@isempty, hashes(indices));
    if any(missingHash)
        clientTimer = tic;
        prepared = r34.prepareInputHashes( ...
            cfg, scan, batchDesign(missingHash, :));
        hashes(indices(missingHash)) = prepared;
        environment = environmentRecord( ...
            pool, options.BatchSize, toc(clientTimer));
        r34.saveCheckpoint(checkpoint, shardIdentity, design, ...
            results, hashes, environment);
    end
    batchHashes = hashes(indices);
    batch = cell(numel(indices), 1);
    parfor localIndex = 1:numel(indices)
        batch{localIndex} = r34.finalTrial(cfg, scan, ...
            batchDesign(localIndex, :), batchHashes{localIndex}, ...
            protocol);
    end
    results(indices) = batch;
    environment = environmentRecord(pool, options.BatchSize, 0);
    r34.saveCheckpoint(checkpoint, shardIdentity, design, ...
        results, hashes, environment);
    fprintf("R34 final shard %d/%d: %d/%d\n", ...
        shardIndex, shardCount, nnz(~cellfun(@isempty, results)), ...
        height(design));
end

identity = shardIdentity;
environment = environmentRecord(pool, options.BatchSize, 0);
save(fullfile(folder, "result.mat"), "identity", "design", ...
    "results", "hashes", "environment", "-v7.3");
failed = cellfun(@(item) ~item.success, results);
failures = failureTable(design, results, failed);
writetable(failures, fullfile(folder, "failed_rows.csv"));
save(fullfile(folder, "COMPLETE.mat"), "identity", "failed");
fprintf("ROUND34_FINAL_SHARD_COMPLETE shard=%d failures=%d\n", ...
    shardIndex, nnz(failed));
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

function output = environmentRecord(pool, batchSize, clientHashSeconds)
output = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), ...
    batchSize=batchSize, timestamp=string(datetime("now")), ...
    inputHashLocation="MATLAB-client-not-thread-worker", ...
    latestClientHashSeconds=clientHashSeconds, ...
    hashReplayIsOrchestrationOverhead=true);
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
