function output = run_round44_clock_invariant_pilot(options)
%RUN_ROUND44_CLOCK_INVARIANT_PILOT Execute the new R44 pilot.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
addpath(fullfile(project, "+r38", "schemeF"));
protocol = r44.config();
design = r44.design(protocol.development.positionCount, protocol);
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
folder = fullfile(project, "results", "full_spectrum", ...
    "round44_clock_invariant_sequential_development_v1", ...
    "positions_10");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(design, fullfile(folder, "design.csv"));
pool = gcp("nocreate");
requiredClass = "parallel.ThreadPool";
if options.PoolType == "Processes"
    requiredClass = "parallel.ProcessPool";
end
if ~isempty(pool) && string(class(pool)) ~= requiredClass
    delete(pool);
    pool = [];
end
if isempty(pool)
    parpool(options.PoolType, options.NumWorkers);
end
results = cell(height(design), 1);
parfor index = 1:height(design)
    results{index} = r44.trial(cfg, scan, design(index, :), index, protocol);
end
save(fullfile(folder, "raw_results.mat"), ...
    "protocol", "design", "results", "-v7.3");
failureMask = ~cellfun(@(x) x.success, results);
failures = design(failureMask, :);
writetable(failures, fullfile(folder, "failures.csv"));
if any(failureMask)
    error("r44:TrialFailure", "At least one R44 development row failed.");
end
summary = r44.summarize(design, results, protocol);
writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparison, fullfile(folder, "comparisons.csv"));
writetable(summary.gate, fullfile(folder, "engineering_gate.csv"));
identity = struct(version=protocol.version, date=protocol.date, ...
    evidenceRole=protocol.evidenceRole, completedRows=height(design), ...
    positionCount=protocol.development.positionCount, ...
    finalTrialsReadOrExecuted=0, r34FinalRead=false, r41FinalRead=false, ...
    priorDevelopmentResultsRead=false, parameterTuningPerformed=false, ...
    pilotPass=summary.gate.pilotPass);
save(fullfile(folder, "result.mat"), "protocol", "identity", ...
    "design", "results", "summary", "-v7.3");
output = struct(folder=folder, identity=identity, summary=summary);
fprintf("ROUND44_CLOCK_INVARIANT_COMPLETE rows=%d pass=%d final=0\n", ...
    height(design), summary.gate.pilotPass);
disp(summary.comparison);
disp(summary.gate);
end
