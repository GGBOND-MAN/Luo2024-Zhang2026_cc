function result = maximizeScore1D(scoreFunction, interval, feasible, options)
%MAXIMIZESCORE1D Deterministic multipeak scalar maximization.

arguments
    scoreFunction (1, 1) function_handle
    interval (1, 2) double {mustBeFinite}
    feasible (:, 1) double {mustBeFinite} = zeros(0, 1)
    options.Intervals (1, 1) double {mustBeInteger, mustBePositive} = 80
    options.PeakCount (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.TolX (1, 1) double {mustBePositive} = 1e-6
end

if interval(2) <= interval(1)
    error("r30:InvalidScalarInterval", ...
        "The scalar optimization interval must be strictly increasing.");
end
grid = linspace(interval(1), interval(2), options.Intervals + 1).';
gridScore = scoreColumn(scoreFunction, grid);
peakIndex = localPeakIndices(gridScore);
[~, order] = sort(gridScore(peakIndex), "descend");
peakIndex = peakIndex(order(1:min(options.PeakCount, numel(order))));

candidate = [interval(:); feasible(feasible >= interval(1) ...
    & feasible <= interval(2))];
candidateScore = scoreColumn(scoreFunction, candidate);
evaluationCount = numel(grid) + numel(candidate);
for index = 1:numel(peakIndex)
    lowerIndex = max(1, peakIndex(index) - 1);
    upperIndex = min(numel(grid), peakIndex(index) + 1);
    if lowerIndex == upperIndex
        refined = grid(peakIndex(index));
        refinedScore = gridScore(peakIndex(index));
    else
        settings = optimset("TolX", options.TolX, "Display", "off");
        [refined, negativeScore, ~, details] = fminbnd( ...
            @(value) -scoreFunction(value), grid(lowerIndex), ...
            grid(upperIndex), settings);
        refinedScore = -negativeScore;
        evaluationCount = evaluationCount + details.funcCount;
    end
    candidate(end+1, 1) = refined; %#ok<AGROW>
    candidateScore(end+1, 1) = refinedScore; %#ok<AGROW>
end

[candidate, uniqueIndex] = uniquetol(candidate, options.TolX, ...
    DataScale=1, OutputAllIndices=false);
candidateScore = candidateScore(uniqueIndex);
[score, selected] = max(candidateScore);
value = candidate(selected);
step = diff(interval)/options.Intervals;
boundary = abs(value-interval(1)) <= max(options.TolX, step/2) ...
    || abs(value-interval(2)) <= max(options.TolX, step/2);
outward = false;
if abs(value-interval(1)) <= max(options.TolX, step/2)
    outward = gridScore(1) > gridScore(2);
elseif abs(value-interval(2)) <= max(options.TolX, step/2)
    outward = gridScore(end) > gridScore(end-1);
end

result.version = "R30-deterministic-scalar-search-v1";
result.value = value;
result.score = score;
result.interval = interval;
result.evaluationCount = evaluationCount;
result.boundary = boundary;
result.outwardTrend = outward;
result.grid = grid;
result.gridScore = gridScore;
result.candidates = candidate;
result.candidateScore = candidateScore;
end

function score = scoreColumn(scoreFunction, values)
if isempty(values)
    score = zeros(0, 1);
    return;
end
score = scoreFunction(values);
score = score(:);
if numel(score) ~= numel(values) || any(~isfinite(score))
    error("r30:InvalidScalarScore", ...
        "The score function must return one finite score per value.");
end
end

function indices = localPeakIndices(score)
if isscalar(score)
    indices = 1;
    return;
end
interior = find(score(2:end-1) >= score(1:end-2) ...
    & score(2:end-1) >= score(3:end)) + 1;
indices = unique([1; interior(:); numel(score)]);
end
