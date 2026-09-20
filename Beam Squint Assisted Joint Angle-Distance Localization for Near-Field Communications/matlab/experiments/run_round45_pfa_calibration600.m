function output = run_round45_pfa_calibration600(options)
%RUN_ROUND45_PFA_CALIBRATION600 Execute the frozen R45 calibration.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = true
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r45.config();
design = r45.design(protocol);
if height(design) ~= protocol.design.expectedRows
    error("r45:FrozenDesignSize", ...
        "The R45 design does not contain the frozen 600 rows.");
end

source = r45.manifest(project);
sourceDigest = r32.sourceDigest(source);
checkpointIdentity = struct( ...
    version="R45-PFA-calibration-checkpoint-v1", ...
    protocolHash=r41.structHash(protocol), ...
    designHash=r32.designHash(design), ...
    sourceDigest=sourceDigest, expectedRows=height(design));
folder = fullfile(project, "results", "full_spectrum", ...
    "round45_pfa_calibration600_v1");
checkpoint = fullfile(folder, "checkpoint.mat");
results = cell(height(design), 1);
environment = struct();

if isfolder(folder)
    if options.Resume && isfile(checkpoint)
        [results, environment] = r41.loadCheckpoint( ...
            checkpoint, checkpointIdentity, design);
    elseif ~options.Resume
        error("r45:CalibrationFolderExists", ...
            "R45 output exists. Use Resume=true for the exact checkpoint.");
    elseif numel(dir(folder)) > 2
        error("r45:MissingCheckpoint", ...
            "A nonempty R45 folder exists without a valid checkpoint.");
    end
else
    mkdir(folder);
end

writetable(design, fullfile(folder, "design.csv"));
writetable(source, fullfile(folder, "source_manifest.csv"));
save(fullfile(folder, "protocol.mat"), "protocol", "design", ...
    "source", "checkpointIdentity", "-v7.3");

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
        batch{localIndex} = r45.trial(cfg, scan, ...
            batchDesign(localIndex, :), indices(localIndex), trialProtocol);
    end
    results(indices) = batch;
    environment = environmentRecord(pool, options.BatchSize);
    r41.saveCheckpoint(checkpoint, checkpointIdentity, ...
        design, results, environment);
    fprintf("R45 calibration: %d/%d rows complete\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end

postSource = r45.manifest(project);
if r32.sourceDigest(postSource) ~= sourceDigest
    error("r45:SourceDrift", ...
        "Executable source changed during the R45 calibration.");
end
failureMask = cellfun(@(item) isempty(item) || ~item.success, results);
failures = failureTable(design, results, failureMask);
writetable(failures, fullfile(folder, "failures.csv"));
if any(failureMask)
    save(fullfile(folder, "failed_result.mat"), "protocol", ...
        "checkpointIdentity", "design", "results", "environment", ...
        "failures", "-v7.3");
    error("r45:TrialFailure", ...
        "At least one frozen R45 calibration row failed.");
end

summary = r45.summarize(design, results, protocol);
writePopulation(folder, summary.all600);
writePopulation(folder, summary.holdout540);
writePopulation(folder, summary.diagnostic60);
writetable(summary.perUser, fullfile(folder, "per_user.csv"));
writetable(summary.decision, fullfile(folder, "decision.csv"));
identity = struct(version=protocol.version, ...
    evidenceRole=protocol.evidenceRole, protocolHash=checkpointIdentity.protocolHash, ...
    designHash=checkpointIdentity.designHash, sourceDigest=sourceDigest, ...
    completedRows=height(design), failedRows=0, ...
    finalTrialsReadOrExecuted=0, r34FinalRead=false, r41FinalRead=false, ...
    priorDevelopmentResultsRead=false, parameterTuningPerformed=false, ...
    calibrationReady=summary.calibrationReady, ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(fullfile(folder, "result.mat"), "protocol", "identity", ...
    "design", "results", "summary", "source", "environment", "-v7.3");
output = struct(folder=folder, identity=identity, summary=summary);
fprintf("ROUND45_PFA_CALIBRATION_COMPLETE rows=%d pass=%d final=0\n", ...
    height(design), summary.calibrationReady);
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

function output = environmentRecord(pool, batchSize)
output = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    timestamp=string(datetime("now", "TimeZone", "Asia/Shanghai")), ...
    serverThroughputIsAlgorithmRuntimeEvidence=false);
end

function failures = failureTable(design, results, failed)
failures = design(failed, :);
failures.errorIdentifier = strings(nnz(failed), 1);
failures.errorMessage = strings(nnz(failed), 1);
selected = find(failed);
for index = 1:numel(selected)
    item = results{selected(index)};
    if ~isempty(item)
        failures.errorIdentifier(index) = string(item.errorIdentifier);
        failures.errorMessage(index) = string(item.errorMessage);
    else
        failures.errorIdentifier(index) = "r45:MissingResult";
        failures.errorMessage(index) = "The frozen row has no result.";
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
