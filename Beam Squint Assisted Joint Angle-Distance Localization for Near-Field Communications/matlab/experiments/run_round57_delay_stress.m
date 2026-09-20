function output = run_round57_delay_stress(options)
%RUN_ROUND57_DELAY_STRESS Timing-jitter sensitivity of P_FACR.
%   MODIFIED DATA PATH. This branch multiplies the observations by
%   exp(-j 2 pi f_m tau) before estimation, so it is not the frozen
%   replayRound27Data path. It writes to its own result directory, is never
%   merged with the primary summary, and cannot change any primary verdict.
%   It requires the development result to exist, so the scope of a claim is
%   only ever measured after the claim itself.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r57.config();
if protocol.stress.entersPrimaryJudgement
    error("r57:StressMustStayIsolated", ...
        "The delay-stress branch must never enter the primary judgement.");
end
developmentFolder = fullfile(project, "results", "full_spectrum", ...
    "round57_coherent_range_development_v1");
if ~isfile(fullfile(developmentFolder, "result.mat"))
    error("r57:DevelopmentRequired", ...
        "Run the R57 development stage before the delay-stress branch.");
end

design = r57.stressDesign(protocol);
source = r57.manifest(project);
sourceDigest = r32.sourceDigest(source);
folder = fullfile(project, "results", "full_spectrum", ...
    "round57_delay_stress_v1");
resultFile = fullfile(folder, "result.mat");
if isfile(resultFile)
    error("r57:OutputExists", "The immutable R57 stress result exists.");
end
if ~isfolder(folder)
    mkdir(folder);
end
writetable(design, fullfile(folder, "design.csv"));
writetable(source, fullfile(folder, "source_hashes.csv"));

identity = struct(version=protocol.version, stage="delay-stress", ...
    dataPath="modified-exp-minus-j-2pi-f-tau", ...
    sourceDigest=sourceDigest, designHash=r32.designHash(design));
checkpoint = fullfile(folder, "checkpoint.mat");
results = loadCheckpoint(checkpoint, height(design), identity, options.Resume);
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
pending = find(cellfun(@isempty, results));
runTimer = tic;
for first = 1:protocol.execution.batchSize:numel(pending)
    rows = pending(first:min(first+protocol.execution.batchSize-1, ...
        numel(pending)));
    batchDesign = design(rows, :);
    batch = cell(numel(rows), 1);
    parfor localIndex = 1:numel(rows)
        batch{localIndex} = r57.stressTrial(cfg, scan, ...
            batchDesign(localIndex, :), rows(localIndex), protocol);
    end
    results(rows) = batch;
    saveCheckpoint(checkpoint, identity, results);
    fprintf("R57 delay stress: %d/%d rows complete\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end
wallSeconds = toc(runTimer);

failures = failureTable(design, results);
writetable(failures, fullfile(folder, "failures.csv"));
if ~isempty(failures)
    error("r57:StressTrialFailure", "At least one stress row failed.");
end
if r32.sourceDigest(r57.manifest(project)) ~= sourceDigest
    error("r57:SourceDrift", "Executable source changed during the stress run.");
end

summary = r57.stressSummarize(design, results, protocol);
runtime = table(height(design), pool.NumWorkers, wallSeconds, ...
    wallSeconds/height(design), mean(summary.perUser.backendSeconds), ...
    'VariableNames', {'rows', 'workers', 'wallSeconds', ...
    'wallSecondsPerRow', 'meanBackendSeconds'});
writetable(summary.perUser, fullfile(folder, "per_row.csv"));
writetable(summary.curves, fullfile(folder, "stress_curves.csv"));
writetable(summary.invariance, fullfile(folder, "invariance_check.csv"));
writetable(runtime, fullfile(folder, "runtime.csv"));
save(resultFile, "protocol", "identity", "design", "results", ...
    "summary", "runtime", "source", "-v7");
output = struct(folder=folder, identity=identity, ...
    summary=summary, runtime=runtime);
fprintf("ROUND57_DELAY_STRESS_COMPLETE rows=%d failures=0 invariance=%d\n", ...
    height(design), all(summary.invariance.pass));
for mode = protocol.stress.modes
    fprintf("\n--- mode %s ---\n", mode);
    disp(summary.curves(summary.curves.mode == mode, :));
end
end

function output = loadCheckpoint(file, count, identity, resume)
output = cell(count, 1);
if ~resume || ~isfile(file)
    return;
end
saved = load(file, "identity", "results");
if ~isequal(saved.identity, identity) || numel(saved.results) ~= count
    error("r57:CheckpointIdentityMismatch", ...
        "The R57 stress checkpoint identity is invalid.");
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
