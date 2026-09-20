function result = maximizeScore1D(scoreFunction, interval, feasible, options)
%MAXIMIZESCORE1D Retain every evaluated base candidate and valid refinement.

arguments
    scoreFunction (1, 1) function_handle
    interval (1, 2) double {mustBeFinite}
    feasible (:, 1) double {mustBeFinite} = zeros(0, 1)
    options.Intervals (1, 1) double {mustBeInteger, mustBePositive} = 80
    options.PeakCount (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.TolX (1, 1) double {mustBePositive} = 1e-6
    options.ScoreTolerance (1, 1) double {mustBeNonnegative} = 1e-10
end

if interval(2) <= interval(1)
    error("r31:InvalidScalarInterval", ...
        "The scalar optimization interval must be strictly increasing.");
end

grid = linspace(interval(1), interval(2), options.Intervals + 1).';
gridScore = scoreColumn(scoreFunction, grid);
peakIndex = retainedPeakIndices(gridScore, options.PeakCount);
feasible = unique(feasible(feasible >= interval(1) ...
    & feasible <= interval(2)), "stable");

capacity = numel(grid) + numel(feasible) + numel(peakIndex);
candidate = nan(capacity, 1);
candidateScore = nan(capacity, 1);
candidateSource = strings(capacity, 1);
candidateCount = numel(grid);
candidate(1:candidateCount) = grid;
candidateScore(1:candidateCount) = gridScore;
candidateSource(1:candidateCount) = "grid";

baseEvaluationCount = numel(grid);
for index = 1:numel(feasible)
    exactGrid = find(grid == feasible(index), 1);
    if ~isempty(exactGrid)
        candidateSource(exactGrid) = "grid+feasible";
    else
        candidateCount = candidateCount + 1;
        candidate(candidateCount) = feasible(index);
        candidateScore(candidateCount) = scoreColumn( ...
            scoreFunction, feasible(index));
        candidateSource(candidateCount) = "feasible";
        baseEvaluationCount = baseEvaluationCount + 1;
    end
end

refinementEvaluationCount = 0;
refinement = repmat(emptyRefinement(), numel(peakIndex), 1);
for index = 1:numel(peakIndex)
    lowerIndex = max(1, peakIndex(index) - 1);
    upperIndex = min(numel(grid), peakIndex(index) + 1);
    refinement(index).peakValue = grid(peakIndex(index));
    refinement(index).lower = grid(lowerIndex);
    refinement(index).upper = grid(upperIndex);
    before = refinementEvaluationCount;
    try
        settings = optimset("TolX", options.TolX, "Display", "off");
        [refined, negativeScore, exitflag, details] = fminbnd( ...
            @checkedObjective, grid(lowerIndex), grid(upperIndex), settings);
        refinement(index).exitflag = exitflag;
        refinement(index).reportedEvaluations = details.funcCount;
        refinement(index).value = refined;
        refinement(index).score = -negativeScore;
        valid = exitflag > 0 && isfinite(refined) && isfinite(negativeScore);
        if valid
            candidateCount = candidateCount + 1;
            candidate(candidateCount) = refined;
            candidateScore(candidateCount) = -negativeScore;
            candidateSource(candidateCount) = "refined";
            refinement(index).accepted = true;
            refinement(index).status = "accepted";
        else
            refinement(index).status = "rejected-exitflag-or-nonfinite";
        end
    catch exception
        refinement(index).status = "rejected-exception";
        refinement(index).errorIdentifier = string(exception.identifier);
        refinement(index).errorMessage = string(exception.message);
    end
    refinement(index).observedEvaluations = ...
        refinementEvaluationCount - before;
end

candidate = candidate(1:candidateCount);
candidateScore = candidateScore(1:candidateCount);
candidateSource = candidateSource(1:candidateCount);
[candidate, candidateScore, candidateSource] = retainBestWithinTolerance( ...
    candidate, candidateScore, candidateSource, options.TolX);
[score, selected] = max(candidateScore);
value = candidate(selected);

rawBestScore = max([gridScore; candidateScore]);
if score < rawBestScore - options.ScoreTolerance
    error("r31:CandidateRetentionInvariant", ...
        "The selected score is below an already evaluated candidate score.");
end

step = diff(interval)/options.Intervals;
endpointTolerance = max(options.TolX, ...
    16*eps(max(1, max(abs(interval)))));
endpointHit = abs(value-interval(1)) <= endpointTolerance ...
    || abs(value-interval(2)) <= endpointTolerance;
nearBoundary = abs(value-interval(1)) <= max(endpointTolerance, step/2) ...
    || abs(value-interval(2)) <= max(endpointTolerance, step/2);
endpointOutwardTrend = false;
if abs(value-interval(1)) <= endpointTolerance
    endpointOutwardTrend = gridScore(1) > gridScore(2);
elseif abs(value-interval(2)) <= endpointTolerance
    endpointOutwardTrend = gridScore(end) > gridScore(end-1);
end

result.version = "R31-retained-candidate-scalar-search-v1";
result.value = value;
result.score = score;
result.interval = interval;
result.evaluationCount = baseEvaluationCount + refinementEvaluationCount;
result.baseEvaluationCount = baseEvaluationCount;
result.refinementEvaluationCount = refinementEvaluationCount;
result.endpointHit = endpointHit;
result.nearBoundary = nearBoundary;
result.endpointOutwardTrend = endpointOutwardTrend;
result.endpointTolerance = endpointTolerance;
result.grid = grid;
result.gridScore = gridScore;
result.peakIndex = peakIndex;
result.feasible = feasible;
result.candidates = candidate;
result.candidateScore = candidateScore;
result.candidateSource = candidateSource;
result.refinement = struct2table(refinement);
result.rawBestScore = rawBestScore;
result.retentionMargin = score - rawBestScore;

    function negativeScore = checkedObjective(candidateValue)
        refinementEvaluationCount = refinementEvaluationCount + 1;
        negativeScore = -scoreColumn(scoreFunction, candidateValue);
    end
end

function peakIndex = retainedPeakIndices(score, peakCount)
if isscalar(score)
    peakIndex = 1;
    return;
end
interior = find(score(2:end-1) >= score(1:end-2) ...
    & score(2:end-1) >= score(3:end)) + 1;
allPeakIndex = unique([1; interior(:); numel(score)]);
[~, order] = sortrows([-score(allPeakIndex), allPeakIndex], [1, 2]);
allPeakIndex = allPeakIndex(order);
peakIndex = allPeakIndex(1:min(peakCount, numel(allPeakIndex)));
[~, gridBestIndex] = max(score);
peakIndex = unique([peakIndex; gridBestIndex], "stable");
end

function [value, score, source] = retainBestWithinTolerance( ...
    value, score, source, tolerance)
[value, order] = sort(value, "ascend");
score = score(order);
source = source(order);
keep = false(size(value));
first = 1;
while first <= numel(value)
    last = find(value <= value(first) + tolerance, 1, "last");
    group = first:last;
    maximumScore = max(score(group));
    selected = group(find(score(group) == maximumScore, 1, "first"));
    keep(selected) = true;
    first = last + 1;
end
value = value(keep);
score = score(keep);
source = source(keep);
end

function score = scoreColumn(scoreFunction, values)
score = scoreFunction(values);
score = score(:);
if numel(score) ~= numel(values) || any(~isfinite(score))
    error("r31:InvalidScalarScore", ...
        "The score function must return one finite score per value.");
end
end

function output = emptyRefinement()
output = struct(peakValue=nan, lower=nan, upper=nan, value=nan, ...
    score=nan, exitflag=nan, accepted=false, status="not-run", ...
    reportedEvaluations=nan, observedEvaluations=0, ...
    errorIdentifier="", errorMessage="");
end
