function run_round32_final_shard(shardIndex, shardCount, options)
%RUN_ROUND32_FINAL_SHARD Run one authorized shard of the frozen final test.

arguments
    shardIndex (1, 1) double {mustBeInteger, mustBePositive}
    shardCount (1, 1) double {mustBeInteger, mustBePositive}
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 32
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 16
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

if shardIndex > shardCount
    error("r32:InvalidShard", "ShardIndex cannot exceed ShardCount.");
end
project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
packageFolder = fullfile(project, "results", "full_spectrum", ...
    "round32_final_test_protocol_v1");
saved = load(fullfile(packageFolder, "protocol.mat"), ...
    "identity", "design", "source");
if r32.designHash(saved.design) ~= saved.identity.designHash
    error("r32:FinalDesignDrift", ...
        "The design stored in protocol.mat does not match its frozen hash.");
end
currentSource = r32.manifest(project);
currentDigest = r32.sourceDigest(currentSource);
if currentDigest ~= saved.identity.sourceDigest
    error("r32:FinalSourceDrift", ...
        "The current executable source differs from the frozen protocol.");
end
r32.assertFinalTestAuthorized(packageFolder, saved.identity);

rowIndex = find(mod((1:height(saved.design)).'-1, shardCount) == shardIndex-1);
design = saved.design(rowIndex, :);
identity = struct(version="R32-final-test-shard-v1", ...
    protocolIdentity=saved.identity, shardIndex=shardIndex, ...
    shardCount=shardCount, globalRowIndex=rowIndex, ...
    designHash=r32.designHash(design));
folder = fullfile(project, "results", "full_spectrum", ...
    "round32_final_test_v1", sprintf("shard_%02d_of_%02d", ...
    shardIndex, shardCount));
if ~isfolder(folder)
    mkdir(folder);
end
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(design), 1);
if isfile(checkpoint)
    old = load(checkpoint, "identity", "results");
    if ~isequaln(old.identity, identity)
        error("r32:StaleFinalCheckpoint", ...
            "The final-test checkpoint has a different frozen identity.");
    end
    results = old.results;
end

pool = preparePool(options.PoolType, options.NumWorkers);
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
protocol = saved.identity.protocol;
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    indices = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(indices, :);
    batch = cell(numel(indices), 1);
    parfor localIndex = 1:numel(indices)
        batch{localIndex} = r32.finalTrial(cfg, scan, ...
            batchDesign(localIndex, :), protocol);
    end
    results(indices) = batch;
    environment = environmentRecord(pool, options.BatchSize);
    save(checkpoint, "identity", "design", "results", ...
        "environment", "-v7.3");
    fprintf("R32 final shard %d/%d: %d/%d\n", shardIndex, shardCount, ...
        nnz(~cellfun(@isempty, results)), height(design));
end

environment = environmentRecord(pool, options.BatchSize);
save(fullfile(folder, "result.mat"), "identity", "design", ...
    "results", "environment", "-v7.3");
failed = cellfun(@(x) ~x.success, results);
writetable(design(failed, :), fullfile(folder, "failed_rows.csv"));
save(fullfile(folder, "COMPLETE.mat"), "identity", "failed");
fprintf("ROUND32_FINAL_SHARD_COMPLETE shard=%d failures=%d\n", ...
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

function output = environmentRecord(pool, batchSize)
output = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    timestamp=string(datetime("now")));
end
