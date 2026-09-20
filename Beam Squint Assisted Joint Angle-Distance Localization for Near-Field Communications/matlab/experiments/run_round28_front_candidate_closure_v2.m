function run_round28_front_candidate_closure_v2(options)
%RUN_ROUND28_FRONT_CANDIDATE_CLOSURE_V2 Run nine-seed front closure.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.OutputRoot (1, 1) string = ""
    options.V1ResultRoot (1, 1) string = ""
    options.Force (1, 1) logical = false
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
originalPath = path;
addpath(project);
cleanup = onCleanup(@() path(originalPath));
setup = fsjad.round28FrontV2Setup(project);
design = setup.design;
preflightFile = fullfile(project, "results", "full_spectrum", ...
    "round28_front_candidate_preflight_v2", "preflight_passed.mat");
assert(isfile(preflightFile), "fsjad:Round28FrontV2PreflightRequired", ...
    "Run preflight_round28_front_v2 before this experiment.");
preflight = load(preflightFile, "source");
assert(isequal(preflight.source, setup.source), ...
    "fsjad:Round28FrontV2PreflightStale", ...
    "Source changed after preflight. Run preflight again.");

if options.OutputRoot == ""
    root = fullfile(project, "results", "full_spectrum", ...
        "round28_front_candidate_closure_v2");
else
    root = options.OutputRoot;
end
if options.V1ResultRoot == ""
    v1Root = fullfile(project, "results", "full_spectrum", ...
        "round28_targeted_front_closure_v1");
else
    v1Root = options.V1ResultRoot;
end
v1StartsFile = fullfile(v1Root, "all_starts_200_400_800.csv");
v1ProfileFile = fullfile(v1Root, "profile_front_extra_start.csv");
assert(isfile(v1StartsFile) && isfile(v1ProfileFile), ...
    "fsjad:Round28FrontV2MissingV1", ...
    "The two Round 28 v1 summary CSV files are required for comparison.");
if ~isfolder(root)
    mkdir(root);
end
v1Starts = readtable(v1StartsFile, TextType="string");
v1Profile = readtable(v1ProfileFile, TextType="string");
feasibleCandidates = frozenV1Candidates(design, v1Starts);
completeFile = fullfile(root, "COMPLETE.csv");
if isfile(completeFile) && ~options.Force
    complete = readtable(completeFile, TextType="string");
    if isequal(complete.seed, setup.protocol.targetSeeds)
        fprintf("ROUND28_FRONT_V2_ALREADY_COMPLETE %s\n", root);
        return;
    end
end

environment = experimentEnvironment(options);
pool = ensureRequestedPool(options.PoolType, options.NumWorkers);
environment.actualNumWorkers = pool.NumWorkers;
environment.actualPoolClass = string(class(pool));
if environment.actualNumWorkers ~= environment.requestedNumWorkers
    error("fsjad:Round28FrontV2WorkerMismatch", ...
        "Requested %d workers but MATLAB created %d.", ...
        environment.requestedNumWorkers, environment.actualNumWorkers);
end

cfg = setup.cfg;
scan = fsjad.prepareScan(cfg);
algorithm = setup.algorithm;
protocol = setup.protocol;
frontOffsetsDeg = algorithm.frontOffsetsDeg;
iterationCaps = protocol.iterationCaps;
stepTolerance = protocol.stepTolerance;
initialSpacingM = protocol.initialSpacingM;
minimumIntervals = protocol.minimumIntervals;
refinementLevels = protocol.refinementLevels;
peakCount = protocol.peakCount;
tolX = protocol.tolX;
scoreTolerance = protocol.scoreTolerance;
rangeMergeToleranceM = protocol.rangeMergeToleranceM;
results = cell(height(design), 1);
timer = tic;
parfor index = 1:height(design)
    replay = fsjad.replayRound27Data(cfg, scan, design(index, :));
    results{index} = fsjad.deterministicMultipeakFrontEstimate( ...
        cfg, replay.observation, scan, frontOffsetsDeg, ...
        IterationCaps=iterationCaps, StepTolerance=stepTolerance, ...
        InitialSpacingM=initialSpacingM, ...
        MinimumIntervals=minimumIntervals, ...
        RefinementLevels=refinementLevels, PeakCount=peakCount, ...
        TolX=tolX, ScoreTolerance=scoreTolerance, ...
        RangeMergeToleranceM=rangeMergeToleranceM, ...
        FeasibleCandidates=feasibleCandidates{index});
end
fprintf("R28 front-v2 parallel phase completed in %.2f h.\n", toc(timer)/3600);

[candidateBank, allStarts, selected] = resultTables(design, results);
comparison = compareWithV1(selected, v1Starts, v1Profile);
serialThreadCheck = repeatSerial(setup, scan, results, feasibleCandidates);

writetable(candidateBank, fullfile(root, "candidate_bank.csv"));
writetable(allStarts, fullfile(root, "all_starts_200_400_800.csv"));
writetable(selected, fullfile(root, "selected_front_200_400_800.csv"));
writetable(comparison, fullfile(root, "v1_v2_comparison.csv"));
writetable(serialThreadCheck, fullfile(root, "serial_thread_check.csv"));
writetable(setup.source, fullfile(root, "source_hashes.csv"));
save(fullfile(root, "front_candidate_closure_v2.mat"), ...
    "setup", "design", "results", "candidateBank", "allStarts", ...
    "selected", "comparison", "serialThreadCheck", "environment", "-v7.3");
complete = table(setup.protocol.targetSeeds, ...
    repmat(setup.protocol.version, height(design), 1), ...
    'VariableNames', {'seed', 'protocolVersion'});
writetable(complete, completeFile);
fprintf("ROUND28_FRONT_V2_COMPLETE %s\n", root);
end

function environment = experimentEnvironment(options)
environment.matlabVersion = string(version);
environment.computer = string(computer);
environment.poolType = options.PoolType;
environment.requestedNumWorkers = options.NumWorkers;
environment.timestamp = string(datetime("now", TimeZone="local"));
environment.hostName = string(getenv("COMPUTERNAME"));
if environment.hostName == ""
    environment.hostName = string(getenv("HOSTNAME"));
end
end

function pool = ensureRequestedPool(poolType, workerCount)
pool = gcp("nocreate");
if ~isempty(pool)
    isThreadPool = isa(pool, "parallel.ThreadPool");
    requestedThreadPool = poolType == "Threads";
    if pool.NumWorkers ~= workerCount || isThreadPool ~= requestedThreadPool
        delete(pool);
        pool = [];
    end
end
if isempty(pool)
    pool = parpool(poolType, workerCount);
end
end

function [candidateBank, allStarts, selected] = resultTables(design, results)
candidateParts = cell(height(design), 1);
startParts = cell(height(design), 1);
selectedParts = cell(height(design), 1);
for index = 1:height(design)
    candidateParts{index} = addDesignColumns( ...
        results{index}.candidateBank, design(index, :));
    startParts{index} = addDesignColumns( ...
        results{index}.summary, design(index, :));
    selectedParts{index} = selectedTable(results{index}, design(index, :));
end
candidateBank = vertcat(candidateParts{:});
allStarts = vertcat(startParts{:});
selected = vertcat(selectedParts{:});
end

function output = addDesignColumns(input, row)
output = addvars(input, repmat(row.seed, height(input), 1), ...
    repmat(row.snrDb, height(input), 1), ...
    repmat(row.truthThetaDeg, height(input), 1), ...
    repmat(row.truthRangeM, height(input), 1), Before=1, ...
    NewVariableNames={'seed', 'snrDb', 'truthThetaDeg', 'truthRangeM'});
end

function output = selectedTable(result, row)
count = numel(result.iterationCaps);
thetaDeg = zeros(count, 1);
rangeM = zeros(count, 1);
objective = zeros(count, 1);
stationarityResidual = zeros(count, 1);
iterations = zeros(count, 1);
converged = false(count, 1);
status = strings(count, 1);
candidateId = zeros(count, 1);
candidateSource = strings(count, 1);
for index = 1:count
    item = result.selectedEstimates{index};
    thetaDeg(index) = item.thetaDeg;
    rangeM(index) = item.rangeM;
    objective(index) = item.score;
    stationarityResidual(index) = item.stationarity;
    iterations(index) = item.iterations;
    converged(index) = item.converged;
    status(index) = item.status;
    candidateId(index) = item.candidateId;
    candidateSource(index) = item.candidateSource;
end
output = table(repmat(row.seed, count, 1), repmat(row.snrDb, count, 1), ...
    repmat(row.truthThetaDeg, count, 1), repmat(row.truthRangeM, count, 1), ...
    result.iterationCaps(:), thetaDeg, rangeM, objective, ...
    stationarityResidual, iterations, converged, status, ...
    candidateId, candidateSource, ...
    'VariableNames', {'seed', 'snrDb', 'truthThetaDeg', 'truthRangeM', ...
    'iterationCap', 'thetaDeg', 'rangeM', 'objective', ...
    'stationarityResidual', 'iterations', 'converged', 'status', ...
    'candidateId', 'candidateSource'});
end

function comparison = compareWithV1(selected, v1Starts, v1Profile)
comparison = selected;
rowCount = height(selected);
v1BestObjective = zeros(rowCount, 1);
v1ProfileObjective = zeros(rowCount, 1);
for index = 1:rowCount
    startRows = v1Starts.seed == selected.seed(index) ...
        & v1Starts.iterationCap == selected.iterationCap(index);
    profileRows = v1Profile.seed == selected.seed(index) ...
        & v1Profile.iterationCap == selected.iterationCap(index);
    assert(any(startRows) && nnz(profileRows) == 1, ...
        "fsjad:Round28FrontV2IncompleteV1Comparison");
    v1BestObjective(index) = max(v1Starts.objective(startRows));
    v1ProfileObjective(index) = v1Profile.objective(profileRows);
end
comparison.v1BestObjective = v1BestObjective;
comparison.v1ProfileObjective = v1ProfileObjective;
comparison.objectiveGainOverV1 = comparison.objective-v1BestObjective;
comparison.objectiveGainOverV1Profile = ...
    comparison.objective-v1ProfileObjective;
comparison.higherThanV1 = comparison.objective ...
    > v1BestObjective+1e-10;
comparison.higherThanV1Profile = comparison.objective ...
    > v1ProfileObjective+1e-10;
end

function candidates = frozenV1Candidates(design, v1Starts)
candidates = cell(height(design), 1);
for index = 1:height(design)
    rows = v1Starts.seed == design.seed(index) ...
        & v1Starts.iterationCap == 200;
    source = "v1_frozen_start_" + string(v1Starts.startIndex(rows));
    candidates{index} = table(source, v1Starts.startThetaDeg(rows), ...
        v1Starts.startRangeM(rows), ...
        'VariableNames', {'source', 'thetaDeg', 'rangeM'});
end
end

function output = repeatSerial( ...
    setup, scan, parallelResults, feasibleCandidates)
repeatSeeds = setup.protocol.serialRepeatSeeds;
output = table();
for seedIndex = 1:numel(repeatSeeds)
    designIndex = find(setup.design.seed == repeatSeeds(seedIndex), 1);
    row = setup.design(designIndex, :);
    replay = fsjad.replayRound27Data(setup.cfg, scan, row);
    repeated = fsjad.deterministicMultipeakFrontEstimate( ...
        setup.cfg, replay.observation, scan, setup.algorithm.frontOffsetsDeg, ...
        IterationCaps=setup.protocol.iterationCaps, ...
        StepTolerance=setup.protocol.stepTolerance, ...
        InitialSpacingM=setup.protocol.initialSpacingM, ...
        MinimumIntervals=setup.protocol.minimumIntervals, ...
        RefinementLevels=setup.protocol.refinementLevels, ...
        PeakCount=setup.protocol.peakCount, TolX=setup.protocol.tolX, ...
        ScoreTolerance=setup.protocol.scoreTolerance, ...
        RangeMergeToleranceM=setup.protocol.rangeMergeToleranceM, ...
        FeasibleCandidates=feasibleCandidates{designIndex});
    reference = parallelResults{designIndex};
    parallelSelected = selectedTable(reference, row);
    serialSelected = selectedTable(repeated, row);
    sourceEqual = isequal(reference.candidateBank.source, ...
        repeated.candidateBank.source);
    candidateCountEqual = height(reference.candidateBank) ...
        == height(repeated.candidateBank);
    if candidateCountEqual && sourceEqual
        maxCandidateThetaDifferenceDeg = max(abs( ...
            reference.candidateBank.thetaDeg-repeated.candidateBank.thetaDeg));
        maxCandidateRangeDifferenceM = max(abs( ...
            reference.candidateBank.rangeM-repeated.candidateBank.rangeM));
    else
        maxCandidateThetaDifferenceDeg = Inf;
        maxCandidateRangeDifferenceM = Inf;
    end
    entry = table(row.seed, candidateCountEqual, sourceEqual, ...
        maxCandidateThetaDifferenceDeg, maxCandidateRangeDifferenceM, ...
        max(abs(parallelSelected.objective-serialSelected.objective)), ...
        max(abs(parallelSelected.thetaDeg-serialSelected.thetaDeg)), ...
        max(abs(parallelSelected.rangeM-serialSelected.rangeM)), ...
        isequal(parallelSelected.status, serialSelected.status), ...
        'VariableNames', {'seed', 'candidateCountEqual', 'sourceEqual', ...
        'maxCandidateThetaDifferenceDeg', 'maxCandidateRangeDifferenceM', ...
        'maxObjectiveDifference', 'maxThetaDifferenceDeg', ...
        'maxRangeDifferenceM', 'statusEqual'});
    entry.withinTolerance = entry.candidateCountEqual ...
        & entry.sourceEqual ...
        & entry.maxCandidateThetaDifferenceDeg <= 1e-10 ...
        & entry.maxCandidateRangeDifferenceM <= 1e-5 ...
        & entry.maxObjectiveDifference <= 1e-10 ...
        & entry.maxThetaDifferenceDeg <= 1e-7 ...
        & entry.maxRangeDifferenceM <= 1e-5 ...
        & entry.statusEqual;
    output = [output; entry]; %#ok<AGROW>
end
end
