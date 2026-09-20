function run_round31_angle_controls(options)
%RUN_ROUND31_ANGLE_CONTROLS Run fixed-front C/A/B on the existing 60 users.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
raw = r31.loadRound30Raw(project);
protocol = r31.config();
identity = struct(version="R31-fixed-front-CAB-v2", protocol=protocol, ...
    design=raw.pilot.design, pilotHash=raw.pilotHash, ...
    baselineHash=raw.baselineHash, source=raw.source, ...
    l06Candidate=raw.l06Candidate, ...
    enhancedAlgorithm=raw.pilot.expected.enhancedAlgorithm);
folder = fullfile(project, "results", "full_spectrum", ...
    "round31_angle_controls_v2");
if ~isfolder(folder)
    mkdir(folder);
end
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(raw.pilot.design), 1);
if isfile(checkpoint)
    saved = load(checkpoint, "identity", "results");
    if ~isequaln(saved.identity, identity)
        error("r31:StaleControlCheckpoint", ...
            "The saved C/A/B checkpoint has a different identity.");
    end
    results = saved.results;
end

pool = preparePool(options.PoolType, options.NumWorkers);
cfg = raw.pilot.expected.cfg;
scan = fsjad.prepareScan(cfg);
design = raw.pilot.design;
pilotResults = raw.pilot.results;
baselineResults = raw.baselines.results;
l06PilotIndex = raw.l06PilotIndex;
l06BaselineIndex = raw.l06BaselineIndex;
enhancedAlgorithm = raw.pilot.expected.enhancedAlgorithm;
l06Candidate = raw.l06Candidate;
pending = find(cellfun(@isempty, results));

for first = 1:options.BatchSize:numel(pending)
    taskRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(taskRows, :);
    batchPilot = cellfun(@(item) item.candidateResults{l06PilotIndex}, ...
        pilotResults(taskRows), UniformOutput=false);
    batchBaseline = baselineResults(taskRows, l06BaselineIndex);
    batch = cell(numel(taskRows), 1);
    batchReplay = cell(numel(taskRows), 1);
    batchHash = cell(numel(taskRows), 1);
    for index = 1:numel(taskRows)
        batchReplay{index} = fsjad.replayRound27Data( ...
            cfg, scan, batchDesign(index, :));
        batchHash{index} = struct( ...
            observation=r31.arrayHash(batchReplay{index}.observation), ...
            snapshots=r31.arrayHash(batchReplay{index}.snapshots), ...
            frontSignalVectors=r31.arrayHash( ...
            batchBaseline{index}.enhancedBaseline.estimate.signalVectors));
    end
    parfor index = 1:numel(taskRows)
        batch{index} = r31.controlTrial(cfg, scan, batchDesign(index, :), ...
            batchReplay{index}, batchHash{index}, batchPilot{index}, ...
            batchBaseline{index}, enhancedAlgorithm, protocol, l06Candidate);
    end
    results(taskRows) = batch;
    environment = executionEnvironment(pool, options.BatchSize);
    save(checkpoint, "identity", "results", "environment", "-v7.3");
    fprintf("R31 C/A/B: %d/%d\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end

environment = executionEnvironment(pool, options.BatchSize);
save(fullfile(folder, "result.mat"), ...
    "identity", "results", "environment", "-v7.3");
failed = cellfun(@(item) ~item.success, results);
writetable(design(failed, :), fullfile(folder, "failed_rows.csv"));
writetable(raw.source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "COMPLETE.mat"), "identity", "failed");
fprintf("ROUND31_ANGLE_CONTROLS_COMPLETE failures=%d\n", nnz(failed));
end

function pool = preparePool(poolType, workerCount)
pool = gcp("nocreate");
requiredClass = "parallel.ThreadPool";
if poolType == "Processes"
    requiredClass = "parallel.ProcessPool";
end
if ~isempty(pool) && (pool.NumWorkers ~= workerCount ...
        || string(class(pool)) ~= requiredClass)
    delete(pool);
    pool = [];
end
if isempty(pool)
    pool = parpool(poolType, workerCount);
end
end

function environment = executionEnvironment(pool, batchSize)
environment = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    timestamp=string(datetime("now")));
end
