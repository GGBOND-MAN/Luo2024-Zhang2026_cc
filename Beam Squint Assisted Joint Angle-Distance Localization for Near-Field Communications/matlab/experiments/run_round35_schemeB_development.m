function run_round35_schemeB_development(options)
%RUN_ROUND35_SCHEMEB_DEVELOPMENT Run only Scheme B on 60 old users.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
addpath(fullfile(project, "+r35", "common"));
addpath(fullfile(project, "+r35", "schemeB"));
commonProtocol = r35CommonProtocol();
commonIdentity = r35AssertCommonProtocol( ...
    jad.defaultConfig(), commonProtocol);
schemeProtocol = r35SchemeBConfig();
if schemeProtocol.commonVersion ~= commonProtocol.version
    error("r35:SchemeBCommonProtocolMismatch", ...
        "Scheme B is not bound to the active common protocol.");
end

raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
design = raw.pilot.design;
validateDesign(design, schemeProtocol);
cfg = raw.pilot.expected.cfg;
r35AssertCommonProtocol(cfg, commonProtocol);
scan = fsjad.prepareScan(cfg);
[schemeAReadOnly, schemeAHash] = loadSchemeAReadOnly(project, schemeProtocol);

source = schemeBManifest(project);
reportingSourceDigest = r32.sourceDigest(source);
primarySource = primaryManifest(project);
primarySourceDigest = r32.sourceDigest(primarySource);
identity = struct( ...
    version="R35-schemeB-existing-60-development-v1", ...
    dataRole="existing-60-user-development-only", ...
    commonProtocol=commonProtocol, schemeProtocol=schemeProtocol, ...
    frozenR34SourceDigest=commonIdentity.frozenSourceDigest, ...
    pilotHash=raw.pilotHash, schemeAReadOnlyHash=schemeAHash, ...
    primarySourceDigest=primarySourceDigest, ...
    reportingSourceDigest=reportingSourceDigest, ...
    calibrationUsersExecuted=0, finalTrialsExecuted=0, ...
    schemesExecuted="B-only", schemeAEstimatorExecuted=false, ...
    schemeDExecuted=false);

folder = fullfile(project, "results", "full_spectrum", ...
    "round35_schemeB_spectral_angle_v1");
if ~isfolder(folder)
    mkdir(folder);
end
checkpointFile = fullfile(folder, "checkpoint.mat");
results = cell(height(design), 1);
environment = struct();
if isfile(checkpointFile)
    saved = load(checkpointFile, ...
        "identity", "design", "results", "environment");
    if ~checkpointCompatible(saved.identity, identity) ...
            || ~isequaln(saved.design, design)
        error("r35:StaleSchemeBCheckpoint", ...
            "The Scheme B checkpoint has a different frozen identity.");
    end
    results = saved.results;
    environment = saved.environment;
end

pool = [];
pending = find(cellfun(@isempty, results));
if ~isempty(pending)
    pool = preparePool(options.PoolType, options.NumWorkers);
    for first = 1:options.BatchSize:numel(pending)
        taskRows = pending(first:min( ...
            first+options.BatchSize-1, numel(pending)));
        batchDesign = design(taskRows, :);
        batch = cell(numel(taskRows), 1);
        parfor index = 1:numel(taskRows)
            batch{index} = r35SchemeBPrimaryTrial( ...
                cfg, scan, batchDesign(index, :), taskRows(index), ...
                r34.config(), schemeProtocol);
        end
        results(taskRows) = batch;
        environment = environmentRecord(pool, options.BatchSize);
        save(checkpointFile, "identity", "design", "results", ...
            "environment", "-v7.3");
        fprintf("R35 SCHEME B PRIMARY: %d/%d\n", ...
            nnz(~cellfun(@isempty, results)), height(design));
    end
end

failures = failureTable(design, results);
writetable(failures, fullfile(folder, "failures.csv"));
if height(failures) > 0
    closePool(pool);
    save(fullfile(folder, "result.mat"), "identity", "design", ...
        "results", "failures", "environment", "source", "-v7.3");
    error("r35:SchemeBDevelopmentFailure", ...
        "Scheme B retained at least one failed primary row.");
end

summary = r35SummarizeSchemeB( ...
    design, results, schemeAReadOnly, commonProtocol);
writePrimaryTables(folder, summary);

rangeRefreshExecuted = false;
refreshResults = cell(0, 1);
refreshSummary = struct();
if summary.primaryAngleGatePassed
    rangeRefreshExecuted = true;
    [refreshResults, pool, environment] = runRangeRefresh( ...
        folder, identity, design, results, cfg, scan, pool, ...
        options, environment);
    refreshSummary = r35SummarizeSchemeBRefresh( ...
        design, results, refreshResults, commonProtocol);
    writetable(refreshSummary.perUser, ...
        fullfile(folder, "range_refresh_per_user.csv"));
    writetable(refreshSummary.summary, ...
        fullfile(folder, "range_refresh_summary.csv"));
    writetable(refreshSummary.gate, ...
        fullfile(folder, "range_refresh_gate.csv"));
end
closePool(pool);

figureManifest = r35BuildSchemeBFigures(summary, folder);
writetable(source, fullfile(folder, "source_hashes.csv"));
finalGatePassed = summary.overallPrimaryGatePassed ...
    && rangeRefreshExecuted && refreshSummary.gatePassed;
if ~summary.primaryAngleGatePassed
    finalGatePassed = false;
end
identity.rangeRefreshExecuted = rangeRefreshExecuted;
identity.finalGatePassed = finalGatePassed;
save(fullfile(folder, "result.mat"), "identity", "design", ...
    "results", "summary", "refreshResults", "refreshSummary", ...
    "failures", "environment", "source", "figureManifest", "-v7.3");
fprintf("ROUND35_SCHEME_B_DEVELOPMENT_COMPLETE users=%d angleGate=%d " + ...
    "rangeRefresh=%d finalGate=%d calibration=0 final=0\n", ...
    height(design), summary.primaryAngleGatePassed, ...
    rangeRefreshExecuted, finalGatePassed);
end

function [schemeA, hash] = loadSchemeAReadOnly(project, protocol)
relative = fullfile("results", "full_spectrum", ...
    "round35_schemeA_continuous_angle_v1", "per_user_outputs.csv");
file = fullfile(project, relative);
if ~isfile(file)
    error("r35:SchemeAReadOnlyFileMissing", ...
        "The frozen Scheme A diagnostic CSV is required.");
end
manifest = fsjad.sourceHashManifest(project, ...
    replace(relative, string(filesep), "/"));
hash = manifest.sha256(1);
if hash ~= protocol.aComparisonSha256
    error("r35:SchemeAReadOnlyFileDrift", ...
        "The frozen Scheme A diagnostic CSV has changed.");
end
schemeA = readtable(file, TextType="string");
end

function validateDesign(design, protocol)
counts = groupcounts(design, "snrDb");
pass = height(design) == protocol.developmentUserCount ...
    && isequal(sort(counts.snrDb).', sort(protocol.snrDb)) ...
    && all(counts.GroupCount == protocol.developmentUserCount ...
    /numel(protocol.snrDb)) && numel(unique(design.seed)) == height(design);
if ~pass
    error("r35:SchemeBDevelopmentDesignMismatch", ...
        "Scheme B requires the frozen 60-user, three-SNR design.");
end
end

function writePrimaryTables(folder, summary)
writetable(summary.perUser, fullfile(folder, "per_user_outputs.csv"));
writetable(summary.summary, fullfile(folder, "method_summary.csv"));
writetable(summary.comparisons, ...
    fullfile(folder, "paired_comparisons.csv"));
writetable(summary.refinement, ...
    fullfile(folder, "refinement_diagnostics.csv"));
writetable(summary.schemeAComparison, ...
    fullfile(folder, "schemeA_readonly_comparison.csv"));
writetable(summary.gate, fullfile(folder, "engineering_gate.csv"));
end

function [refresh, pool, environment] = runRangeRefresh( ...
    folder, identity, design, primary, cfg, scan, pool, options, environment)
checkpoint = fullfile(folder, "range_refresh_checkpoint.mat");
refresh = cell(height(design), 1);
if isfile(checkpoint)
    saved = load(checkpoint, "identity", "design", "refresh");
    if ~checkpointCompatible(saved.identity, identity) ...
            || ~isequaln(saved.design, design)
        error("r35:StaleSchemeBRangeRefreshCheckpoint", ...
            "The range-refresh checkpoint has a different identity.");
    end
    refresh = saved.refresh;
end
pending = find(cellfun(@isempty, refresh));
if ~isempty(pending) && isempty(pool)
    pool = preparePool(options.PoolType, options.NumWorkers);
end
for first = 1:options.BatchSize:numel(pending)
    taskRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batch = cell(numel(taskRows), 1);
    batchDesign = design(taskRows, :);
    batchPrimary = primary(taskRows);
    parfor index = 1:numel(taskRows)
        batch{index} = r35SchemeBRangeRefreshTrial( ...
            cfg, scan, batchDesign(index, :), ...
            batchPrimary{index}, r34.config());
    end
    refresh(taskRows) = batch;
    environment = environmentRecord(pool, options.BatchSize);
    save(checkpoint, "identity", "design", "refresh", ...
        "environment", "-v7.3");
    fprintf("R35 SCHEME B RANGE REFRESH: %d/%d\n", ...
        nnz(~cellfun(@isempty, refresh)), height(design));
end
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

function closePool(pool)
if ~isempty(pool)
    delete(pool);
end
end

function environment = environmentRecord(pool, batchSize)
environment = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    timestamp=string(datetime("now")));
end

function pass = checkpointCompatible(saved, current)
pass = saved.version == current.version ...
    && saved.frozenR34SourceDigest == current.frozenR34SourceDigest ...
    && saved.pilotHash == current.pilotHash ...
    && saved.schemeAReadOnlyHash == current.schemeAReadOnlyHash ...
    && saved.primarySourceDigest == current.primarySourceDigest ...
    && isequaln(saved.commonProtocol, current.commonProtocol) ...
    && isequaln(saved.schemeProtocol, current.schemeProtocol);
end

function source = primaryManifest(project)
listing = [dir(fullfile(project, "+r35", "common", "*.m")); ...
    dir(fullfile(project, "+r35", "schemeB", "r35SchemeBConfig.m")); ...
    dir(fullfile(project, "+r35", "schemeB", ...
    "r35BracketedSpectralRefinement.m")); ...
    dir(fullfile(project, "+r35", "schemeB", ...
    "r35SchemeBPrimaryTrial.m"))];
source = sourceFromListing(project, listing);
end

function source = schemeBManifest(project)
listing = [dir(fullfile(project, "+r35", "common", "*.m")); ...
    dir(fullfile(project, "+r35", "schemeB", "*.m")); ...
    dir(fullfile(project, "experiments", ...
    "run_round35_schemeB_development.m")); ...
    dir(fullfile(project, "tests", "round35*Test.m"))];
source = sourceFromListing(project, listing);
end

function source = sourceFromListing(project, listing)
paths = strings(numel(listing), 1);
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    paths(index) = replace(extractAfter(file, strlength(project)+1), ...
        string(filesep), "/");
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end
