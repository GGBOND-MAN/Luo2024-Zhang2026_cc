function run_round35_schemeA_development(options)
%RUN_ROUND35_SCHEMEA_DEVELOPMENT Run only Scheme A on the old 60 users.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
addpath(fullfile(project, "+r35", "common"));
addpath(fullfile(project, "+r35", "schemeA"));
commonProtocol = r35CommonProtocol();
commonIdentity = r35AssertCommonProtocol( ...
    jad.defaultConfig(), commonProtocol);
schemeProtocol = r35SchemeAConfig();
if schemeProtocol.commonVersion ~= commonProtocol.version
    error("r35:SchemeACommonProtocolMismatch", ...
        "Scheme A is not bound to the active common protocol.");
end

raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
design = raw.pilot.design;
validateDesign(design, schemeProtocol);
cfg = raw.pilot.expected.cfg;
r35AssertCommonProtocol(cfg, commonProtocol);
scan = fsjad.prepareScan(cfg);
source = schemeManifest(project);
sourceDigest = r32.sourceDigest(source);
estimationSource = estimationManifest(project);
estimationSourceDigest = r32.sourceDigest(estimationSource);
identity = struct( ...
    version="R35-schemeA-existing-60-development-v1", ...
    dataRole="existing-60-user-development-only", ...
    commonProtocol=commonProtocol, schemeProtocol=schemeProtocol, ...
    frozenR34SourceDigest=commonIdentity.frozenSourceDigest, ...
    pilotHash=raw.pilotHash, ...
    estimationSourceDigest=estimationSourceDigest, ...
    reportingSourceDigest=sourceDigest, ...
    calibrationUsersExecuted=0, finalTrialsExecuted=0, ...
    schemesExecuted="A-only");

folder = fullfile(project, "results", "full_spectrum", ...
    "round35_schemeA_continuous_angle_v1");
if ~isfolder(folder)
    mkdir(folder);
end
checkpointFile = fullfile(folder, "checkpoint.mat");
results = cell(height(design), 1);
environment = struct();
if isfile(checkpointFile)
    saved = load(checkpointFile, ...
        "identity", "design", "results", "environment");
    completeLegacy = all(~cellfun(@isempty, saved.results));
    compatible = isequaln(saved.design, design) ...
        && (currentCheckpointCompatible(saved.identity, identity) ...
        || (completeLegacy ...
        && legacyCheckpointCompatible(saved.identity, identity)));
    if ~compatible
        error("r35:StaleSchemeACheckpoint", ...
            "The Scheme A checkpoint has a different frozen identity.");
    end
    results = saved.results;
    environment = saved.environment;
    if ~isfield(saved.identity, "estimationSourceDigest")
        identity.legacyCheckpointSchemeSourceDigest = ...
            saved.identity.schemeSourceDigest;
        identity.summaryOnlyMigration = true;
    end
end

pending = find(cellfun(@isempty, results));
pool = [];
if ~isempty(pending)
    pool = preparePool(options.PoolType, options.NumWorkers);
    for first = 1:options.BatchSize:numel(pending)
        taskRows = pending(first:min( ...
            first+options.BatchSize-1, numel(pending)));
        batchDesign = design(taskRows, :);
        batch = cell(numel(taskRows), 1);
        parfor index = 1:numel(taskRows)
            batch{index} = r35SchemeATrial( ...
                cfg, scan, batchDesign(index, :), taskRows(index), ...
                r34.config(), schemeProtocol);
        end
        results(taskRows) = batch;
        environment = environmentRecord(pool, options.BatchSize);
        save(checkpointFile, "identity", "design", "results", ...
            "environment", "-v7.3");
        fprintf("R35 SCHEME A: %d/%d\n", ...
            nnz(~cellfun(@isempty, results)), height(design));
    end
end

failed = failureTable(design, results);
writetable(failed, fullfile(folder, "failures.csv"));
if ~isempty(pool)
    environment = environmentRecord(pool, options.BatchSize);
    delete(pool);
end
if height(failed) > 0
    save(fullfile(folder, "result.mat"), "identity", "design", ...
        "results", "failed", "environment", "source", "-v7.3");
    error("r35:SchemeADevelopmentFailure", ...
        "Scheme A retained at least one failed development row.");
end

summary = r35SummarizeSchemeA(design, results, commonProtocol);
writetable(summary.perUser, fullfile(folder, "per_user_outputs.csv"));
writetable(summary.summary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, ...
    fullfile(folder, "paired_comparisons.csv"));
writetable(summary.refinement, ...
    fullfile(folder, "refinement_diagnostics.csv"));
writetable(summary.gate, fullfile(folder, "engineering_gate.csv"));
writetable(source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "result.mat"), "identity", "design", ...
    "results", "summary", "environment", "source", "-v7.3");
fprintf("ROUND35_SCHEME_A_DEVELOPMENT_COMPLETE users=%d gate=%d " + ...
    "calibration=0 final=0\n", height(design), summary.gatePassed);
end

function validateDesign(design, protocol)
counts = groupcounts(design, "snrDb");
pass = height(design) == protocol.developmentUserCount ...
    && isequal(sort(counts.snrDb).', sort(protocol.snrDb)) ...
    && all(counts.GroupCount == protocol.developmentUserCount ...
    /numel(protocol.snrDb)) && numel(unique(design.seed)) == height(design);
if ~pass
    error("r35:DevelopmentDesignMismatch", ...
        "Scheme A requires the frozen 60-user, three-SNR design.");
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

function environment = environmentRecord(pool, batchSize)
environment = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    timestamp=string(datetime("now")));
end

function failures = failureTable(design, results)
failed = cellfun(@(item) ~item.success, results);
failures = design(failed, ["seed", "trialIndex", "snrDb"]);
if any(failed)
    failures.errorIdentifier = string(cellfun( ...
        @(item) item.errorIdentifier, results(failed), ...
        UniformOutput=false));
    failures.errorMessage = string(cellfun( ...
        @(item) item.errorMessage, results(failed), ...
        UniformOutput=false));
end
end

function source = schemeManifest(project)
listing = [dir(fullfile(project, "+r35", "common", "*.m")); ...
    dir(fullfile(project, "+r35", "schemeA", "*.m")); ...
    dir(fullfile(project, "experiments", ...
    "run_round35_schemeA_development.m")); ...
    dir(fullfile(project, "tests", "round35*Test.m"))];
paths = strings(numel(listing), 1);
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    paths(index) = replace(extractAfter(file, strlength(project)+1), ...
        string(filesep), "/");
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end

function source = estimationManifest(project)
listing = [dir(fullfile(project, "+r35", "common", "*.m")); ...
    dir(fullfile(project, "+r35", "schemeA", "r35SchemeAConfig.m")); ...
    dir(fullfile(project, "+r35", "schemeA", ...
    "r35BracketedMusicRefinement.m")); ...
    dir(fullfile(project, "+r35", "schemeA", "r35SchemeATrial.m"))];
paths = strings(numel(listing), 1);
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    paths(index) = replace(extractAfter(file, strlength(project)+1), ...
        string(filesep), "/");
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end

function pass = currentCheckpointCompatible(saved, current)
pass = isfield(saved, "estimationSourceDigest") ...
    && saved.version == current.version ...
    && saved.frozenR34SourceDigest == current.frozenR34SourceDigest ...
    && saved.pilotHash == current.pilotHash ...
    && saved.estimationSourceDigest == current.estimationSourceDigest ...
    && isequaln(saved.commonProtocol, current.commonProtocol) ...
    && isequaln(saved.schemeProtocol, current.schemeProtocol);
end

function pass = legacyCheckpointCompatible(saved, current)
pass = isfield(saved, "schemeSourceDigest") ...
    && saved.version == current.version ...
    && saved.frozenR34SourceDigest == current.frozenR34SourceDigest ...
    && saved.pilotHash == current.pilotHash ...
    && saved.calibrationUsersExecuted == 0 ...
    && saved.finalTrialsExecuted == 0 ...
    && saved.schemesExecuted == "A-only" ...
    && isequaln(saved.commonProtocol, current.commonProtocol) ...
    && isequaln(saved.schemeProtocol, current.schemeProtocol);
end
