function output = run_round50_range_conditioning_diagnostics(options)
%RUN_ROUND50_RANGE_CONDITIONING_DIAGNOSTICS Execute frozen R50 diagnostics.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = true
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r50.config();
r48Folder = fullfile(project, "results", "full_spectrum", ...
    "round48_pfam5_calibration600_v1");
r48Data = load(fullfile(r48Folder, "result.mat"), ...
    "design", "results", "finalIdentity");
design = r48Data.design;
if height(design) ~= 600 || numel(r48Data.results) ~= 600 ...
        || r48Data.finalIdentity.completedRows ~= 600
    error("r50:InvalidR48Source", ...
        "R50 requires the complete frozen R48 calibration-600 result.");
end
source = r50.manifest(project);
sourceDigest = r32.sourceDigest(source);
identity = struct(version=protocol.version, ...
    sourceDigest=sourceDigest, designHash=r32.designHash(design), ...
    r48SourceDigest=r48Data.finalIdentity.sourceDigest, expectedRows=600);
folder = fullfile(project, "results", "full_spectrum", ...
    "round50_pfa_range_conditioning_diagnostics600_v1");
checkpointFolder = fullfile(folder, "checkpoints");
results = cell(height(design), 1);
environment = struct();
if isfolder(folder)
    if options.Resume && isfolder(checkpointFolder)
        [results, environment] = loadLatestCheckpoint( ...
            checkpointFolder, identity, design);
    elseif ~options.Resume
        error("r50:OutputExists", "The immutable R50 output exists.");
    else
        error("r50:MissingCheckpoint", ...
            "A nonempty R50 folder exists without checkpoints.");
    end
else
    mkdir(folder);
end
if ~isfolder(checkpointFolder)
    mkdir(checkpointFolder);
end
writetable(design, fullfile(folder, "design.csv"));
writetable(source, fullfile(folder, "source_manifest.csv"));
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    indices = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(indices, :);
    batchSaved = r48Data.results(indices);
    batch = cell(numel(indices), 1);
    trialProtocol = protocol;
    parfor localIndex = 1:numel(indices)
        batch{localIndex} = r50.diagnosticRow(cfg, scan, ...
            batchDesign(localIndex, :), batchSaved{localIndex}, ...
            indices(localIndex), trialProtocol);
    end
    results(indices) = batch;
    environment = struct(matlabVersion=version, computer=computer, ...
        workers=pool.NumWorkers, poolClass=class(pool), ...
        batchSize=options.BatchSize, ...
        timestamp=string(datetime("now", "TimeZone", "Asia/Shanghai")));
    saveVersionedCheckpoint(checkpointFolder, identity, design, ...
        results, environment);
    fprintf("R50 diagnostics: %d/%d rows complete\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end
if r32.sourceDigest(r50.manifest(project)) ~= sourceDigest
    error("r50:SourceDrift", "Executable source changed during R50.");
end
failureMask = cellfun(@(item) isempty(item) || ~item.success, results);
failures = failureTable(design, results, failureMask);
writetable(failures, fullfile(folder, "failures.csv"));
if any(failureMask)
    error("r50:DiagnosticFailure", "At least one R50 row failed.");
end
summary = r50.summarize(design, results, protocol);
r46Folder = fullfile(project, "results", "full_spectrum", ...
    "round46_pfa_independent_final_v1");
r46Data = load(fullfile(r46Folder, "result.mat"), "summary", "identity");
r46Audit = r50.auditR46(r46Data.summary.perUser, protocol);

writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.oracleBootstrap, ...
    fullfile(folder, "oracle_bootstrap.csv"));
writetable(summary.biasVariance, fullfile(folder, "angle_bias_variance.csv"));
writetable(summary.ridge.distribution, ...
    fullfile(folder, "ridge_distribution.csv"));
writetable(summary.ridge.smoothPrediction, ...
    fullfile(folder, "ridge_prediction.csv"));
writetable(summary.decomposition, ...
    fullfile(folder, "range_mse_decomposition.csv"));
writetable(summary.modeSwitch, fullfile(folder, "mode_switch.csv"));
writetable(summary.gridContinuous, ...
    fullfile(folder, "grid_continuous.csv"));
writetable(summary.diagnostics, fullfile(folder, "diagnostics.csv"));
writetable(r46Audit.paired, fullfile(folder, "r46_paired_audit.csv"));
writetable(r46Audit.robust, fullfile(folder, "r46_robust_metrics.csv"));
writetable(r46Audit.tail, fullfile(folder, "r46_tail_contribution.csv"));
writetable(r46Audit.topRows, fullfile(folder, "r46_top_rows.csv"));
finalIdentity = struct(version=protocol.version, completedRows=600, ...
    failedRows=0, sourceDigest=sourceDigest, ...
    r48SourceDigest=r48Data.finalIdentity.sourceDigest, ...
    r46ReadOnlyAudit=true, r46UsedForSelection=false, ...
    candidatesImplemented=false, pausedAfterDiagnostics=true, ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "protocol", "finalIdentity", ...
    "design", "results", "summary", "r46Audit", ...
    "source", "environment", "-v7");
output = struct(folder=folder, identity=finalIdentity, ...
    summary=summary, r46Audit=r46Audit);
fprintf("ROUND50_RANGE_CONDITIONING_DIAGNOSTICS_COMPLETE rows=600\n");
disp(summary.oracleBootstrap);
disp(summary.ridge.smoothPrediction);
disp(summary.gridContinuous);
end

function [results, environment] = loadLatestCheckpoint( ...
    checkpointFolder, identity, design)
listing = dir(fullfile(checkpointFolder, "checkpoint_rows_*.mat"));
if isempty(listing)
    error("r50:MissingResumeCheckpoint", ...
        "No complete versioned R50 checkpoint is available.");
end
[~, order] = sort(string({listing.name}), "descend");
for index = order
    file = string(fullfile(listing(index).folder, listing(index).name));
    try
        [results, environment] = r41.loadCheckpoint(file, identity, design);
        return;
    catch
    end
end
error("r50:NoValidResumeCheckpoint", ...
    "Every R50 checkpoint is invalid or stale.");
end

function saveVersionedCheckpoint(folder, identity, design, results, environment)
completed = nnz(~cellfun(@isempty, results));
file = fullfile(folder, sprintf("checkpoint_rows_%06d.mat", completed));
if isfile(file)
    error("r50:CheckpointAlreadyExists", ...
        "A versioned R50 checkpoint cannot be overwritten.");
end
temporary = fullfile(folder, sprintf( ...
    ".checkpoint_rows_%06d_%s.tmp.mat", completed, ...
    char(java.util.UUID.randomUUID)));
cleanup = onCleanup(@() deleteTemporary(temporary));
save(temporary, "identity", "design", "results", "environment", "-v7");
movefile(temporary, file);
clear cleanup
end

function deleteTemporary(file)
if isfile(file)
    delete(file);
end
end

function failures = failureTable(design, results, failed)
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
