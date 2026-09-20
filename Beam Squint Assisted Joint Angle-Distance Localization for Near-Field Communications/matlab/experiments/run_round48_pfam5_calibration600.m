function output = run_round48_pfam5_calibration600(options)
%RUN_ROUND48_PFAM5_CALIBRATION600 Execute the frozen R48 calibration.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = true
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r48.config();
design = r48.design(protocol);
source = r48.manifest(project);
sourceDigest = r32.sourceDigest(source);
identity = struct(version="R48-PFAM5-calibration-checkpoint-v1", ...
    protocolHash=r41.structHash(protocol), ...
    designHash=r32.designHash(design), sourceDigest=sourceDigest, ...
    expectedRows=height(design));
folder = fullfile(project, "results", "full_spectrum", ...
    "round48_pfam5_calibration600_v1");
checkpointFolder = fullfile(folder, "checkpoints");
results = cell(height(design), 1);
environment = struct();
if isfolder(folder)
    if options.Resume && isfolder(checkpointFolder)
        [results, environment] = loadLatestCheckpoint( ...
            checkpointFolder, identity, design);
    elseif ~options.Resume
        error("r48:CalibrationFolderExists", ...
            "R48 output exists. Resume the exact checkpoint.");
    elseif numel(dir(folder)) > 2
        error("r48:MissingCheckpoint", ...
            "A nonempty R48 folder exists without a valid checkpoint.");
    end
else
    mkdir(folder);
end
if ~isfolder(checkpointFolder)
    mkdir(checkpointFolder);
end
writetable(design, fullfile(folder, "design.csv"));
writetable(source, fullfile(folder, "source_manifest.csv"));
save(fullfile(folder, "protocol.mat"), "protocol", "design", ...
    "source", "identity", "-v7.3");

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    indices = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(indices, :);
    batch = cell(numel(indices), 1);
    trialProtocol = protocol;
    parfor localIndex = 1:numel(indices)
        batch{localIndex} = r48.trial(cfg, scan, ...
            batchDesign(localIndex, :), indices(localIndex), trialProtocol);
    end
    results(indices) = batch;
    environment = struct(matlabVersion=version, computer=computer, ...
        workers=pool.NumWorkers, poolClass=class(pool), ...
        batchSize=options.BatchSize, ...
        timestamp=string(datetime("now", "TimeZone", "Asia/Shanghai")), ...
        serverThroughputIsAlgorithmRuntimeEvidence=false);
    saveVersionedCheckpoint(checkpointFolder, identity, design, ...
        results, environment);
    fprintf("R48 calibration: %d/%d rows complete\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end

function [results, environment] = loadLatestCheckpoint( ...
    checkpointFolder, identity, design)
listing = dir(fullfile(checkpointFolder, "checkpoint_rows_*.mat"));
if isempty(listing)
    error("r48:MissingResumeCheckpoint", ...
        "No complete versioned R48 checkpoint is available.");
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
error("r48:NoValidResumeCheckpoint", ...
    "Every versioned R48 checkpoint is invalid or stale.");
end

function saveVersionedCheckpoint(folder, identity, design, results, environment)
completed = nnz(~cellfun(@isempty, results));
name = sprintf("checkpoint_rows_%06d.mat", completed);
file = fullfile(folder, name);
if isfile(file)
    error("r48:CheckpointAlreadyExists", ...
        "A versioned checkpoint cannot be overwritten.");
end
temporary = fullfile(folder, sprintf( ...
    ".checkpoint_rows_%06d_%s.tmp.mat", completed, char(java.util.UUID.randomUUID)));
cleanup = onCleanup(@() deleteTemporary(temporary));
save(temporary, "identity", "design", "results", "environment", "-v7.3");
movefile(temporary, file);
clear cleanup
end

function deleteTemporary(file)
if isfile(file)
    delete(file);
end
end
if r32.sourceDigest(r48.manifest(project)) ~= sourceDigest
    error("r48:SourceDrift", ...
        "Executable source changed during R48 calibration.");
end
failed = cellfun(@(item) isempty(item) || ~item.success, results);
failures = failureTable(design, results, failed);
writetable(failures, fullfile(folder, "failures.csv"));
if any(failed)
    error("r48:TrialFailure", "At least one R48 row failed.");
end
summary = r48.summarize(design, results, protocol);
writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.decision, fullfile(folder, "decision.csv"));
writePopulation(folder, summary.all600);
writePopulation(folder, summary.holdout540);
writePopulation(folder, summary.diagnostic60);
finalIdentity = struct(version=protocol.version, ...
    evidenceRole=protocol.evidenceRole, completedRows=600, failedRows=0, ...
    sourceDigest=sourceDigest, finalTrialsReadOrExecuted=0, ...
    r34FinalRead=false, r41FinalRead=false, r46FinalRead=false, ...
    parameterTuningPerformed=false, ...
    calibrationReady=summary.calibrationReady, ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "protocol", "finalIdentity", ...
    "design", "results", "summary", "source", "environment", "-v7.3");
output = struct(folder=folder, identity=finalIdentity, summary=summary);
fprintf("ROUND48_PFAM5_CALIBRATION_COMPLETE rows=600 pass=%d final=0\n", ...
    summary.calibrationReady);
disp(summary.decision);
disp(summary.all600.gate);
disp(summary.all600.bootstrap.summary);
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

function failures = failureTable(design, results, failed)
failures = design(failed, :);
failures.errorIdentifier = strings(nnz(failed), 1);
failures.errorMessage = strings(nnz(failed), 1);
selected = find(failed);
for index = 1:numel(selected)
    item = results{selected(index)};
    if isempty(item)
        failures.errorIdentifier(index) = "r48:MissingResult";
        failures.errorMessage(index) = "The frozen row has no result.";
    else
        failures.errorIdentifier(index) = string(item.errorIdentifier);
        failures.errorMessage(index) = string(item.errorMessage);
    end
end
end

function writePopulation(folder, population)
prefix = population.population+"_";
writetable(population.methodSummary, ...
    fullfile(folder, prefix+"method_summary.csv"));
writetable(population.comparisons, ...
    fullfile(folder, prefix+"comparisons.csv"));
writetable(population.gate, ...
    fullfile(folder, prefix+"engineering_gate.csv"));
writetable(population.bootstrap.summary, ...
    fullfile(folder, prefix+"bootstrap.csv"));
writetable(population.diagnostics, ...
    fullfile(folder, prefix+"diagnostics.csv"));
end
