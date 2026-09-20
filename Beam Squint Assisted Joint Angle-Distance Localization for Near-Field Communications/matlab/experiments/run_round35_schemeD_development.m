function run_round35_schemeD_development(options)
%RUN_ROUND35_SCHEMED_DEVELOPMENT Run only Scheme D on 60 old users.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
addpath(fullfile(project, "+r35", "common"));
addpath(fullfile(project, "+r35", "schemeD"));
commonProtocol = r35CommonProtocol();
commonIdentity = r35AssertCommonProtocol( ...
    jad.defaultConfig(), commonProtocol);
schemeProtocol = r35SchemeDConfig();
if schemeProtocol.commonVersion ~= commonProtocol.version
    error("r35:SchemeDCommonProtocolMismatch", ...
        "Scheme D is not bound to the active common protocol.");
end

raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
design = raw.pilot.design;
validateDesign(design, schemeProtocol);
cfg = raw.pilot.expected.cfg;
r35AssertCommonProtocol(cfg, commonProtocol);
scan = fsjad.prepareScan(cfg);

algorithmSource = algorithmManifest(project);
algorithmSourceDigest = r32.sourceDigest(algorithmSource);
source = schemeDManifest(project);
reportingSourceDigest = r32.sourceDigest(source);
studyLabel = "Development study – not R34 final confirmation";
identity = struct( ...
    version="R35-schemeD-existing-60-development-v1", ...
    date="2026-09-12", dataRole="existing-60-user-development-only", ...
    studyLabel=studyLabel, commonProtocol=commonProtocol, ...
    schemeProtocol=schemeProtocol, ...
    frozenR34SourceDigest=commonIdentity.frozenSourceDigest, ...
    pilotHash=raw.pilotHash, algorithmSourceDigest=algorithmSourceDigest, ...
    reportingSourceDigest=reportingSourceDigest, ...
    calibrationUsersExecuted=0, finalTrialsExecuted=0, ...
    schemesExecuted="D-only", schemeAEstimatorExecuted=false, ...
    schemeBEstimatorExecuted=false, r34FinalReadOrExecuted=false, ...
    sameSessionRuntimeComparison=true);

folder = fullfile(project, "results", "full_spectrum", ...
    "round35_schemeD_weighted_music_v1");
if ~isfolder(folder)
    mkdir(folder);
end
checkpointFile = fullfile(folder, "checkpoint.mat");
baselines = cell(height(design), 1);
results = cell(height(design), 1);
environment = struct();
completedCheckpoint = false;
if isfile(checkpointFile)
    saved = load(checkpointFile, ...
        "identity", "design", "baselines", "results", "environment");
    if ~checkpointCompatible(saved.identity, identity) ...
            || ~isequaln(saved.design, design)
        error("r35:StaleSchemeDCheckpoint", ...
            "The Scheme D checkpoint has a different frozen identity.");
    end
    baselines = saved.baselines;
    results = saved.results;
    completedCheckpoint = all(~cellfun(@isempty, baselines)) ...
        && all(~cellfun(@isempty, results));
    if ~completedCheckpoint
        error("r35:PartialSchemeDCheckpointCannotResume", ...
            "Partial Scheme D timing cannot resume across MATLAB sessions.");
    end
    environment = saved.environment;
end

sessionId = string(datetime("now", ...
    Format="yyyyMMddHHmmssSSS"));
if ~completedCheckpoint
    pool = preparePool(options.PoolType, options.NumWorkers);
    baselines = runBaselinePhase(folder, identity, design, cfg, scan, ...
        baselines, results, pool, options, sessionId);
    baselineFailures = failureTable(design, baselines, "D0-baseline");
    writeLabeledTable(baselineFailures, ...
        fullfile(folder, "failures.csv"), studyLabel);
    if height(baselineFailures) > 0 ...
            || any(cellfun(@(x) ~x.d0Identity.passed, baselines))
        environment = environmentRecord(pool, options.BatchSize, sessionId);
        save(fullfile(folder, "result.mat"), "identity", "design", ...
            "baselines", "results", "baselineFailures", ...
            "environment", "source", "-v7.3");
        closePool(pool);
        error("r35:SchemeDD0DevelopmentFailure", ...
            "D0 identity failed; D1-D3 were not executed.");
    end

    results = runWeightedPhase(folder, identity, design, cfg, scan, ...
        baselines, results, pool, options, sessionId);
    weightedFailures = failureTable(design, results, "D1-D3-weighted");
    failures = [baselineFailures; weightedFailures];
    writeLabeledTable(failures, ...
        fullfile(folder, "failures.csv"), studyLabel);
    environment = environmentRecord(pool, options.BatchSize, sessionId);
    save(checkpointFile, "identity", "design", "baselines", ...
        "results", "environment", "-v7.3");
    closePool(pool);
    if height(weightedFailures) > 0
        save(fullfile(folder, "result.mat"), "identity", "design", ...
            "baselines", "results", "failures", "environment", ...
            "source", "-v7.3");
        error("r35:SchemeDWeightedDevelopmentFailure", ...
            "At least one D1-D3 development row failed.");
    end
else
    failures = failureTable(design, results, "D1-D3-weighted");
    writeLabeledTable(failures, ...
        fullfile(folder, "failures.csv"), studyLabel);
end

summary = r35SummarizeSchemeD( ...
    design, baselines, results, commonProtocol);
[allWeights, frequencyHz] = collectWeights(baselines, results, cfg);
writeSummaryTables(folder, summary, studyLabel);
writeLabeledTable(source, fullfile(folder, "source_hashes.csv"), studyLabel);
save(fullfile(folder, "all_weights.mat"), "allWeights", ...
    "frequencyHz", "studyLabel", "-v7.3");
figureManifest = r35BuildSchemeDFigures( ...
    summary, allWeights, frequencyHz, folder);
identity.anyMethodPassed = summary.anyMethodPassed;
identity.completedUsers = height(design);
save(checkpointFile, "identity", "design", "baselines", ...
    "results", "environment", "-v7.3");
save(fullfile(folder, "result.mat"), "identity", "design", ...
    "baselines", "results", "summary", "allWeights", ...
    "frequencyHz", "failures", "environment", "source", ...
    "figureManifest", "-v7.3");
fprintf("ROUND35_SCHEME_D_DEVELOPMENT_COMPLETE users=%d anyGate=%d " + ...
    "calibration=0 final=0 A=0 B=0\n", ...
    height(design), summary.anyMethodPassed);
end

function baselines = runBaselinePhase(folder, identity, design, cfg, scan, ...
    baselines, results, pool, options, sessionId)
pending = find(cellfun(@isempty, baselines));
for first = 1:options.BatchSize:numel(pending)
    taskRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(taskRows, :);
    batch = cell(numel(taskRows), 1);
    parfor index = 1:numel(taskRows)
        batch{index} = r35SchemeDBaselineTrial( ...
            cfg, scan, batchDesign(index, :), taskRows(index), ...
            r34.config(), r35SchemeDConfig());
    end
    baselines(taskRows) = batch;
    environment = environmentRecord(pool, options.BatchSize, sessionId);
    checkpoint = fullfile(folder, "checkpoint.mat");
    save(checkpoint, "identity", "design", "baselines", "results", ...
        "environment", "-v7.3");
    fprintf("R35 SCHEME D D0 IDENTITY: %d/%d\n", ...
        nnz(~cellfun(@isempty, baselines)), height(design));
end
end

function results = runWeightedPhase(folder, identity, design, cfg, scan, ...
    baselines, results, pool, options, sessionId)
pending = find(cellfun(@isempty, results));
for first = 1:options.BatchSize:numel(pending)
    taskRows = pending(first:min(first+options.BatchSize-1, numel(pending)));
    batchDesign = design(taskRows, :);
    batchBaselines = baselines(taskRows);
    batch = cell(numel(taskRows), 1);
    parfor index = 1:numel(taskRows)
        batch{index} = r35SchemeDWeightedTrial( ...
            cfg, scan, batchDesign(index, :), taskRows(index), ...
            batchBaselines{index}, r34.config(), r35SchemeDConfig());
    end
    results(taskRows) = batch;
    environment = environmentRecord(pool, options.BatchSize, sessionId);
    checkpoint = fullfile(folder, "checkpoint.mat");
    save(checkpoint, "identity", "design", "baselines", "results", ...
        "environment", "-v7.3");
    fprintf("R35 SCHEME D D1-D3: %d/%d\n", ...
        nnz(~cellfun(@isempty, results)), height(design));
end
end

function validateDesign(design, protocol)
counts = groupcounts(design, "snrDb");
pass = height(design) == protocol.developmentUserCount ...
    && isequal(sort(counts.snrDb).', sort(protocol.snrDb)) ...
    && all(counts.GroupCount == protocol.developmentUserCount ...
    /numel(protocol.snrDb)) && numel(unique(design.seed)) == height(design);
if ~pass
    error("r35:SchemeDDevelopmentDesignMismatch", ...
        "Scheme D requires the frozen 60-user, three-SNR design.");
end
end

function failures = failureTable(design, results, phase)
failed = cellfun(@isempty, results);
for index = find(~failed).'
    failed(index) = ~results{index}.success;
end
failures = design(failed, ["seed", "trialIndex", "snrDb"]);
failures.phase = repmat(phase, height(failures), 1);
failures.errorIdentifier = strings(height(failures), 1);
failures.errorMessage = strings(height(failures), 1);
failedResults = results(failed);
for index = 1:numel(failedResults)
    if ~isempty(failedResults{index})
        failures.errorIdentifier(index) = failedResults{index}.errorIdentifier;
        failures.errorMessage(index) = failedResults{index}.errorMessage;
    else
        failures.errorIdentifier(index) = "r35:MissingResult";
        failures.errorMessage(index) = "The required row was not produced.";
    end
end
end

function [allWeights, frequencyHz] = collectWeights(baselines, results, cfg)
carrierCount = numel(baselines{1}.paFrozen.state.frequencyHz);
userCount = numel(results);
frequencyHz = zeros(carrierCount, userCount);
allWeights = struct(D0_uniform=repmat( ...
    ones(carrierCount, 1)/carrierCount, 1, userCount), ...
    D1_gap=zeros(carrierCount, userCount), ...
    D2_information=zeros(carrierCount, userCount), ...
    D3_mix=zeros(carrierCount, userCount));
for user = 1:userCount
    currentFrequencyHz = baselines{user}.paFrozen.state.frequencyHz(:);
    if numel(currentFrequencyHz) ~= carrierCount ...
            || carrierCount ~= cfg.numSubcarriers-1
        error("r35:SchemeDCarrierIdentityDrift", ...
            "Every user must use the frozen K=2047 carrier count.");
    end
    frequencyHz(:, user) = currentFrequencyHz;
    allWeights.D1_gap(:, user) = results{user}.D1_gap.weights;
    allWeights.D2_information(:, user) = ...
        results{user}.D2_information.weights;
    allWeights.D3_mix(:, user) = results{user}.D3_mix.weights;
end
end

function writeSummaryTables(folder, summary, label)
writeLabeledTable(summary.perUser, ...
    fullfile(folder, "per_user_outputs.csv"), label);
writeLabeledTable(summary.methodSummary, ...
    fullfile(folder, "method_summary.csv"), label);
writeLabeledTable(summary.pairedComparisons, ...
    fullfile(folder, "paired_comparisons.csv"), label);
writeLabeledTable(summary.weightDiagnostics, ...
    fullfile(folder, "weight_diagnostics.csv"), label);
writeLabeledTable(summary.weightSummary, ...
    fullfile(folder, "weight_diagnostic_summary.csv"), label);
writeLabeledTable(summary.engineeringGate, ...
    fullfile(folder, "engineering_gate.csv"), label);
writeLabeledTable(summary.gateDecision, ...
    fullfile(folder, "gate_decision.csv"), label);
writeLabeledTable(summary.runtimeSummary, ...
    fullfile(folder, "runtime_summary.csv"), label);
writeLabeledTable(summary.identityAudit, ...
    fullfile(folder, "d0_identity.csv"), label);
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

function closePool(pool)
if ~isempty(pool)
    delete(pool);
end
end

function environment = environmentRecord(pool, batchSize, sessionId)
environment = struct(matlabVersion=version, computer=computer, ...
    workers=pool.NumWorkers, poolClass=class(pool), batchSize=batchSize, ...
    sessionId=sessionId, sameSessionRuntimeComparison=true, ...
    timestamp=string(datetime("now")));
end

function pass = checkpointCompatible(saved, current)
pass = saved.version == current.version ...
    && saved.frozenR34SourceDigest == current.frozenR34SourceDigest ...
    && saved.pilotHash == current.pilotHash ...
    && saved.algorithmSourceDigest == current.algorithmSourceDigest ...
    && saved.calibrationUsersExecuted == 0 ...
    && saved.finalTrialsExecuted == 0 ...
    && saved.schemesExecuted == "D-only" ...
    && ~saved.schemeAEstimatorExecuted ...
    && ~saved.schemeBEstimatorExecuted ...
    && isequaln(saved.commonProtocol, current.commonProtocol) ...
    && isequaln(saved.schemeProtocol, current.schemeProtocol);
end

function source = algorithmManifest(project)
names = ["r35SchemeDConfig.m", "r35AngleSteeringDerivative.m", ...
    "r35SingleCarrierMusicLogScores.m", ...
    "r35StagedWeightedAngleMusic.m", "r35BuildCarrierWeights.m", ...
    "r35AssertD0Identity.m", "r35SchemeDBaselineTrial.m", ...
    "r35SchemeDWeightedTrial.m"];
listing = dir(fullfile(project, "+r35", "common", "*.m"));
for name = names
    listing = [listing; dir(fullfile(project, "+r35", ...
        "schemeD", name))]; %#ok<AGROW>
end
source = sourceFromListing(project, listing);
end

function source = schemeDManifest(project)
listing = [dir(fullfile(project, "+r35", "common", "*.m")); ...
    dir(fullfile(project, "+r35", "schemeD", "*.m")); ...
    dir(fullfile(project, "experiments", ...
    "run_round35_schemeD_development.m")); ...
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
