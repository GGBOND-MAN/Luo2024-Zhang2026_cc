function result = findRangePeakCandidates( ...
    scoreFunction, intervalM, feasibleCandidatesM, options)
%FINDRANGEPEAKCANDIDATES Find separated peaks with deterministic local grids.

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
        {mustBeInteger, mustBePositive} = 16
    options.TolX (1, 1) double {mustBePositive} = 1e-6
    options.MergeToleranceM (1, 1) double {mustBePositive} = 1e-5
    options.KeepTrace (1, 1) logical = false
end

if intervalM(2) <= intervalM(1)
    error("fsjad:InvalidPeakSearchInterval", ...
        "intervalM must contain a strictly increasing interval.");
end
feasibleCandidatesM = unique(feasibleCandidatesM( ...
    feasibleCandidatesM >= intervalM(1) ...
    & feasibleCandidatesM <= intervalM(2)));
intervalCount = max(options.MinimumIntervals, ...
    ceil(diff(intervalM)/options.InitialSpacingM));
baseGridM = linspace(intervalM(1), intervalM(2), intervalCount+1).';
baseScore = columnScore(scoreFunction, baseGridM);
peakIndex = localPeakIndices(baseScore);
[~, peakOrder] = sort(baseScore(peakIndex), "descend");
peakIndex = peakIndex(peakOrder(1:min(options.PeakCount, numel(peakOrder))));

peakRangeM = zeros(numel(peakIndex), 1);
peakScore = zeros(numel(peakIndex), 1);
peakTrace = cell(numel(peakIndex), 1);
evaluationCount = numel(baseGridM);
for index = 1:numel(peakIndex)
    [peakRangeM(index), peakScore(index), peakTrace{index}, evaluations] = ...
        refinePeak(scoreFunction, baseGridM, baseScore, peakIndex(index), ...
        options.RefinementLevels, options.TolX, options.KeepTrace);
    evaluationCount = evaluationCount+evaluations;
end

endpointRangeM = intervalM(:);
endpointScore = baseScore([1, end]);
feasibleScore = columnScore(scoreFunction, feasibleCandidatesM);
evaluationCount = evaluationCount+numel(feasibleCandidatesM);
[candidateRangeM, candidateScore, candidateSource] = mergeCandidates( ...
    [endpointRangeM; feasibleCandidatesM; peakRangeM], ...
    [endpointScore; feasibleScore; peakScore], ...
    ["lower_endpoint"; "upper_endpoint"; ...
    repmat("feasible", numel(feasibleCandidatesM), 1); ...
    repmat("local_peak", numel(peakRangeM), 1)], ...
    options.MergeToleranceM);
[rankingScore, order] = sort(candidateScore, "descend");
ranking = table(candidateRangeM(order), rankingScore, ...
    candidateSource(order), (1:numel(order)).', ...
    'VariableNames', {'rangeM', 'score', 'source', 'rank'});

result.version = "Deterministic-Range-Peak-Bank-v1";
result.intervalM = intervalM;
result.rangeM = ranking.rangeM;
result.score = ranking.score;
result.source = ranking.source;
result.baseGridStepM = diff(intervalM)/intervalCount;
result.refinementLevels = options.RefinementLevels;
result.peakCount = numel(peakIndex);
result.feasibleCandidatesM = feasibleCandidatesM;
result.evaluationCount = evaluationCount;
result.ranking = ranking;
if options.KeepTrace
    result.baseGridM = baseGridM;
    result.baseScore = baseScore;
    result.basePeakIndex = peakIndex;
    result.peakTrace = peakTrace;
else
    result.baseGridM = [];
    result.baseScore = [];
    result.basePeakIndex = [];
    result.peakTrace = cell(0, 1);
end
end

function [rangeM, score, trace, evaluationCount] = refinePeak( ...
    scoreFunction, baseGridM, baseScore, peakIndex, levels, tolX, keepTrace)
lowerIndex = max(1, peakIndex-1);
upperIndex = min(numel(baseGridM), peakIndex+1);
nodesM = baseGridM(lowerIndex:upperIndex);
nodeScore = baseScore(lowerIndex:upperIndex);
levelStepM = zeros(levels, 1);
levelStepM(1) = max(diff(nodesM));
traceNodes = cell(levels, 1);
traceScores = cell(levels, 1);
traceNodes{1} = nodesM;
traceScores{1} = nodeScore;
evaluationCount = 0;

for level = 2:levels
    [~, bestIndex] = max(nodeScore);
    lowerIndex = max(1, bestIndex-1);
    upperIndex = min(numel(nodesM), bestIndex+1);
    lowerM = nodesM(lowerIndex);
    upperM = nodesM(upperIndex);
    refinedNodesM = unique([nodesM(bestIndex); lowerM; upperM; ...
        (lowerM+nodesM(bestIndex))/2; ...
        (nodesM(bestIndex)+upperM)/2]);
    refinedScore = columnScore(scoreFunction, refinedNodesM);
    evaluationCount = evaluationCount+numel(refinedNodesM);
    nodesM = refinedNodesM;
    nodeScore = refinedScore;
    levelStepM(level) = max(diff(nodesM));
    traceNodes{level} = nodesM;
    traceScores{level} = nodeScore;
end

[gridScore, bestIndex] = max(nodeScore);
lowerIndex = max(1, bestIndex-1);
upperIndex = min(numel(nodesM), bestIndex+1);
if lowerIndex == upperIndex
    rangeM = nodesM(bestIndex);
    score = gridScore;
else
    solverOptions = optimset("TolX", tolX, "Display", "off");
    [continuousRangeM, negativeScore, ~, output] = fminbnd( ...
        @(candidateM) -scoreFunction(candidateM), ...
        nodesM(lowerIndex), nodesM(upperIndex), solverOptions);
    evaluationCount = evaluationCount+output.funcCount;
    continuousScore = -negativeScore;
    if continuousScore > gridScore
        rangeM = continuousRangeM;
        score = continuousScore;
    else
        rangeM = nodesM(bestIndex);
        score = gridScore;
    end
end
trace.levelStepM = levelStepM;
if keepTrace
    trace.nodesM = traceNodes;
    trace.score = traceScores;
else
    trace.nodesM = cell(0, 1);
    trace.score = cell(0, 1);
end
end

function score = columnScore(scoreFunction, rangeM)
if isempty(rangeM)
    score = zeros(0, 1);
    return;
end
score = scoreFunction(rangeM);
score = score(:);
if numel(score) ~= numel(rangeM) || any(~isfinite(score))
    error("fsjad:InvalidPeakSearchScore", ...
        "The score function must return one finite value per range.");
end
end

function indices = localPeakIndices(score)
if isscalar(score)
    indices = 1;
    return;
end
interior = find(score(2:end-1) >= score(1:end-2) ...
    & score(2:end-1) >= score(3:end))+1;
indices = unique([1; interior(:); numel(score)]);
end

function [rangeM, score, source] = mergeCandidates( ...
    proposedRangeM, proposedScore, proposedSource, toleranceM)
rangeM = zeros(0, 1);
score = zeros(0, 1);
source = strings(0, 1);
for index = 1:numel(proposedRangeM)
    match = find(abs(rangeM-proposedRangeM(index)) <= toleranceM, 1);
    if isempty(match)
        rangeM(end+1, 1) = proposedRangeM(index); %#ok<AGROW>
        score(end+1, 1) = proposedScore(index); %#ok<AGROW>
        source(end+1, 1) = proposedSource(index); %#ok<AGROW>
    elseif proposedScore(index) > score(match) ...
            && ~endsWith(source(match), "endpoint")
        rangeM(match) = proposedRangeM(index);
        score(match) = proposedScore(index);
        source(match) = proposedSource(index);
    end
end
end
