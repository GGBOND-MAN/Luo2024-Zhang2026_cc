function output = run_round49_wide_support_pilot(options)
%RUN_ROUND49_WIDE_SUPPORT_PILOT Execute the frozen 60-row R49 pilot.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r49.config();
design = r49.design(protocol);
source = r49.manifest(project);
sourceDigest = r32.sourceDigest(source);
folder = fullfile(project, "results", "full_spectrum", ...
    "round49_pfa_wide_support_pilot60_v1");
if isfolder(folder)
    error("r49:OutputExists", ...
        "The immutable R49 development output already exists.");
end
mkdir(folder);
writetable(design, fullfile(folder, "design.csv"));
writetable(source, fullfile(folder, "source_manifest.csv"));
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
results = cell(height(design), 1);
parfor index = 1:height(design)
    results{index} = r49.trial(cfg, scan, design(index, :), index, protocol);
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
        "protocol", "design", "results", "failures", "source", "-v7.3");
    error("r49:TrialFailure", "At least one R49 pilot row failed.");
end
if r32.sourceDigest(r49.manifest(project)) ~= sourceDigest
    error("r49:SourceDrift", "Executable source changed during R49 pilot.");
end
summary = r49.summarize(design, results, protocol);
legacyDesign = r48.design(protocol.r48);
stressRow = legacyDesign(legacyDesign.positionId ...
    == protocol.legacyStress.positionId ...
    & legacyDesign.snrDb == protocol.legacyStress.snrDb, :);
legacyStress = r49.trial(cfg, scan, stressRow, 1, protocol);
if ~legacyStress.success
    error("r49:LegacyStressFailure", ...
        "The excluded R48 design-only stress replay failed.");
end
stressTable = stressSummary(stressRow, legacyStress, protocol);

writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, fullfile(folder, "comparisons.csv"));
writetable(summary.selection.summary, fullfile(folder, "selection.csv"));
writetable(summary.diagnostics, fullfile(folder, "diagnostics.csv"));
writetable(stressTable, fullfile(folder, "legacy_stress.csv"));
identity = struct(version=protocol.version, ...
    evidenceRole=protocol.evidenceRole, completedRows=height(design), ...
    failedRows=0, sourceDigest=sourceDigest, r34FinalRead=false, ...
    r41FinalRead=false, r46FinalRead=false, ...
    r48FinalEstimateRowsRead=false, legacyStressExcluded=true, ...
    selectedCandidate=summary.selection.selected, ...
    pilotPass=summary.pilotPass, workers=pool.NumWorkers, ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "protocol", "identity", ...
    "design", "results", "summary", "legacyStress", ...
    "stressTable", "source", "-v7.3");
output = struct(folder=folder, identity=identity, ...
    summary=summary, stress=stressTable);
fprintf("ROUND49_WIDE_SUPPORT_PILOT_COMPLETE rows=60 selected=%s pass=%d\n", ...
    summary.selection.selected, summary.pilotPass);
disp(summary.selection.summary);
disp(summary.diagnostics);
disp(stressTable);
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

function output = stressSummary(row, result, protocol)
methods = ["P_FA", "P_FAM5", protocol.method.candidates, "P_A"];
output = table();
for method = methods
    estimate = result.(method);
    output = [output; table(method, row.truthThetaDeg, row.truthRangeM, ...
        estimate.thetaDeg, estimate.rangeM, ...
        estimate.thetaDeg-row.truthThetaDeg, ...
        estimate.rangeM-row.truthRangeM, ...
        'VariableNames', {'method', 'truthThetaDeg', 'truthRangeM', ...
        'thetaDeg', 'rangeM', 'angleErrorDeg', 'rangeErrorM'})]; %#ok<AGROW>
end
end
