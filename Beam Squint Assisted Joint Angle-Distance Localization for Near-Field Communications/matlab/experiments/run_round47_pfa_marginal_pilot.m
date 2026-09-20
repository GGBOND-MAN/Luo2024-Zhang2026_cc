function output = run_round47_pfa_marginal_pilot(options)
%RUN_ROUND47_PFA_MARGINAL_PILOT Execute the new 60-row R47 pilot.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r47.config();
design = r47.design(protocol);
folder = fullfile(project, "results", "full_spectrum", ...
    "round47_pfa_angle_marginal_pilot60_v1");
if isfolder(folder)
    error("r47:OutputExists", ...
        "The immutable R47 development output already exists.");
end
mkdir(folder);
writetable(design, fullfile(folder, "design.csv"));
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
results = cell(height(design), 1);
parfor index = 1:height(design)
    results{index} = r47.trial(cfg, scan, design(index, :), index, protocol);
end
failureMask = cellfun(@(item) ~item.success, results);
failures = design(failureMask, :);
failures.errorIdentifier = cellfun( ...
    @(item) string(item.errorIdentifier), results(failureMask));
failures.errorMessage = cellfun( ...
    @(item) string(item.errorMessage), results(failureMask));
writetable(failures, fullfile(folder, "failures.csv"));
if any(failureMask)
    save(fullfile(folder, "failed_result.mat"), ...
        "protocol", "design", "results", "failures", "-v7.3");
    error("r47:TrialFailure", "At least one R47 pilot row failed.");
end
summary = r47.summarize(design, results, protocol);
writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparison, fullfile(folder, "comparisons.csv"));
writetable(summary.selection.summary, ...
    fullfile(folder, "selection.csv"));
writetable(summary.diagnostics, fullfile(folder, "diagnostics.csv"));
identity = struct(version=protocol.version, ...
    evidenceRole=protocol.evidenceRole, completedRows=height(design), ...
    failedRows=0, r34FinalRead=false, r41FinalRead=false, ...
    r46FinalRead=false, priorEstimateRowsRead=false, ...
    selectedCandidate=summary.selection.selected, ...
    pilotPass=summary.pilotPass, workers=pool.NumWorkers, ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "protocol", "identity", ...
    "design", "results", "summary", "-v7.3");
output = struct(folder=folder, identity=identity, summary=summary);
fprintf("ROUND47_PFA_MARGINAL_PILOT_COMPLETE rows=60 selected=%s pass=%d\n", ...
    summary.selection.selected, summary.pilotPass);
disp(summary.selection.summary);
disp(summary.diagnostics);
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
