function output = run_round52_basin_consistency_development(options)
%RUN_ROUND52_BASIN_CONSISTENCY_DEVELOPMENT Execute frozen R52 development.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r52.config();
normalDesign = r52.normalDesign(protocol);
poolDesign = r52.stressPoolDesign(protocol);
source = r52.manifest(project);
sourceDigest = r32.sourceDigest(source);
folder = fullfile(project, "results", "full_spectrum", ...
    "round52_basin_consistency_development_v2");
if isfile(fullfile(folder, "result.mat"))
    error("r52:OutputExists", "The immutable R52 result already exists.");
end
if ~isfolder(folder)
    mkdir(folder);
end
writetable(normalDesign, fullfile(folder, "normal_design.csv"));
writetable(poolDesign, fullfile(folder, "stress_pool_design.csv"));
writetable(source, fullfile(folder, "source_manifest.csv"));

identity = struct(version=protocol.version, sourceDigest=sourceDigest, ...
    normalDesignHash=r32.designHash(normalDesign), ...
    poolDesignHash=r32.designHash(poolDesign));
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);

screening = loadPhase(fullfile(folder, "screening_checkpoint.mat"), ...
    "screening", height(poolDesign), identity);
pending = find(cellfun(@isempty, screening));
batchSize = protocol.execution.screenBatchSize;
for first = 1:batchSize:numel(pending)
    rows = pending(first:min(first+batchSize-1, numel(pending)));
    batchDesign = poolDesign(rows, :);
    batch = cell(numel(rows), 1);
    parfor localIndex = 1:numel(rows)
        batch{localIndex} = r52.screenStressRow(cfg, scan, ...
            batchDesign(localIndex, :), rows(localIndex), protocol);
    end
    screening(rows) = batch;
    savePhase(fullfile(folder, "screening_checkpoint.mat"), ...
        identity, screening);
    fprintf("R52 natural stress screening: %d/%d\n", ...
        nnz(~cellfun(@isempty, screening)), height(poolDesign));
end
screenFailures = failureTable(poolDesign, screening);
writetable(screenFailures, fullfile(folder, "screening_failures.csv"));
if ~isempty(screenFailures)
    error("r52:StressScreeningFailure", ...
        "At least one fixed-pool screening row failed.");
end
stressSelection = r52.selectStress(poolDesign, screening, protocol);
writetable(stressSelection.poolAudit, ...
    fullfile(folder, "stress_pool_audit.csv"));
writetable(stressSelection.classSummary, ...
    fullfile(folder, "stress_class_summary.csv"));
writetable(stressSelection.design, fullfile(folder, "stress_design.csv"));
save(fullfile(folder, "screening_phase.mat"), "protocol", "identity", ...
    "poolDesign", "screening", "stressSelection", "-v7");

normalResults = runTrialPhase(fullfile(folder, "normal_checkpoint.mat"), ...
    normalDesign, identity, cfg, scan, protocol, "normal");
normalFailures = failureTable(normalDesign, normalResults);
writetable(normalFailures, fullfile(folder, "normal_failures.csv"));
if ~isempty(normalFailures)
    error("r52:NormalTrialFailure", "At least one normal row failed.");
end
save(fullfile(folder, "normal_phase.mat"), ...
    "protocol", "identity", "normalDesign", "normalResults", "-v7");

stressResults = runTrialPhase(fullfile(folder, "stress_checkpoint.mat"), ...
    stressSelection.design, identity, cfg, scan, protocol, "stress");
stressFailures = failureTable(stressSelection.design, stressResults);
writetable(stressFailures, fullfile(folder, "stress_failures.csv"));
if ~isempty(stressFailures)
    error("r52:StressTrialFailure", "At least one natural stress row failed.");
end
save(fullfile(folder, "stress_phase.mat"), "protocol", "identity", ...
    "stressSelection", "stressResults", "-v7");

if r32.sourceDigest(r52.manifest(project)) ~= sourceDigest
    error("r52:SourceDrift", "Executable source changed during R52.");
end
summary = r52.summarize( ...
    normalDesign, normalResults, stressSelection, stressResults, protocol);
timing = r52.matchedTiming(normalDesign, cfg, scan, protocol);
runtimeGate = table("mean-complete-runtime/C_enhanced", ...
    timing.comparison.meanRuntimeRatio, "<=", 1.0, ...
    timing.comparison.pass, "predeclared-R52-development-gate", ...
    'VariableNames', summary.gate.Properties.VariableNames);
summary.gate = [summary.gate; runtimeGate];
summary.developmentPass = all(summary.gate.pass);

historical = historicalReplay(cfg, scan, protocol);
writetable(historical, fullfile(folder, "historical_replay.csv"));
writetable(summary.normalPerUser, fullfile(folder, "per_row_results.csv"));
writetable(summary.stressPerUser, fullfile(folder, "stress_results.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, fullfile(folder, "comparisons.csv"));
writetable(summary.bootstrap, fullfile(folder, "bootstrap.csv"));
writetable(summary.normalDiagnostics, ...
    fullfile(folder, "trigger_diagnostics.csv"));
writetable(summary.stressSummary, fullfile(folder, "stress_summary.csv"));
writetable(summary.mechanism, fullfile(folder, "mechanism.csv"));
writetable(summary.gate, fullfile(folder, "gate.csv"));
writetable(timing.rows, fullfile(folder, "matched_timing_rows.csv"));
writetable(timing.summary, fullfile(folder, "matched_timing_summary.csv"));
writetable(timing.comparison, fullfile(folder, "runtime_comparison.csv"));
writetable(runtimeTable(normalDesign, normalResults, "normal"), ...
    fullfile(folder, "runtime_breakdown.csv"));

finalIdentity = struct(version=protocol.version, ...
    completedScreeningRows=height(poolDesign), ...
    completedNormalRows=height(normalDesign), ...
    completedStressRows=height(stressSelection.design), failedRows=0, ...
    sourceDigest=sourceDigest, normalDesignHash=identity.normalDesignHash, ...
    poolDesignHash=identity.poolDesignHash, finalRowsRead=false, ...
    R51ResultsUsedForGate=false, historicalReplayExcludedFromGate=true, ...
    stressConstructionPass=stressSelection.constructionPass, ...
    developmentPass=summary.developmentPass, workers=pool.NumWorkers, ...
    poolClass=class(pool), ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "protocol", "finalIdentity", ...
    "normalDesign", "normalResults", "poolDesign", "screening", ...
    "stressSelection", "stressResults", "summary", "timing", ...
    "historical", "source", "-v7");
output = struct(folder=folder, identity=finalIdentity, ...
    summary=summary, timing=timing, historical=historical);
fprintf("ROUND52_BASIN_CONSISTENCY_COMPLETE pass=%d normal=%d stress=%d\n", ...
    summary.developmentPass, height(normalDesign), height(stressSelection.design));
disp(stressSelection.classSummary);
disp(summary.gate);
disp(summary.normalDiagnostics);
disp(summary.stressSummary);
disp(summary.mechanism);
disp(timing.comparison);
end

function results = runTrialPhase(file, design, identity, cfg, scan, protocol, label)
results = loadPhase(file, "results", height(design), identity);
pending = find(cellfun(@isempty, results));
batchSize = 10;
for first = 1:batchSize:numel(pending)
    rows = pending(first:min(first+batchSize-1, numel(pending)));
    batchDesign = design(rows, :);
    batch = cell(numel(rows), 1);
    parfor localIndex = 1:numel(rows)
        batch{localIndex} = r52.trial(cfg, scan, ...
            batchDesign(localIndex, :), rows(localIndex), protocol);
    end
    results(rows) = batch;
    savePhase(file, identity, results);
    fprintf("R52 %s phase: %d/%d\n", label, ...
        nnz(~cellfun(@isempty, results)), height(design));
end
end

function output = loadPhase(file, variableName, count, identity)
output = cell(count, 1);
if ~isfile(file)
    return;
end
saved = load(file, "identity", variableName);
if ~isequal(saved.identity, identity)
    error("r52:CheckpointIdentityMismatch", ...
        "The R52 checkpoint identity does not match current source/design.");
end
output = saved.(variableName);
if numel(output) ~= count
    error("r52:CheckpointSizeMismatch", ...
        "The R52 checkpoint row count is invalid.");
end
end

function savePhase(file, identity, values)
if contains(file, "screening")
    screening = values; %#ok<NASGU>
    save(file, "identity", "screening", "-v7");
else
    results = values; %#ok<NASGU>
    save(file, "identity", "results", "-v7");
end
end

function failures = failureTable(design, results)
failed = cellfun(@(item) isempty(item) || ~item.success, results);
failures = design(failed, :);
failures.errorIdentifier = strings(nnz(failed), 1);
failures.errorMessage = strings(nnz(failed), 1);
indices = find(failed);
for index = 1:numel(indices)
    item = results{indices(index)};
    if ~isempty(item)
        failures.errorIdentifier(index) = item.errorIdentifier;
        failures.errorMessage(index) = item.errorMessage;
    end
end
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

function output = runtimeTable(design, results, dataset)
output = table(repmat(dataset, height(design), 1), ...
    (1:height(design)).', design.positionId, design.snrDb, ...
    cellfun(@(item) item.backend.frozenR51.certificate.trigger, results), ...
    cellfun(@(item) item.backend.certificate.C3b, results), ...
    cellfun(@(item) item.backend.certificate.trigger, results), ...
    cellfun(@(item) item.backend.recovery.accepted, results), ...
    cellfun(@(item) item.backend.backendSeconds, results), ...
    'VariableNames', {'dataset', 'rowIndex', 'positionId', 'snrDb', ...
    'oldTrigger', 'C3b', 'newTrigger', 'recoveryAccepted', ...
    'backendSeconds'});
end

function output = historicalReplay(cfg, scan, protocol)
r51Design = r51.design(protocol.r51);
r51Row = r51Design(r51Design.positionId ...
    == protocol.execution.historicalR51PositionId ...
    & r51Design.snrDb == protocol.execution.historicalR51SnrDb, :);
r48Design = r48.design(protocol.r51.r50.r48);
r48Row = r48Design(r48Design.positionId ...
    == protocol.execution.historicalR48PositionId ...
    & r48Design.snrDb == protocol.execution.historicalR48SnrDb, :);
rows = {r51Row, r48Row};
labels = ["R51-position11"; "R48-position124"];
output = table();
for index = 1:numel(rows)
    row = rows{index};
    result = r52.trial(cfg, scan, row, 1, protocol);
    if ~result.success
        error("r52:HistoricalReplayFailure", ...
            "The frozen historical replay failed for %s.", labels(index));
    end
    output = [output; table(labels(index), row.positionId, row.snrDb, ...
        row.truthThetaDeg, row.truthRangeM, ...
        result.backend.certificate.C1, result.backend.certificate.C2, ...
        result.backend.certificate.C3a, result.backend.certificate.C3b, ...
        result.backend.certificate.C4, ...
        result.backend.certificate.trigger, ...
        result.P_FA.thetaDeg, result.P_FA.rangeM, ...
        result.P_FARC2.thetaDeg, result.P_FARC2.rangeM, ...
        'VariableNames', {'caseLabel', 'positionId', 'snrDb', ...
        'truthThetaDeg', 'truthRangeM', 'C1', 'C2', 'C3a', 'C3b', ...
        'C4', 'trigger', 'thetaPFA', 'rangePFA', ...
        'thetaPFARC2', 'rangePFARC2'})]; %#ok<AGROW>
end
end
