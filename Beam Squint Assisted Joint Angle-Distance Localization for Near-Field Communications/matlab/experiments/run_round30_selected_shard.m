function run_round30_selected_shard(shardId, shardCount, options)
%RUN_ROUND30_SELECTED_SHARD Extend at most two selected candidates to 600 users.

arguments
    shardId (1, 1) double {mustBeInteger, mustBePositive}
    shardCount (1, 1) double {mustBeInteger, mustBePositive}
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 32
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 16
end

if shardId > shardCount
    error("r30:InvalidSelectedShard", "shardId must not exceed shardCount.");
end
project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
setup = r30.setup(project, "calibration600");
selectionFile = fullfile(project, "results", "full_spectrum", ...
    "round30_pilot_v1", "aggregate", "selection.mat");
selection = load(selectionFile, "selected", "expected");
pilotSetup = r30.setup(project, "pilot");
r30.assertIdentity(selection.expected, pilotSetup);
selectedRows = find(ismember(setup.protocol.candidates.candidateId, ...
    selection.selected.candidateId));
candidates = setup.protocol.candidates(selectedRows, :);
preflight = load(fullfile(project, "results", "full_spectrum", ...
    "round30_preflight_v1", "preflight.mat"));
if ~preflight.passed || ~isequaln(preflight.source, setup.source)
    error("r30:StaleSelectedPreflight", ...
        "Run preflight_round30 after the last source change.");
end

rows = (shardId:shardCount:height(setup.design)).';
design = setup.design(rows, :);
identity = struct(setup=setup, selected=selection.selected, ...
    candidates=candidates, design=design, ...
    shardId=shardId, shardCount=shardCount);
root = fullfile(project, "results", "full_spectrum", ...
    "round30_calibration600_v1", ...
    sprintf("shard_%02d_of_%02d", shardId, shardCount));
if ~isfolder(root)
    mkdir(root);
end
checkpoint = fullfile(root, "checkpoint.mat");
results = cell(height(design), 1);
if isfile(checkpoint)
    saved = load(checkpoint);
    r30.assertIdentity(saved.identity, identity);
    results = saved.results;
end
pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= options.NumWorkers
    delete(pool);
    pool = [];
end
if isempty(pool)
    pool = parpool("Threads", options.NumWorkers);
end
environment = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), ...
    batchSize=options.BatchSize, timestamp=string(datetime("now")));
cfg = setup.cfg;
protocol = setup.protocol;
scan = fsjad.prepareScan(cfg);
pending = find(cellfun(@isempty, results));
timer = tic;
for first = 1:options.BatchSize:numel(pending)
    taskRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(taskRows, :);
    batch = cell(numel(taskRows), 1);
    parfor index = 1:numel(taskRows)
        batch{index} = r30.screenRow(cfg, scan, ...
            protocol, candidates, batchDesign(index, :));
    end
    results(taskRows) = batch;
    save(checkpoint, "identity", "results", "environment", "-v7.3");
    fprintf("R30 selected shard %d: %d/%d session %.2f h\n", ...
        shardId, nnz(~cellfun(@isempty, results)), height(design), toc(timer)/3600);
end
save(fullfile(root, "result.mat"), ...
    "identity", "results", "environment", "-v7.3");
failed = cellfun(@(item) ~item.success, results);
writetable(design(failed, :), fullfile(root, "failures.csv"));
writetable(setup.source, fullfile(root, "source_hashes.csv"));
save(fullfile(root, "COMPLETE.mat"), "identity", "failed");
fprintf("ROUND30_SELECTED_SHARD_COMPLETE failures=%d\n", nnz(failed));
end
