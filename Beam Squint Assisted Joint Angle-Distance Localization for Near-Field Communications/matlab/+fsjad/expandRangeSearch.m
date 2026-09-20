function result = expandRangeSearch( ...
    scoreFunction, centerRangeM, physicalLimitsM, halfWidthsM, ...
    feasibleCandidatesM, solverOptions)
%EXPANDRANGESEARCH Apply a fixed, truth-free sequence of range expansions.

arguments
    scoreFunction (1, 1) function_handle
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    physicalLimitsM (1, 2) double {mustBeFinite, mustBeNonnegative}
    halfWidthsM (1, :) double {mustBeFinite, mustBePositive}
    feasibleCandidatesM (:, 1) double {mustBeFinite} = zeros(0, 1)
    solverOptions (1, 1) struct = struct()
end

if any(diff(halfWidthsM) <= 0)
    error("fsjad:InvalidExpansionWidths", ...
        "halfWidthsM must be strictly increasing.");
end
stages = cell(numel(halfWidthsM), 1);
usedStages = 0;
for stage = 1:numel(halfWidthsM)
    intervalM = [max(physicalLimitsM(1), centerRangeM - halfWidthsM(stage)), ...
        min(physicalLimitsM(2), centerRangeM + halfWidthsM(stage))];
    stages{stage} = callSolver( ...
        scoreFunction, intervalM, feasibleCandidatesM, solverOptions);
    usedStages = stage;
    if ~(stages{stage}.boundary && stages{stage}.outwardTrend)
        break;
    end
end

result.version = "Predetermined-Range-Expansion-v1";
result.rangeM = stages{usedStages}.rangeM;
result.score = stages{usedStages}.score;
result.finalIntervalM = stages{usedStages}.intervalM;
result.finalHalfWidthM = halfWidthsM(usedStages);
result.usedStages = usedStages;
result.reachedPhysicalBoundary = any(abs(result.finalIntervalM ...
    - physicalLimitsM) <= 1e-12);
result.termination = expansionStatus(stages{usedStages}, ...
    usedStages == numel(halfWidthsM), result.reachedPhysicalBoundary);
result.stages = stages(1:usedStages);
result.evaluationCount = sum(cellfun(@(item) item.evaluationCount, ...
    result.stages));
end

function result = callSolver(scoreFunction, intervalM, candidatesM, options)
names = string(fieldnames(options));
values = struct2cell(options);
argumentsCell = cell(1, 2*numel(names));
argumentsCell(1:2:end) = cellstr(names);
argumentsCell(2:2:end) = values;
result = fsjad.maximizeRangeScore( ...
    scoreFunction, intervalM, candidatesM, argumentsCell{:});
end

function status = expansionStatus(last, exhausted, physicalBoundary)
if physicalBoundary && last.boundary && last.outwardTrend
    status = "physical_limit";
elseif exhausted && last.boundary && last.outwardTrend
    status = "maximum_expansion";
elseif last.boundary
    status = "boundary_without_outward_trend";
else
    status = "interior";
end
end
