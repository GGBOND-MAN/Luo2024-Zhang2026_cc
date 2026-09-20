function run_round28_targeted_front_diagnostics(options)
%RUN_ROUND28_TARGETED_FRONT_DIAGNOSTICS Close only predeclared R27 anomalies.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.OutputRoot (1, 1) string = ""
    options.Force (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
originalPath = path;
addpath(project);
cleanup = onCleanup(@() path(originalPath));
if options.OutputRoot == ""
    root = fullfile(project, "results", "full_spectrum", ...
        "round28_targeted_front_closure_v1");
else
    root = options.OutputRoot;
end
if ~isfolder(root)
    mkdir(root);
end
completeFile = fullfile(root, "COMPLETE.csv");
targetSeeds = [36200034; 36300058; 36200114; 36400431; ...
    36200073; 36200111; 36200127; 36200175; 36300167];
iterationCaps = [200, 400, 800];
if isfile(completeFile) && ~options.Force
    complete = readtable(completeFile);
    if isequal(complete.seed, targetSeeds) ...
            && all(complete.iterationCaps == "200/400/800")
        fprintf("ROUND28_TARGETED_DIAGNOSTICS_ALREADY_COMPLETE %s\n", root);
        return;
    end
end

inventory = existingInventory(project);
writetable(inventory, fullfile(root, "existing_diagnostic_inventory.csv"));
fullSetup = fsjad.round27Setup(project, 1000, "formal");
[present, locations] = ismember(targetSeeds, fullSetup.design.seed);
assert(all(present), "fsjad:Round28MissingDiagnosticSeed");
design = fullSetup.design(locations, :);
protocol.version = "Round28-targeted-front-closure-v1";
protocol.iterationCaps = iterationCaps;
protocol.stepTolerance = 1e-6;
protocol.scoreTolerance = 1e-10;
protocol.profileHalfWidthM = 2;
protocol.initialSpacingM = 0.05;
protocol.minimumIntervals = 40;
protocol.refinementLevels = 3;
protocol.peakCount = 8;
protocol.tolX = 1e-6;
protocol.targetSeeds = targetSeeds;
protocol.reason = ["cache_difference"; "front_profile_jump"; ...
    "two_meter_boundary"; "round26_outlier"; ...
    repmat("selected_start_not_converged", 5, 1)];
environment.matlabVersion = version;
environment.computer = computer;
environment.poolType = options.PoolType;
environment.numWorkers = options.NumWorkers;
environment.timestamp = string(datetime("now", TimeZone="local"));
environment.hostName = string(getenv("COMPUTERNAME"));
scan = fsjad.prepareScan(fullSetup.cfg);
existingEstimates = existingTargetEstimates(project, targetSeeds, iterationCaps);
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool(options.PoolType, options.NumWorkers);
end
environment.actualNumWorkers = pool.NumWorkers;
cfg = fullSetup.cfg;
algorithm = fullSetup.zhang;
diagnostics = cell(numel(targetSeeds), 1);
parfor index = 1:numel(targetSeeds)
    diagnostics{index} = fsjad.round28FrontClosureTrial( ...
        cfg, scan, design(index, :), algorithm, protocol, ...
        ExistingEstimates=existingEstimates{index});
end

startTables = cellfun(@(item) item.summary, ...
    diagnostics, UniformOutput=false);
pfTables = cellfun(@(item) item.pfSummary, ...
    diagnostics, UniformOutput=false);
startSummary = vertcat(startTables{:});
pfSummary = vertcat(pfTables{:});
startSummary.reason = repelem(protocol.reason, ...
    numel(iterationCaps)*numel(fullSetup.zhang.frontOffsetsDeg));
pfSummary.reason = repelem(protocol.reason, numel(iterationCaps));
writetable(startSummary, fullfile(root, "all_starts_200_400_800.csv"));
writetable(pfSummary, fullfile(root, "profile_front_extra_start.csv"));
save(fullfile(root, "targeted_front_closure.mat"), "protocol", ...
    "design", "diagnostics", "startSummary", "pfSummary", ...
    "environment", "inventory", "-v7.3");

reproducibility = serialRepeatCheck( ...
    fullSetup, scan, design(1:4, :), diagnostics(1:4), protocol);
writetable(reproducibility, fullfile(root, "serial_repeat_check.csv"));
complete = table(targetSeeds, repmat("200/400/800", numel(targetSeeds), 1), ...
    protocol.reason, 'VariableNames', {'seed', 'iterationCaps', 'reason'});
writetable(complete, completeFile);
fprintf("ROUND28_TARGETED_DIAGNOSTICS_COMPLETE %s\n", root);
end

function estimates = existingTargetEstimates(project, targetSeeds, caps)
estimates = repmat({cell(numel(caps), 1)}, numel(targetSeeds), 1);
file = fullfile(project, "results", "full_spectrum", ...
    "round27_preflight", "outlier_replay.mat");
if ~isfile(file)
    return;
end
saved = load(file, "row", "short", "long");
seedIndex = find(targetSeeds == saved.row.seed, 1);
if isempty(seedIndex)
    return;
end
cap200 = find(caps == 200, 1);
cap400 = find(caps == 400, 1);
if ~isempty(cap200) && saved.short.maxIterations == 200
    estimates{seedIndex}{cap200} = saved.short.allStarts;
end
if ~isempty(cap400) && saved.long.maxIterations == 400
    estimates{seedIndex}{cap400} = saved.long.allStarts;
end
end

function inventory = existingInventory(project)
paths = [fullfile(project, "results", "full_spectrum", ...
    "round27_preflight", "outlier_replay.mat"); ...
    fullfile(project, "results", "full_spectrum", ...
    "round27_front_stability_0010_per_snr", "front_stability_result.mat")];
exists = isfile(paths);
coverage = ["one-seed-selected-path-200-400"; ...
    "thirty-selected-paths-200-400"];
completeForRequestedClosure = false(size(paths));
inventory = table(paths, exists, coverage, completeForRequestedClosure, ...
    'VariableNames', {'path', 'exists', 'coverage', ...
    'completeForRequestedClosure'});
end

function tableOut = serialRepeatCheck(setup, scan, design, reference, protocol)
tableOut = table();
for index = 1:height(design)
    repeated = fsjad.round28FrontClosureTrial( ...
        setup.cfg, scan, design(index, :), setup.zhang, protocol);
    referenceSummary = reference{index}.summary;
    currentSummary = repeated.summary;
    entry = table(design.seed(index), ...
        max(abs(referenceSummary.objective-currentSummary.objective)), ...
        max(abs(referenceSummary.finalThetaDeg-currentSummary.finalThetaDeg)), ...
        max(abs(referenceSummary.finalRangeM-currentSummary.finalRangeM)), ...
        isequal(referenceSummary.status, currentSummary.status), ...
        'VariableNames', {'seed', 'maxObjectiveDifference', ...
        'maxThetaDifferenceDeg', 'maxRangeDifferenceM', 'statusEqual'});
    tableOut = [tableOut; entry]; %#ok<AGROW>
end
end
