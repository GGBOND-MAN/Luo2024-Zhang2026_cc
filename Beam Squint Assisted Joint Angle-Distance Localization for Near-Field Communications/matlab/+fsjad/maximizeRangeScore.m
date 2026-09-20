function result = maximizeRangeScore( ...
    scoreFunction, intervalM, feasibleCandidatesM, options)
%MAXIMIZERANGESCORE Deterministic multipeak one-dimensional maximization.

arguments
    scoreFunction (1, 1) function_handle
    intervalM (1, 2) double {mustBeFinite, mustBeNonnegative}
    feasibleCandidatesM (:, 1) double {mustBeFinite} = zeros(0, 1)
    options.InitialSpacingM (1, 1) double {mustBePositive} = 0.05
    options.MinimumIntervals (1, 1) double ...
        {mustBeInteger, mustBePositive} = 40
    options.RefinementLevels (1, 1) double ...
        {mustBeInteger, mustBePositive} = 3
    options.PeakCount (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
    options.TolX (1, 1) double {mustBePositive} = 1e-6
    options.ScoreTolerance (1, 1) double {mustBeNonnegative} = 1e-10
    options.KeepTrace (1, 1) logical = false
end

if intervalM(2) <= intervalM(1)
    error("fsjad:InvalidRangeInterval", ...
        "intervalM must contain a strictly increasing interval.");
end
feasibleCandidatesM = unique(feasibleCandidatesM( ...
    feasibleCandidatesM >= intervalM(1) ...
    & feasibleCandidatesM <= intervalM(2)));
widthM = diff(intervalM);
baseIntervals = max(options.MinimumIntervals, ...
    ceil(widthM/options.InitialSpacingM));
levelSummary = repmat(emptyLevel(), options.RefinementLevels, 1);
allCandidateRangeM = zeros(0, 1);
allCandidateScore = zeros(0, 1);
allCandidateSource = strings(0, 1);
evaluationCount = 0;

for level = 1:options.RefinementLevels
    intervalCount = baseIntervals*2^(level - 1);
    gridM = linspace(intervalM(1), intervalM(2), intervalCount + 1).';
    nodesM = unique([gridM; feasibleCandidatesM]);
    nodeScore = columnScore(scoreFunction, nodesM);
    [gridIsPresent, gridNodeIndex] = ismember(gridM, nodesM);
    assert(all(gridIsPresent), "fsjad:MissingSolverGridNode");
    evaluationCount = evaluationCount + numel(nodesM);
    peakIndex = localPeakIndices(nodeScore);
    [~, peakOrder] = sort(nodeScore(peakIndex), "descend");
    peakIndex = peakIndex(peakOrder(1:min(options.PeakCount, numel(peakOrder))));

    refinedRangeM = zeros(numel(peakIndex), 1);
    refinedScore = zeros(numel(peakIndex), 1);
    refinedEvaluations = zeros(numel(peakIndex), 1);
    for peak = 1:numel(peakIndex)
        lowerIndex = max(1, peakIndex(peak) - 1);
        upperIndex = min(numel(nodesM), peakIndex(peak) + 1);
        if lowerIndex == upperIndex
            refinedRangeM(peak) = nodesM(peakIndex(peak));
            refinedScore(peak) = nodeScore(peakIndex(peak));
        else
            solverOptions = optimset( ...
                "TolX", options.TolX, "Display", "off");
            [refinedRangeM(peak), negativeScore, ~, output] = fminbnd( ...
                @(rangeM) -scoreFunction(rangeM), ...
                nodesM(lowerIndex), nodesM(upperIndex), solverOptions);
            refinedScore(peak) = -negativeScore;
            refinedEvaluations(peak) = output.funcCount;
        end
    end
    evaluationCount = evaluationCount + sum(refinedEvaluations);

    [candidateRangeM, candidateScore, candidateSource] = levelCandidates( ...
        nodesM, nodeScore, refinedRangeM, refinedScore, level);
    allCandidateRangeM = [allCandidateRangeM; candidateRangeM]; %#ok<AGROW>
    allCandidateScore = [allCandidateScore; candidateScore]; %#ok<AGROW>
    allCandidateSource = [allCandidateSource; candidateSource]; %#ok<AGROW>
    levelSummary(level) = buildLevelSummary(nodesM, nodeScore, ...
        gridNodeIndex, diff(intervalM)/intervalCount, peakIndex, ...
        refinedRangeM, refinedScore, level, options.KeepTrace);
end

[bestScore, bestIndex] = max(allCandidateScore);
bestRangeM = allCandidateRangeM(bestIndex);
finalGridStepM = levelSummary(end).gridStepM;
lowerBoundary = abs(bestRangeM - intervalM(1)) <= options.TolX;
upperBoundary = abs(bestRangeM - intervalM(2)) <= options.TolX;
lowerOutwardTrend = levelSummary(end).lowerEndpointScore ...
    > levelSummary(end).lowerInnerScore + options.ScoreTolerance;
upperOutwardTrend = levelSummary(end).upperEndpointScore ...
    > levelSummary(end).upperInnerScore + options.ScoreTolerance;

[rankingScore, order] = sort(allCandidateScore, "descend");
ranking = table(allCandidateRangeM(order), rankingScore, ...
    allCandidateSource(order), (1:numel(order)).', ...
    'VariableNames', {'rangeM', 'score', 'source', 'rank'});

result.version = "Common-Fixed-Angle-Range-Solver-v1";
result.rangeM = bestRangeM;
result.score = bestScore;
result.intervalM = intervalM;
result.feasibleCandidatesM = feasibleCandidatesM;
result.baseIntervals = baseIntervals;
result.refinementLevels = options.RefinementLevels;
result.finalGridStepM = finalGridStepM;
result.lowerBoundary = lowerBoundary;
result.upperBoundary = upperBoundary;
result.boundary = lowerBoundary || upperBoundary;
result.lowerOutwardTrend = lowerOutwardTrend;
result.upperOutwardTrend = upperOutwardTrend;
result.outwardTrend = (lowerBoundary && lowerOutwardTrend) ...
    || (upperBoundary && upperOutwardTrend);
result.status = rangeStatus(result.boundary, result.outwardTrend);
result.evaluationCount = evaluationCount;
result.candidateRanking = ranking;
result.levels = levelSummary;
end

function score = columnScore(scoreFunction, rangeM)
score = scoreFunction(rangeM);
if ~isequal(size(score), size(rangeM))
    score = score(:);
end
if numel(score) ~= numel(rangeM) || any(~isfinite(score))
    error("fsjad:InvalidRangeScore", ...
        "The score function must return one finite value per range.");
end
end

function indices = localPeakIndices(score)
count = numel(score);
if count == 1
    indices = 1;
    return;
end
interior = find(score(2:end-1) >= score(1:end-2) ...
    & score(2:end-1) >= score(3:end)) + 1;
indices = unique([1; interior(:); count]);
end

function [rangeM, score, source] = levelCandidates( ...
    nodesM, nodeScore, refinedRangeM, refinedScore, level)
rangeM = [nodesM; refinedRangeM];
score = [nodeScore; refinedScore];
source = [repmat("grid-L" + level, numel(nodesM), 1); ...
    repmat("continuous-L" + level, numel(refinedRangeM), 1)];
end

function summary = buildLevelSummary( ...
    nodesM, nodeScore, gridNodeIndex, nominalGridStepM, peakIndex, ...
    refinedRangeM, refinedScore, level, keepTrace)
summary = emptyLevel();
summary.level = level;
summary.nodeCount = numel(nodesM);
summary.gridStepM = nominalGridStepM;
summary.lowerEndpointScore = nodeScore(gridNodeIndex(1));
summary.lowerInnerScore = nodeScore(gridNodeIndex(2));
summary.upperEndpointScore = nodeScore(gridNodeIndex(end));
summary.upperInnerScore = nodeScore(gridNodeIndex(end - 1));
summary.bestNodeRangeM = nodesM(find(nodeScore == max(nodeScore), 1));
summary.bestNodeScore = max(nodeScore);
summary.peakCount = numel(peakIndex);
if keepTrace
    summary.nodesM = nodesM;
    summary.nodeScore = nodeScore;
    summary.peakIndex = peakIndex;
    summary.refinedRangeM = refinedRangeM;
    summary.refinedScore = refinedScore;
end
end

function summary = emptyLevel()
summary = struct('level', 0, 'nodeCount', 0, 'gridStepM', NaN, ...
    'lowerEndpointScore', NaN, 'lowerInnerScore', NaN, ...
    'upperEndpointScore', NaN, 'upperInnerScore', NaN, ...
    'bestNodeRangeM', NaN, 'bestNodeScore', NaN, 'peakCount', 0, ...
    'nodesM', [], 'nodeScore', [], 'peakIndex', [], ...
    'refinedRangeM', [], 'refinedScore', []);
end

function status = rangeStatus(boundary, outwardTrend)
if boundary && outwardTrend
    status = "boundary_outward";
elseif boundary
    status = "boundary_flat_or_inward";
else
    status = "interior";
end
end
