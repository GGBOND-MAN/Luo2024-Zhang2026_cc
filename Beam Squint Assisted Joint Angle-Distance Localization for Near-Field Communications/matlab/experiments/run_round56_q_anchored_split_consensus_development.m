function output = run_round56_q_anchored_split_consensus_development(options)
%RUN_ROUND56_Q_ANCHORED_SPLIT_CONSENSUS_DEVELOPMENT Execute frozen R56.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Resume (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r56.config();
frozenR53Source = r53.manifest(project);
frozenR53Digest = r32.sourceDigest(frozenR53Source);
frozenPfaSource = r45.manifest(project);
frozenPfaDigest = r32.sourceDigest(frozenPfaSource);
if frozenR53Digest ~= protocol.freeze.expectedR53Digest
    error("r56:FrozenR53DigestMismatch", ...
        "The frozen R53 implementation does not match its accepted digest.");
end
if frozenPfaDigest ~= protocol.freeze.expectedPfaDigest
    error("r56:FrozenPfaDigestMismatch", ...
        "The frozen P_FA implementation does not match its accepted digest.");
end

design = r56.design(protocol);
source = r56.manifest(project);
sourceDigest = r32.sourceDigest(source);
designHash = r32.designHash(design);
folder = fullfile(project, "results", "full_spectrum", ...
    "round56_q_anchored_split_consensus_development_v1");
resultFile = fullfile(folder, "result.mat");
if isfile(resultFile)
    error("r56:OutputExists", "The immutable R56 result already exists.");
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
runTimer = tic;
for first = 1:protocol.execution.batchSize:numel(pending)
    rows = pending(first:min(first+protocol.execution.batchSize-1, ...
        numel(pending)));
    batchDesign = design(rows, :);
    batch = cell(numel(rows), 1);
    parfor localIndex = 1:numel(rows)
        batch{localIndex} = r56.trial(cfg, scan, ...
            batchDesign(localIndex, :), rows(localIndex), protocol);
    end
    results(rows) = batch;
    saveCheckpoint(checkpoint, identity, results);
    fprintf("R56 development: %d/%d rows complete\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end
wallSeconds = toc(runTimer);

failures = failureTable(design, results);
writetable(failures, fullfile(folder, "failures.csv"));
if ~isempty(failures)
    error("r56:TrialFailure", "At least one R56 development row failed.");
end
if r32.sourceDigest(r56.manifest(project)) ~= sourceDigest
    error("r56:SourceDrift", "Executable source changed during R56.");
end
if r32.sourceDigest(r53.manifest(project)) ~= frozenR53Digest
    error("r56:FrozenR53Drift", "Frozen R53 changed during R56.");
end
if r32.sourceDigest(r45.manifest(project)) ~= frozenPfaDigest
    error("r56:FrozenPfaDrift", "Frozen P_FA changed during R56.");
end

summary = r56.summarize(design, results, protocol);
runtime = table(height(design), pool.NumWorkers, wallSeconds, ...
    wallSeconds/height(design), mean(summary.perUser.backendSeconds), ...
    'VariableNames', {'rows', 'workers', 'wallSeconds', ...
    'wallSecondsPerRow', 'meanCompleteBackendSeconds'});
writetable(summary.perUser, fullfile(folder, "per_row.csv"));
writetable(summary.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, fullfile(folder, "performance_tables.csv"));
writetable(summary.bootstrap, fullfile(folder, "bootstrap.csv"));
writetable(summary.mechanism, fullfile(folder, "mechanism.csv"));
writetable(summary.mechanismBySnr, ...
    fullfile(folder, "mechanism_by_snr.csv"));
writetable(summary.gate, fullfile(folder, "gate.csv"));
writetable(runtime, fullfile(folder, "runtime.csv"));

finalIdentity = struct(version=protocol.version, completedRows=height(design), ...
    failedRows=0, sourceDigest=sourceDigest, ...
    frozenR53Digest=frozenR53Digest, frozenPfaDigest=frozenPfaDigest, ...
    designHash=designHash, finalRowsRead=false, ...
    R53R54R55RowsRead=false, parameterTuningPerformed=false, ...
    developmentPass=summary.developmentPass, workers=pool.NumWorkers, ...
    poolClass=class(pool), wallSeconds=wallSeconds, ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
save(resultFile, "protocol", "finalIdentity", "design", "results", ...
    "summary", "runtime", "source", "frozenR53Source", ...
    "frozenPfaSource", "-v7");
output = struct(folder=folder, identity=finalIdentity, ...
    summary=summary, runtime=runtime);
fprintf("ROUND56_PFALFSC_COMPLETE pass=%d rows=%d failures=0\n", ...
    summary.developmentPass, height(design));
disp(summary.gate);
disp(summary.comparisons(summary.comparisons.candidate == "P_FALF_SC", :));
disp(summary.mechanism);
end

function output = loadCheckpoint(file, count, identity, resume)
output = cell(count, 1);
if ~resume || ~isfile(file)
    return;
end
saved = load(file, "identity", "results");
if ~isequal(saved.identity, identity) || numel(saved.results) ~= count
    error("r56:CheckpointIdentityMismatch", ...
        "The R56 checkpoint identity is invalid.");
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
