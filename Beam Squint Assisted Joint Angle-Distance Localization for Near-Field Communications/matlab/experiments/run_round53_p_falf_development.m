function output = run_round53_p_falf_development(options)
%RUN_ROUND53_P_FALF_DEVELOPMENT Execute frozen R53 development.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r53.config();
if ~protocol.audit.statisticalModelGate
    error("r53:StatisticalModelGate", ...
        "R53 cannot run because the statistical model gate failed.");
end
design = r53.design(protocol);
source = r53.manifest(project);
sourceDigest = r32.sourceDigest(source);
frozenPfaSource = r45.manifest(project);
frozenPfaDigest = r32.sourceDigest(frozenPfaSource);
designHash = r32.designHash(design);
folder = fullfile(project, "results", "full_spectrum", ...
    "round53_p_falf_development_v1");
resultFile = fullfile(folder, "result.mat");
if isfile(resultFile)
    error("r53:OutputExists", "The immutable R53 result already exists.");
end
if ~isfolder(folder)
    mkdir(folder);
end
writetable(design, fullfile(folder, "design.csv"));
writetable(source, fullfile(folder, "source_hashes.csv"));
writetable(frozenPfaSource, fullfile(folder, "frozen_pfa_source_hashes.csv"));
writetable(auditTable(protocol), fullfile(folder, "data_genealogy_audit.csv"));

identity = struct(version=protocol.version, sourceDigest=sourceDigest, ...
    frozenPfaDigest=frozenPfaDigest, designHash=designHash, ...
    statisticalModelGate=protocol.audit.statisticalModelGate);
checkpoint = fullfile(folder, "checkpoint.mat");
results = loadCheckpoint(checkpoint, height(design), identity, options.Resume);
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
pending = find(cellfun(@isempty, results));
for first = 1:protocol.execution.batchSize:numel(pending)
    rows = pending(first:min(first+protocol.execution.batchSize-1, ...
        numel(pending)));
    batchDesign = design(rows, :);
    batch = cell(numel(rows), 1);
    parfor localIndex = 1:numel(rows)
        batch{localIndex} = r53.trial(cfg, scan, ...
            batchDesign(localIndex, :), rows(localIndex), protocol);
    end
    results(rows) = batch;
    saveCheckpoint(checkpoint, identity, results);
    fprintf("R53 development: %d/%d\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end

failures = failureTable(design, results);
writetable(failures, fullfile(folder, "failures.csv"));
if ~isempty(failures)
    error("r53:TrialFailure", "At least one R53 development row failed.");
end
if r32.sourceDigest(r53.manifest(project)) ~= sourceDigest
    error("r53:SourceDrift", "Executable source changed during R53.");
end
if r32.sourceDigest(r45.manifest(project)) ~= frozenPfaDigest
    error("r53:FrozenPfaDrift", "Frozen P_FA source changed during R53.");
end

summary = r53.summarize(design, results, protocol);
timing = r53.matchedTiming(design, cfg, scan, protocol);
runtimeGate = table("complete-runtime/P_C_enhanced", ...
    timing.comparison.meanRuntimeRatio, "<=", 1.0, ...
    timing.comparison.pass, "predeclared-R53-development-gate", ...
    'VariableNames', summary.gate.Properties.VariableNames);
summary.gate = [summary.gate; runtimeGate];
summary.developmentPass = all(summary.gate.pass);

writetable(summary.perUser, fullfile(folder, "per_row.csv"));
writetable(curvatureTable(summary.perUser), ...
    fullfile(folder, "curvature_diagnostics.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, fullfile(folder, "performance_tables.csv"));
writetable(summary.bootstrap, fullfile(folder, "bootstrap.csv"));
writetable(summary.mechanism, fullfile(folder, "mechanism.csv"));
writetable(summary.gate, fullfile(folder, "gate.csv"));
writetable(timing.rows, fullfile(folder, "runtime_rows.csv"));
writetable(timing.summary, fullfile(folder, "runtime.csv"));
writetable(timing.comparison, fullfile(folder, "runtime_comparison.csv"));

finalIdentity = struct(version=protocol.version, completedRows=height(design), ...
    failedRows=0, sourceDigest=sourceDigest, ...
    frozenPfaDigest=frozenPfaDigest, designHash=designHash, ...
    statisticalModelGate=protocol.audit.statisticalModelGate, ...
    finalRowsRead=false, calibrationRowsRead=false, ...
    R51R52RowsRead=false, parameterTuningPerformed=false, ...
    developmentPass=summary.developmentPass, workers=pool.NumWorkers, ...
    poolClass=class(pool), ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(resultFile, "protocol", "finalIdentity", "design", "results", ...
    "summary", "timing", "source", "frozenPfaSource", "-v7");
output = struct(folder=folder, identity=finalIdentity, ...
    summary=summary, timing=timing);
fprintf("ROUND53_PFALF_COMPLETE pass=%d rows=%d failures=0\n", ...
    summary.developmentPass, height(design));
disp(summary.gate);
disp(summary.comparisons(summary.comparisons.candidate == "P_FALF", :));
disp(summary.mechanism);
disp(timing.comparison);
end

function output = auditTable(protocol)
question = ["z-derived-from-Y"; "shared-noise-realization"; ...
    "nonoverlapping-random-draws"; "conditional-independence-simulator"; ...
    "separate-normalization"; "physical-same-receiver-established"; ...
    "statistical-model-gate"];
value = [protocol.audit.zDerivedFromY; ...
    protocol.audit.sharedNoiseRealization; ...
    protocol.audit.sequentialNonoverlappingRandomDraws; ...
    protocol.audit.conditionallyIndependentUnderSimulator; ...
    protocol.audit.separatelyNormalized; ...
    protocol.audit.physicalSameReceiverInterpretationEstablished; ...
    protocol.audit.statisticalModelGate];
output = table(question, value);
end

function output = curvatureTable(input)
names = ["positionId", "seed", "snrDb", "range_P_FA", ...
    "range_P_FALF", "rangeShiftM", "qPeakChanged", ...
    "yOnlyZBasinAgreement", "hessianZAtPFA", "hessianYAtPFA", ...
    "hessianJointAtPFA", "curvatureRatioYToZ", ...
    "hessianJointAtSelected"];
output = input(:, names);
end

function output = loadCheckpoint(file, count, identity, resume)
output = cell(count, 1);
if ~resume || ~isfile(file)
    return;
end
saved = load(file, "identity", "results");
if ~isequal(saved.identity, identity) || numel(saved.results) ~= count
    error("r53:CheckpointIdentityMismatch", ...
        "The R53 checkpoint identity is invalid.");
end
output = saved.results;
end

function saveCheckpoint(file, identity, results)
temporary = file+".tmp";
save(temporary, "identity", "results", "-v7");
movefile(temporary, file, "f");
end

function output = failureTable(design, results)
failed = cellfun(@isempty, results) ...
    | cellfun(@(item) ~isempty(item) && ~item.success, results);
output = design(failed, :);
if any(failed)
    output.errorIdentifier = strings(nnz(failed), 1);
    output.errorMessage = strings(nnz(failed), 1);
    indices = find(failed);
    for index = 1:numel(indices)
        if ~isempty(results{indices(index)})
            output.errorIdentifier(index) = ...
                results{indices(index)}.errorIdentifier;
            output.errorMessage(index) = results{indices(index)}.errorMessage;
        end
    end
end
end

function pool = preparePool(poolType, workers)
pool = gcp("nocreate");
requiredClass = "parallel.ThreadPool";
if poolType == "Processes"
    requiredClass = "parallel.ProcessPool";
end
if ~isempty(pool) && string(class(pool)) ~= requiredClass
    delete(pool);
    pool = [];
end
if isempty(pool)
    pool = parpool(poolType, workers);
end
end
