function run_round30_selected_baselines(options)
%RUN_ROUND30_SELECTED_BASELINES Add same-front public and enhanced MUSIC controls.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
setup = r30.setup(project, "pilot");
aggregateFile = fullfile(project, "results", "full_spectrum", ...
    "round30_pilot_v1", "aggregate", "aggregate.mat");
saved = load(aggregateFile, "design", "results", "selected", "expected");
r30.assertIdentity(saved.expected, setup);
selectedRows = find(ismember(setup.protocol.candidates.candidateId, ...
    saved.selected.candidateId));
root = fullfile(project, "results", "full_spectrum", ...
    "round30_selected_baselines_v1");
if ~isfolder(root)
    mkdir(root);
end
checkpoint = fullfile(root, "checkpoint.mat");
identity = struct(setup=setup, selected=saved.selected, design=saved.design);
results = cell(height(saved.design), numel(selectedRows));
if isfile(checkpoint)
    previous = load(checkpoint);
    r30.assertIdentity(previous.identity, identity);
    results = previous.results;
end
pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= options.NumWorkers
    delete(pool);
    pool = [];
end
if isempty(pool)
    parpool("Threads", options.NumWorkers);
end
cfg = setup.cfg;
protocol = setup.protocol;
publicAlgorithm = protocol.publicZhang;
enhancedAlgorithm = setup.enhancedAlgorithm;
design = saved.design;
pilotResults = saved.results;
selectedRowsLocal = selectedRows;
scan = fsjad.prepareScan(cfg);
tasks = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(tasks)
    task = tasks(first:min(first+options.BatchSize-1, numel(tasks)));
    [taskRow, taskColumn] = ind2sub(size(results), task);
    batchDesign = design(taskRow, :);
    batchSource = cell(numel(task), 1);
    for index = 1:numel(task)
        batchSource{index} = pilotResults{taskRow(index)} ...
            .candidateResults{selectedRowsLocal(taskColumn(index))};
    end
    batch = cell(numel(task), 1);
    parfor index = 1:numel(task)
        replay = fsjad.replayRound27Data(cfg, scan, batchDesign(index, :));
        source = batchSource{index};
        item = source;
        [item.publicBaseline, item.thetaDeg(4), item.rangeM(4)] = ...
            r30.runBaseline(cfg, replay, source.front.selected, ...
            publicAlgorithm);
        [item.enhancedBaseline, item.thetaDeg(5), item.rangeM(5)] = ...
            r30.runBaseline(cfg, replay, source.front.selected, ...
            enhancedAlgorithm);
        batch{index} = item;
    end
    results(task) = batch;
    save(checkpoint, "identity", "results", "-v7.3");
end
save(fullfile(root, "result.mat"), "identity", "results", "-v7.3");
fprintf("ROUND30_SELECTED_BASELINES_COMPLETE rows=%d candidates=%d\n", ...
    height(design), numel(selectedRows));
end
