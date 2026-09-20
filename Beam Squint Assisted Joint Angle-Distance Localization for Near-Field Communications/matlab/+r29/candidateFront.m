function estimate = candidateFront( ...
    cfg, observation, scan, angleOffsetsDeg, options)
%DETERMINISTICMULTIPEAKFRONTESTIMATE Build and refine a deterministic front bank.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    angleOffsetsDeg (:, 1) double {mustBeFinite} = [-0.2; -0.1; 0; 0.1; 0.2]
    options.IterationCaps (1, :) double ...
        {mustBeInteger, mustBePositive} = [200, 400, 800]
    options.StepTolerance (1, 1) double {mustBePositive} = 1e-6
    options.InitialSpacingM (1, 1) double {mustBePositive} = 0.05
    options.MinimumIntervals (1, 1) double ...
        {mustBeInteger, mustBePositive} = 40
    options.RefinementLevels (1, 1) double ...
        {mustBeInteger, mustBePositive} = 3
    options.PeakCount (1, 1) double ...
        {mustBeInteger, mustBePositive} = 16
    options.TolX (1, 1) double {mustBePositive} = 1e-6
    options.ScoreTolerance (1, 1) double {mustBeNonnegative} = 1e-10
    options.RangeMergeToleranceM (1, 1) double {mustBePositive} = 1e-5
    options.FeasibleCandidates table = table()
    options.KeepTrace (1, 1) logical = false
end

if numel(observation) ~= cfg.numSubcarriers
    error("fsjad:DeterministicFrontSize", ...
        "Observation size must equal cfg.numSubcarriers.");
end
iterationCaps = unique(options.IterationCaps, "stable");
if ~isequal(iterationCaps, sort(iterationCaps))
    error("fsjad:DeterministicFrontCaps", ...
        "IterationCaps must be strictly increasing.");
end

[~, peakIndex] = max(abs(observation).^2);
peakThetaDeg = scan.focusThetaDeg(peakIndex);
initialThetaDeg = min(max(peakThetaDeg + angleOffsetsDeg, ...
    cfg.thetaLimitsDeg(1)), cfg.thetaLimitsDeg(2));
initialThetaDeg = unique(initialThetaDeg, "stable");
physicalIntervalM = cfg.rangeLimitsM;
rangeSolvers = cell(numel(initialThetaDeg), 1);
candidateTables = cell(numel(initialThetaDeg), 1);

stageTimer = tic;
for angleIndex = 1:numel(initialThetaDeg)
    [candidateTables{angleIndex}, rangeSolvers{angleIndex}] = ...
        fixedAngleCandidates(cfg, observation, scan, ...
        initialThetaDeg(angleIndex), physicalIntervalM, ...
        "coarse_angle_" + angleIndex, options);
end
cost.candidateSeconds = toc(stageTimer);
cost.candidateEvaluations = sum(cellfun(@(s) s.evaluationCount, rangeSolvers));
stageOneCandidates = [normalizeFeasibleCandidates( ...
    options.FeasibleCandidates, cfg); vertcat(candidateTables{:})];
stageOneCandidates = mergeLocationCandidates(stageOneCandidates, ...
    options.RangeMergeToleranceM);
stageOneCandidates.candidateId = (1:height(stageOneCandidates)).';
stageTimer = tic;
stageOneEstimates = refineCandidates(cfg, observation, scan, ...
    stageOneCandidates, iterationCaps(1), options.StepTolerance);
cost.stageOneSeconds = toc(stageTimer);
cost.stageOneEvaluations = sum(cellfun(@(s) s.responseEvaluations, stageOneEstimates));
stageOneScores = cellfun(@(item) item.score, stageOneEstimates);
[~, stageOneIndex] = max(stageOneScores);
stageOneBest = stageOneEstimates{stageOneIndex};

stageTimer = tic;
[profileCandidates, profileSolver] = fixedAngleCandidates( ...
    cfg, observation, scan, stageOneBest.thetaDeg, physicalIntervalM, ...
    "profile_at_stage1_front", options);
cost.profileSeconds = toc(stageTimer);
cost.profileEvaluations = profileSolver.evaluationCount;
selectedCandidate = table("stage1_selected", 0, ...
    stageOneBest.thetaDeg, stageOneBest.rangeM, log(stageOneBest.score), ...
    'VariableNames', {'source', 'sourceAngleIndex', 'thetaDeg', ...
    'rangeM', 'fixedAngleLogScore'});
candidateBank = [removevars(stageOneCandidates, "candidateId"); ...
    profileCandidates; selectedCandidate];
candidateBank = mergeLocationCandidates(candidateBank, ...
    options.RangeMergeToleranceM);
candidateBank.candidateId = (1:height(candidateBank)).';
candidateBank = movevars(candidateBank, "candidateId", Before=1);

allEstimates = cell(height(candidateBank), numel(iterationCaps));
summaryParts = cell(numel(iterationCaps), 1);
selectedEstimates = cell(numel(iterationCaps), 1);
cost.finalSeconds = zeros(size(iterationCaps));
cost.finalEvaluations = zeros(size(iterationCaps));
for capIndex = 1:numel(iterationCaps)
    stageTimer = tic;
    capEstimates = refineCandidates(cfg, observation, scan, ...
        candidateBank, iterationCaps(capIndex), options.StepTolerance);
    cost.finalSeconds(capIndex) = toc(stageTimer);
    cost.finalEvaluations(capIndex) = sum(cellfun(@(s) s.responseEvaluations, capEstimates));
    allEstimates(:, capIndex) = capEstimates;
    scores = cellfun(@(item) item.score, capEstimates);
    [~, order] = sort(scores, "descend");
    rank = zeros(size(order));
    rank(order) = (1:numel(order)).';
    summaryParts{capIndex} = estimateTable( ...
        candidateBank, capEstimates, iterationCaps(capIndex), rank);
    selectedEstimates{capIndex} = capEstimates{order(1)};
    selectedEstimates{capIndex}.candidateId = ...
        candidateBank.candidateId(order(1));
    selectedEstimates{capIndex}.candidateSource = ...
        candidateBank.source(order(1));
end

if ~options.KeepTrace
    rangeSolvers = cellfun(@stripRangeTrace, rangeSolvers, ...
        UniformOutput=false);
    profileSolver = stripRangeTrace(profileSolver);
end

estimate.version = "R29-candidate-instrumentation-v1";
estimate.cost = cost;
estimate.peakCarrierIndex = peakIndex - 1;
estimate.peakThetaDeg = peakThetaDeg;
estimate.angleOffsetsDeg = angleOffsetsDeg;
estimate.initialThetaDeg = initialThetaDeg;
estimate.physicalIntervalM = physicalIntervalM;
estimate.iterationCaps = iterationCaps;
estimate.rangeSolvers = rangeSolvers;
estimate.stageOneCandidates = stageOneCandidates;
estimate.stageOneEstimates = stageOneEstimates;
estimate.stageOneSelectedIndex = stageOneIndex;
estimate.stageOneBest = stageOneBest;
estimate.profileSolver = profileSolver;
estimate.candidateBank = candidateBank;
estimate.allEstimates = allEstimates;
estimate.summary = vertcat(summaryParts{:});
estimate.selectedEstimates = selectedEstimates;
end

function [candidates, solver] = fixedAngleCandidates( ...
    cfg, observation, scan, thetaDeg, intervalM, source, options)
scoreFunction = @(rangeM) fsjad.fixedAngleProfileLogScore( ...
    cfg, observation, thetaDeg, rangeM, scan);
solver = fsjad.findRangePeakCandidates( ...
    scoreFunction, intervalM, zeros(0, 1), ...
    InitialSpacingM=options.InitialSpacingM, ...
    MinimumIntervals=options.MinimumIntervals, ...
    RefinementLevels=options.RefinementLevels, ...
    PeakCount=options.PeakCount, TolX=options.TolX, ...
    MergeToleranceM=options.RangeMergeToleranceM, ...
    KeepTrace=options.KeepTrace);
rangeM = solver.rangeM;
logScore = solver.score;
rangeSource = solver.source;
candidates = table(source + "_" + rangeSource, ...
    repmat(extractAngleIndex(source), numel(rangeM), 1), ...
    repmat(thetaDeg, numel(rangeM), 1), rangeM, logScore, ...
    'VariableNames', {'source', 'sourceAngleIndex', 'thetaDeg', ...
    'rangeM', 'fixedAngleLogScore'});
end

function angleIndex = extractAngleIndex(source)
token = regexp(source, "coarse_angle_(\d+)", "tokens", "once");
if isempty(token)
    angleIndex = 0;
else
    angleIndex = str2double(token{1});
end
end

function estimates = refineCandidates( ...
    cfg, observation, scan, candidateBank, cap, stepTolerance)
estimates = cell(height(candidateBank), 1);
for index = 1:height(candidateBank)
    estimates{index} = fsjad.refineProfileMonotone( ...
        cfg, observation, candidateBank.thetaDeg(index), ...
        candidateBank.rangeM(index), scan, MaxIterations=cap, ...
        StepTolerance=stepTolerance);
end
end

function candidates = mergeLocationCandidates(candidates, rangeToleranceM)
keep = true(height(candidates), 1);
for index = 2:height(candidates)
    previous = find(keep(1:index-1));
    sameTheta = abs(candidates.thetaDeg(previous) ...
        - candidates.thetaDeg(index)) <= 1e-10;
    sameRange = abs(candidates.rangeM(previous) ...
        - candidates.rangeM(index)) <= rangeToleranceM;
    keep(index) = ~any(sameTheta & sameRange);
end
candidates = candidates(keep, :);
end

function candidates = normalizeFeasibleCandidates(input, cfg)
if isempty(input)
    candidates = table('Size', [0, 5], ...
        'VariableTypes', {'string', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'source', 'sourceAngleIndex', 'thetaDeg', ...
        'rangeM', 'fixedAngleLogScore'});
    return;
end
required = ["thetaDeg", "rangeM"];
if ~all(ismember(required, string(input.Properties.VariableNames)))
    error("fsjad:DeterministicFrontFeasibleColumns", ...
        "FeasibleCandidates must contain thetaDeg and rangeM.");
end
valid = input.thetaDeg >= cfg.thetaLimitsDeg(1) ...
    & input.thetaDeg <= cfg.thetaLimitsDeg(2) ...
    & input.rangeM >= cfg.rangeLimitsM(1) ...
    & input.rangeM <= cfg.rangeLimitsM(2);
thetaDeg = input.thetaDeg(valid);
rangeM = input.rangeM(valid);
if ismember("source", string(input.Properties.VariableNames))
    source = string(input.source(valid));
else
    source = repmat("frozen_feasible", numel(thetaDeg), 1);
end
candidates = table(source, zeros(numel(thetaDeg), 1), thetaDeg, rangeM, ...
    nan(numel(thetaDeg), 1), ...
    'VariableNames', {'source', 'sourceAngleIndex', 'thetaDeg', ...
    'rangeM', 'fixedAngleLogScore'});
end

function output = estimateTable(candidateBank, estimates, cap, rank)
output = candidateBank;
output.iterationCap = repmat(cap, height(candidateBank), 1);
output.finalThetaDeg = cellfun(@(item) item.thetaDeg, estimates);
output.finalRangeM = cellfun(@(item) item.rangeM, estimates);
output.objective = cellfun(@(item) item.score, estimates);
output.stationarityResidual = cellfun(@(item) item.stationarity, estimates);
output.iterations = cellfun(@(item) item.iterations, estimates);
output.acceptedSteps = cellfun(@(item) item.acceptedSteps, estimates);
output.converged = cellfun(@(item) item.converged, estimates);
output.status = string(cellfun(@(item) item.status, estimates, ...
    UniformOutput=false));
output.candidateRank = rank;
end

function solver = stripRangeTrace(solver)
solver.baseGridM = [];
solver.baseScore = [];
solver.basePeakIndex = [];
solver.peakTrace = cell(0, 1);
end
