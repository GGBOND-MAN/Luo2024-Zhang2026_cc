function run_round28_fixed_angle_shard(shardId, shardCount, options)
%RUN_ROUND28_FIXED_ANGLE_SHARD Incrementally add fixed-angle range ablations.

arguments
    shardId (1, 1) double {mustBeInteger, mustBePositive}
    shardCount (1, 1) double {mustBeInteger, mustBePositive}
    options.Round27AggregateFile (1, 1) string = ""
    options.CountPerSnr (1, 1) double {mustBeInteger, mustBePositive} = 200
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Protocol (1, 1) string ...
        {mustBeMember(options.Protocol, ["development", "formal"])} = "formal"
    options.OutputRoot (1, 1) string = ""
    options.RunExpansion (1, 1) logical = true
end

assert(shardId <= shardCount, "fsjad:Round28ShardId");
project = string(fileparts(fileparts(mfilename("fullpath"))));
originalPath = path;
addpath(project);
cleanup = onCleanup(@() path(originalPath));
if options.Round27AggregateFile == ""
    options.Round27AggregateFile = fullfile(project, "results", ...
        "full_spectrum", "round27_v3_0200_per_snr", "aggregate", ...
        "round27_aggregate.mat");
end
loaded = fsjad.round28Setup(project, options.Round27AggregateFile, ...
    options.CountPerSnr, options.Protocol);
if options.Protocol == "formal"
    passFile = fullfile(project, "results", "full_spectrum", ...
        "round28_preflight", "preflight_passed.mat");
    assert(isfile(passFile), "fsjad:Round28PreflightRequired", ...
        "Run preflight_round28 successfully on this server first.");
    passed = load(passFile, "source");
    assert(isequal(passed.source, loaded.source), ...
        "fsjad:Round28PreflightStale", ...
        "Source changed after preflight; rerun preflight_round28.");
end
loaded.protocol.shardCount = shardCount;
rows = mod(loaded.design.trialIndex-1, shardCount) == shardId-1;
design = loaded.design(rows, :);
oldResults = loaded.oldResults(rows);
setup = rmfield(loaded, "oldResults");
assert(~isempty(design), "fsjad:Round28EmptyShard");
if options.OutputRoot == ""
    folderName = sprintf("round28_v1_%04d_per_snr", options.CountPerSnr);
    outputRoot = fullfile(project, "results", "full_spectrum", folderName);
else
    outputRoot = options.OutputRoot;
end
folder = fullfile(outputRoot, ...
    sprintf("shard_%02d_of_%02d", shardId, shardCount));
if ~isfolder(folder)
    mkdir(folder);
end
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(design), 1);
if isfile(checkpoint)
    saved = load(checkpoint);
    assert(isequaln(saved.setup, setup) && isequal(saved.design, design) ...
        && saved.shardId == shardId, "fsjad:Round28CheckpointMismatch", ...
        "Protocol, source, or saved rows changed; do not mix checkpoints.");
    results = saved.results;
end
environment = environmentSnapshot(options);
scan = fsjad.prepareScan(setup.cfg);
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool(options.PoolType, options.NumWorkers);
elseif pool.NumWorkers ~= options.NumWorkers
    warning("fsjad:Round28ExistingPool", ...
        "Using existing pool with %d workers.", pool.NumWorkers);
end
environment.actualNumWorkers = pool.NumWorkers;
environment.actualPoolClass = class(pool);
pending = find(cellfun(@isempty, results));
timer = tic;
runExpansion = options.RunExpansion;
for first = 1:options.BatchSize:numel(pending)
    batchRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(batchRows, :);
    batchOld = oldResults(batchRows);
    batch = cell(numel(batchRows), 1);
    parfor index = 1:numel(batchRows)
        batch{index} = fsjad.round28IncrementalTrial( ...
            setup, scan, batchDesign(index, :), batchOld{index}, ...
            RunExpansion=runExpansion);
    end
    results(batchRows) = batch;
    save(checkpoint+".next.mat", "setup", "design", "results", ...
        "shardId", "environment", "-v7.3");
    movefile(checkpoint+".next.mat", checkpoint, "f");
    fprintf("R28 shard %d/%d: %d/%d, session %.2f h\n", ...
        shardId, shardCount, sum(~cellfun(@isempty, results)), ...
        height(design), toc(timer)/3600);
end
save(fullfile(folder, "shard_result.mat"), "setup", "design", ...
    "results", "shardId", "environment", "-v7.3");
successful = cellfun(@(item) item.success, results);
failures = design(~successful, :);
failures.errorIdentifier = string(cellfun(@(item) item.errorIdentifier, ...
    results(~successful), UniformOutput=false));
failures.errorMessage = string(cellfun(@(item) item.errorMessage, ...
    results(~successful), UniformOutput=false));
writetable(failures, fullfile(folder, "failures.csv"));
assert(all(successful), "fsjad:Round28TrialFailure", ...
    "At least one row failed; failures are retained in failures.csv.");
marker = table(string(setup.protocol.version), shardId, shardCount, ...
    options.CountPerSnr, height(design), ...
    'VariableNames', {'protocolVersion', 'shardId', 'shardCount', ...
    'countPerSnr', 'completedRows'});
writetable(marker, fullfile(folder, "COMPLETE.csv"));
fprintf("ROUND28_SHARD_COMPLETE %s\n", folder);
end

function environment = environmentSnapshot(options)
environment.matlabVersion = version;
environment.computer = computer;
environment.requestedNumWorkers = options.NumWorkers;
environment.poolType = options.PoolType;
environment.batchSize = options.BatchSize;
environment.runExpansion = options.RunExpansion;
environment.timestamp = string(datetime("now", TimeZone="local"));
environment.hostName = string(getenv("COMPUTERNAME"));
if environment.hostName == ""
    environment.hostName = string(getenv("HOSTNAME"));
end
end
