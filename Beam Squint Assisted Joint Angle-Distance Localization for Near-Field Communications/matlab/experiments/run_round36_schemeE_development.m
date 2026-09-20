function run_round36_schemeE_development(options)
%RUN_ROUND36_SCHEMEE_DEVELOPMENT Run isolated Scheme E on 60 old users.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
addpath(fullfile(project, "+r36", "common"));
addpath(fullfile(project, "+r36", "schemeE"));
commonProtocol = r36CommonProtocol();
commonIdentity = r36AssertCommonProtocol( ...
    jad.defaultConfig(), commonProtocol);
schemeProtocol = r36SchemeEConfig();
if schemeProtocol.commonVersion ~= commonProtocol.version
    error("r36:SchemeECommonProtocolMismatch", ...
        "Scheme E is not bound to the active R36 protocol.");
end

raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
design = raw.pilot.design;
validateDesign(design, schemeProtocol);
cfg = raw.pilot.expected.cfg;
r36AssertCommonProtocol(cfg, commonProtocol);
scan = fsjad.prepareScan(cfg);
r35ReadOnlySource = r35ReadOnlyManifest(project);
r35ReadOnlyDigest = r32.sourceDigest(r35ReadOnlySource);
algorithmSource = algorithmManifest(project);
algorithmSourceDigest = r32.sourceDigest(algorithmSource);
source = schemeEManifest(project);
reportingSourceDigest = r32.sourceDigest(source);
identity = struct(version="R36-schemeE-existing-60-development-v1", ...
    date="2026-09-12", dataRole=commonProtocol.evidenceRole, ...
    studyLabel=commonProtocol.studyLabel, commonProtocol=commonProtocol, ...
    schemeProtocol=schemeProtocol, ...
    frozenR34SourceDigest=commonIdentity.sourceDigest, ...
    r35ReadOnlyDigest=r35ReadOnlyDigest, pilotHash=raw.pilotHash, ...
    algorithmSourceDigest=algorithmSourceDigest, ...
    reportingSourceDigest=reportingSourceDigest, ...
    calibrationUsersExecuted=0, finalTrialsExecuted=0, ...
    newUsersGenerated=0, schemesExecuted="E-only", ...
    r35SchemeExecutions=0, r34FinalReadOrExecuted=false);

folder = fullfile(project, "results", "full_spectrum", ...
    "round36_schemeE_range_orthogonal_v1");
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
        error("r36:StaleSchemeECheckpoint", ...
            "The Scheme E checkpoint has a different frozen identity.");
    end
    results = saved.results;
    environment = saved.environment;
end

pool = [];
pending = find(cellfun(@isempty, results));
if ~isempty(pending)
    pool = preparePool(options.PoolType, options.NumWorkers);
    for first = 1:options.BatchSize:numel(pending)
        taskRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
        batchDesign = design(taskRows, :);
        batch = cell(numel(taskRows), 1);
        parfor index = 1:numel(taskRows)
            batch{index} = r36SchemeETrial( ...
                cfg, scan, batchDesign(index, :), taskRows(index), ...
                r34.config(), r36SchemeEConfig());
        end
        results(taskRows) = batch;
        environment = environmentRecord(pool, options.BatchSize);
        save(checkpointFile, "identity", "design", "results", ...
            "environment", "-v7.3");
        fprintf("R36 SCHEME E: %d/%d\n", ...
            nnz(~cellfun(@isempty, results)), height(design));
    end
end
if ~isempty(pool)
    environment = environmentRecord(pool, options.BatchSize);
    delete(pool);
end

failures = failureTable(design, results);
writeLabeledTable(failures, fullfile(folder, "failures.csv"), ...
    commonProtocol.studyLabel);
if height(failures) > 0
    save(fullfile(folder, "result.mat"), "identity", "design", ...
        "results", "failures", "environment", "source", "-v7.3");
    error("r36:SchemeEDevelopmentFailure", ...
        "At least one Scheme E development row failed.");
end
if r32.sourceDigest(r35ReadOnlyManifest(project)) ~= r35ReadOnlyDigest
    error("r36:R35ReadOnlyDriftDuringRun", ...
        "An R35 source changed while the isolated R36 study was running.");
end

summary = r36SummarizeSchemeE(design, results, commonProtocol);
writeSummaryTables(folder, summary, commonProtocol.studyLabel);
writeLabeledTable(source, fullfile(folder, "source_hashes.csv"), ...
    commonProtocol.studyLabel);
writeLabeledTable(r35ReadOnlySource, ...
    fullfile(folder, "r35_readonly_source_hashes.csv"), ...
    commonProtocol.studyLabel);
figureManifest = r36BuildSchemeEFigures(summary, folder);
identity.completedUsers = height(design);
identity.gatePassed = summary.gatePassed;
save(checkpointFile, "identity", "design", "results", ...
    "environment", "-v7.3");
save(fullfile(folder, "result.mat"), "identity", "design", ...
    "results", "summary", "failures", "environment", "source", ...
    "r35ReadOnlySource", "figureManifest", "-v7.3");
fprintf("ROUND36_SCHEME_E_DEVELOPMENT_COMPLETE users=%d gate=%d " + ...
    "calibration=0 final=0 R35=0\n", height(design), summary.gatePassed);
end

function validateDesign(design, protocol)
counts = groupcounts(design, "snrDb");
pass = height(design) == protocol.developmentUserCount ...
    && isequal(sort(counts.snrDb).', sort(protocol.snrDb)) ...
    && all(counts.GroupCount == protocol.developmentUserCount ...
    /numel(protocol.snrDb)) && numel(unique(design.seed)) == height(design);
if ~pass
    error("r36:SchemeEDevelopmentDesignMismatch", ...
        "Scheme E requires the frozen 60-user, three-SNR design.");
end
end

function failures = failureTable(design, results)
failed = cellfun(@isempty, results);
for index = find(~failed).'
    failed(index) = ~results{index}.success;
end
failures = design(failed, ["seed", "trialIndex", "snrDb"]);
failures.errorIdentifier = strings(height(failures), 1);
failures.errorMessage = strings(height(failures), 1);
failedResults = results(failed);
for index = 1:numel(failedResults)
    if isempty(failedResults{index})
        failures.errorIdentifier(index) = "r36:MissingResult";
        failures.errorMessage(index) = "The required row was not produced.";
    else
        failures.errorIdentifier(index) = failedResults{index}.errorIdentifier;
        failures.errorMessage(index) = failedResults{index}.errorMessage;
    end
end
end

function writeSummaryTables(folder, summary, label)
writeLabeledTable(summary.perUser, ...
    fullfile(folder, "per_user_outputs.csv"), label);
writeLabeledTable(summary.summary, ...
    fullfile(folder, "method_summary.csv"), label);
writeLabeledTable(summary.comparisons, ...
    fullfile(folder, "paired_comparisons.csv"), label);
writeLabeledTable(summary.diagnostics, ...
    fullfile(folder, "one_step_diagnostics.csv"), label);
writeLabeledTable(summary.gate, ...
    fullfile(folder, "engineering_gate.csv"), label);
end

function writeLabeledTable(input, file, label)
input.studyLabel = repmat(label, height(input), 1);
writetable(input, file);
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

function pass = checkpointCompatible(saved, current)
pass = saved.version == current.version ...
    && saved.frozenR34SourceDigest == current.frozenR34SourceDigest ...
    && saved.r35ReadOnlyDigest == current.r35ReadOnlyDigest ...
    && saved.pilotHash == current.pilotHash ...
    && saved.algorithmSourceDigest == current.algorithmSourceDigest ...
    && saved.calibrationUsersExecuted == 0 ...
    && saved.finalTrialsExecuted == 0 ...
    && saved.r35SchemeExecutions == 0 ...
    && isequaln(saved.commonProtocol, current.commonProtocol) ...
    && isequaln(saved.schemeProtocol, current.schemeProtocol);
end

function source = algorithmManifest(project)
listing = [dir(fullfile(project, "+r36", "common", "*.m")); ...
    dir(fullfile(project, "+r36", "schemeE", "r36SchemeEConfig.m")); ...
    dir(fullfile(project, "+r36", "schemeE", "r36SteeringDerivatives.m")); ...
    dir(fullfile(project, "+r36", "schemeE", ...
    "r36SubspaceResidualGaussNewton.m")); ...
    dir(fullfile(project, "+r36", "schemeE", ...
    "r36RangeOrthogonalOneStep.m")); ...
    dir(fullfile(project, "+r36", "schemeE", "r36SchemeETrial.m"))];
source = sourceFromListing(project, listing);
end

function source = schemeEManifest(project)
listing = [dir(fullfile(project, "+r36", "**", "*.m")); ...
    dir(fullfile(project, "experiments", ...
    "run_round36_schemeE_development.m")); ...
    dir(fullfile(project, "tests", "round36*.m"))];
source = sourceFromListing(project, listing);
end

function source = r35ReadOnlyManifest(project)
listing = [dir(fullfile(project, "+r35", "**", "*.m")); ...
    dir(fullfile(project, "experiments", "*round35*.m")); ...
    dir(fullfile(project, "tests", "round35*.m"))];
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
