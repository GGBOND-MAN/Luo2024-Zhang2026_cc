function output = run_round42_schemeH_development(options)
%RUN_ROUND42_SCHEMEH_DEVELOPMENT Execute the new PA-free pilot.

arguments
    options.PositionCount (1, 1) double {mustBeInteger, mustBePositive} = 10
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
addpath(fullfile(project, "+r38", "schemeF"));
protocol = r42.config();
if options.PositionCount > protocol.development.expandedPositionCount
    error("r42:PositionCount", ...
        "R42 development cannot exceed the frozen expanded position count.");
end
design = r42.design(options.PositionCount, protocol);
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
folder = fullfile(project, "results", "full_spectrum", ...
    "round42_schemeH_pa_free_joint_development_v1", ...
    sprintf("positions_%02d", options.PositionCount));
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
    results{index} = r42.trial(cfg, scan, design(index, :), index, protocol);
end
save(fullfile(folder, "raw_results.mat"), ...
    "protocol", "design", "results", "-v7.3");
failureMask = ~cellfun(@(x) x.success, results);
failures = design(failureMask, :);
writetable(failures, fullfile(folder, "failures.csv"));
if any(failureMask)
    save(fullfile(folder, "failed_result.mat"), ...
        "protocol", "design", "results", "failures", "-v7.3");
    error("r42:TrialFailure", "At least one R42 development row failed.");
end
summary = r42.summarize(design, results, protocol);
writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.summary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparison, fullfile(folder, "comparison_vs_pa.csv"));
writetable(summary.aggregate, fullfile(folder, "aggregate_vs_pa.csv"));
writetable(summary.gate, fullfile(folder, "engineering_gate.csv"));
identity = struct(version=protocol.version, date=protocol.date, ...
    evidenceRole=protocol.evidenceRole, completedRows=height(design), ...
    positionCount=options.PositionCount, finalTrialsReadOrExecuted=0, ...
    r34FinalRead=false, r41FinalRead=false, ...
    parameterTuningPerformed=false, pilotPass=summary.gate.pilotPass);
save(fullfile(folder, "result.mat"), "protocol", "identity", ...
    "design", "results", "summary", "-v7.3");
output = struct(folder=folder, identity=identity, summary=summary);
fprintf("ROUND42_SCHEME_H_COMPLETE positions=%d rows=%d pass=%d final=0\n", ...
    options.PositionCount, height(design), summary.gate.pilotPass);
disp(summary.comparison);
disp(summary.aggregate);
disp(summary.gate);
end
