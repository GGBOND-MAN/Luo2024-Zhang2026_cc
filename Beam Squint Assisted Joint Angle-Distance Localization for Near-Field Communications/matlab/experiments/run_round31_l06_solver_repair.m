function run_round31_l06_solver_repair(options)
%RUN_ROUND31_L06_SOLVER_REPAIR Recompute only the L06 scalar backend.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
protocol = r31.config();
identity = struct(version="R31-L06-scalar-repair-v2", ...
    protocol=protocol, design=raw.pilot.design, ...
    pilotHash=raw.pilotHash, source=raw.source);
folder = fullfile(project, "results", "full_spectrum", ...
    "round31_l06_scalar_repair_v2");
if ~isfolder(folder)
    mkdir(folder);
end
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(raw.pilot.design), 1);
if isfile(checkpoint)
    saved = load(checkpoint, "identity", "results");
    if ~isequaln(saved.identity, identity)
        error("r31:StaleRepairCheckpoint", ...
            "The saved L06 repair checkpoint has a different identity.");
    end
    results = saved.results;
end

pool = gcp("nocreate");
requiredClass = "parallel.ThreadPool";
if options.PoolType == "Processes"
    requiredClass = "parallel.ProcessPool";
end
if ~isempty(pool) && (pool.NumWorkers ~= options.NumWorkers ...
        || string(class(pool)) ~= requiredClass)
    delete(pool);
    pool = [];
end
if isempty(pool)
    pool = parpool(options.PoolType, options.NumWorkers);
end

cfg = raw.pilot.expected.cfg;
scan = fsjad.prepareScan(cfg);
design = raw.pilot.design;
oldResults = raw.pilot.results;
l06Index = raw.l06PilotIndex;
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    taskRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batch = cell(numel(taskRows), 1);
    batchDesign = design(taskRows, :);
    batchOld = cellfun(@(item) item.candidateResults{l06Index}, ...
        oldResults(taskRows), UniformOutput=false);
    batchReplay = cell(numel(taskRows), 1);
    batchHash = cell(numel(taskRows), 1);
    for index = 1:numel(taskRows)
        batchReplay{index} = fsjad.replayRound27Data( ...
            cfg, scan, batchDesign(index, :));
        selectedFront = batchOld{index}.front.selected;
        batchHash{index} = struct( ...
            observation=r31.arrayHash(batchReplay{index}.observation), ...
            front=r31.arrayHash( ...
            [selectedFront.thetaDeg; selectedFront.rangeM]));
    end
    parfor index = 1:numel(taskRows)
        batch{index} = r31.repairL06Trial( ...
            cfg, scan, batchDesign(index, :), batchReplay{index}, ...
            batchHash{index}, batchOld{index}, protocol);
    end
    results(taskRows) = batch;
    environment = executionEnvironment(pool, options.BatchSize);
    save(checkpoint, "identity", "results", "environment", "-v7.3");
    fprintf("R31 L06 repair: %d/%d\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end

environment = executionEnvironment(pool, options.BatchSize);
save(fullfile(folder, "result.mat"), ...
    "identity", "results", "environment", "-v7.3");
failed = cellfun(@(item) ~item.success, results);
writetable(design(failed, :), fullfile(folder, "failed_rows.csv"));
writetable(raw.source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "COMPLETE.mat"), "identity", "failed");
fprintf("ROUND31_L06_REPAIR_COMPLETE failures=%d\n", nnz(failed));
end

function environment = executionEnvironment(pool, batchSize)
environment = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    timestamp=string(datetime("now")));
end
