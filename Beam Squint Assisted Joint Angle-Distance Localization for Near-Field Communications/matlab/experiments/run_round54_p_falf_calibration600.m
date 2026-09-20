function output = run_round54_p_falf_calibration600(options)
%RUN_ROUND54_P_FALF_CALIBRATION600 Execute frozen R54 calibration.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r54.config();
frozenR53Source = r53.manifest(project);
frozenR53Digest = r32.sourceDigest(frozenR53Source);
frozenPfaSource = r45.manifest(project);
frozenPfaDigest = r32.sourceDigest(frozenPfaSource);
if frozenR53Digest ~= protocol.freeze.expectedR53SourceDigest
    error("r54:FrozenR53DigestMismatch", ...
        "The frozen R53 implementation does not match its accepted digest.");
end
if frozenPfaDigest ~= protocol.freeze.expectedPfaSourceDigest
    error("r54:FrozenPfaDigestMismatch", ...
        "The frozen P_FA implementation does not match its accepted digest.");
end

design = r54.design(protocol);
source = r54.manifest(project);
sourceDigest = r32.sourceDigest(source);
designHash = r32.designHash(design);
folder = fullfile(project, "results", "full_spectrum", ...
    "round54_p_falf_calibration600_v1");
resultFile = fullfile(folder, "result.mat");
if isfile(resultFile)
    error("r54:OutputExists", "The immutable R54 result already exists.");
end
if ~isfolder(folder)
    mkdir(folder);
end
writetable(design, fullfile(folder, "design.csv"));
writetable(source, fullfile(folder, "source_hashes.csv"));
writetable(frozenR53Source, fullfile(folder, "frozen_r53_source_hashes.csv"));
writetable(frozenPfaSource, fullfile(folder, "frozen_pfa_source_hashes.csv"));

identity = struct(version=protocol.version, sourceDigest=sourceDigest, ...
    frozenR53Digest=frozenR53Digest, frozenPfaDigest=frozenPfaDigest, ...
    designHash=designHash);
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
            batchDesign(localIndex, :), rows(localIndex), protocol.candidate);
    end
    results(rows) = batch;
    saveCheckpoint(checkpoint, identity, results);
    fprintf("R54 calibration: %d/%d\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end

failures = failureTable(design, results);
writetable(failures, fullfile(folder, "failures.csv"));
if ~isempty(failures)
    error("r54:TrialFailure", "At least one R54 calibration row failed.");
end
if r32.sourceDigest(r54.manifest(project)) ~= sourceDigest
    error("r54:SourceDrift", "Executable source changed during R54.");
end
if r32.sourceDigest(r53.manifest(project)) ~= frozenR53Digest
    error("r54:FrozenR53Drift", "Frozen R53 changed during R54.");
end
if r32.sourceDigest(r45.manifest(project)) ~= frozenPfaDigest
    error("r54:FrozenPfaDrift", "Frozen P_FA changed during R54.");
end

summary = r54.summarize(design, results, protocol);
writetable(summary.perUser, fullfile(folder, "per_row.csv"));
writetable([summary.all600.methodSummary; ...
    summary.holdout540.methodSummary; summary.diagnostic60.methodSummary], ...
    fullfile(folder, "method_summary.csv"));
writetable([summary.all600.comparisons; ...
    summary.holdout540.comparisons; summary.diagnostic60.comparisons], ...
    fullfile(folder, "performance_tables.csv"));
writetable([summary.all600.bootstrap; summary.holdout540.bootstrap; ...
    summary.diagnostic60.bootstrap], fullfile(folder, "bootstrap.csv"));
writetable([summary.all600.mechanism; summary.holdout540.mechanism; ...
    summary.diagnostic60.mechanism], fullfile(folder, "mechanism.csv"));
writetable(summary.gate, fullfile(folder, "gate.csv"));
writetable(summary.decision, fullfile(folder, "decision.csv"));

finalIdentity = struct(version=protocol.version, completedRows=height(design), ...
    failedRows=0, sourceDigest=sourceDigest, ...
    frozenR53Digest=frozenR53Digest, frozenPfaDigest=frozenPfaDigest, ...
    designHash=designHash, finalRowsRead=false, ...
    priorCalibrationRowsRead=false, R51R52RowsRead=false, ...
    parameterTuningPerformed=false, calibrationReady=summary.calibrationReady, ...
    workers=pool.NumWorkers, poolClass=class(pool), ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(resultFile, "protocol", "finalIdentity", "design", "results", ...
    "summary", "source", "frozenR53Source", "frozenPfaSource", "-v7");
output = struct(folder=folder, identity=finalIdentity, summary=summary);
fprintf("ROUND54_PFALF_CALIBRATION_COMPLETE ready=%d rows=%d failures=0\n", ...
    summary.calibrationReady, height(design));
disp(summary.gate);
disp(summary.decision);
end

function output = loadCheckpoint(file, count, identity, resume)
output = cell(count, 1);
if ~resume || ~isfile(file)
    return;
end
saved = load(file, "identity", "results");
if ~isequal(saved.identity, identity) || numel(saved.results) ~= count
    error("r54:CheckpointIdentityMismatch", ...
        "The R54 checkpoint identity is invalid.");
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
