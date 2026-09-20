function estimate = bankInitializedProfileEstimate( ...
    cfg, observation, bank, scan, numStarts, minSeparationDeg, ...
    minSeparationM)
%BANKINITIALIZEDPROFILEESTIMATE Refine separated 2-D dictionary candidates.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    bank (1, 1) struct
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    numStarts (1, 1) double {mustBeInteger, mustBePositive} = 3
    minSeparationDeg (1, 1) double {mustBeNonnegative} = 2
    minSeparationM (1, 1) double {mustBeNonnegative} = 1
end

numCandidates = size(bank.response, 2);
if size(bank.response, 1) ~= numel(observation) ...
        || numel(bank.thetaDeg) ~= numCandidates ...
        || numel(bank.rangeM) ~= numCandidates ...
        || numel(bank.energy) ~= numCandidates
    error("fsjad:bankInitializedProfileEstimate:SizeMismatch", ...
        "The candidate bank fields and observation have inconsistent sizes.");
end
if numStarts > numCandidates
    error("fsjad:bankInitializedProfileEstimate:TooManyStarts", ...
        "The number of starts cannot exceed the number of candidates.");
end

candidateScore = abs(bank.response' * observation).^2 ...
    ./ bank.energy / real(observation' * observation);
[~, scoreOrder] = sort(candidateScore, "descend");
selectedIndex = zeros(numStarts, 1);
numSelected = 0;
for orderIndex = 1:numCandidates
    candidateIndex = scoreOrder(orderIndex);
    separated = all(abs(bank.thetaDeg(candidateIndex) ...
        - bank.thetaDeg(selectedIndex(1:numSelected))) >= minSeparationDeg ...
        | abs(bank.rangeM(candidateIndex) ...
        - bank.rangeM(selectedIndex(1:numSelected))) >= minSeparationM);
    if separated
        numSelected = numSelected + 1;
        selectedIndex(numSelected) = candidateIndex;
        if numSelected == numStarts
            break;
        end
    end
end
selectedIndex = selectedIndex(1:numSelected);

refinedThetaDeg = zeros(numSelected, 1);
refinedRangeM = zeros(numSelected, 1);
refinedScore = zeros(numSelected, 1);
refinedIterations = zeros(numSelected, 1);
refinedConverged = false(numSelected, 1);
responseEvaluations = zeros(numSelected, 1);
refinedEstimate = cell(numSelected, 1);
for startIndex = 1:numSelected
    candidateIndex = selectedIndex(startIndex);
    refinedEstimate{startIndex} = fsjad.refineProfileEstimate( ...
        cfg, observation, bank.thetaDeg(candidateIndex), ...
        bank.rangeM(candidateIndex), scan, 12);
    refinedThetaDeg(startIndex) = refinedEstimate{startIndex}.thetaDeg;
    refinedRangeM(startIndex) = refinedEstimate{startIndex}.rangeM;
    refinedScore(startIndex) = refinedEstimate{startIndex}.score;
    refinedIterations(startIndex) = refinedEstimate{startIndex}.iterations;
    refinedConverged(startIndex) = refinedEstimate{startIndex}.converged;
    responseEvaluations(startIndex) = ...
        refinedEstimate{startIndex}.responseEvaluations;
end

[~, bestStart] = max(refinedScore);
estimate = refinedEstimate{bestStart};
sortedRefinedScore = sort(refinedScore, "descend");
if numSelected > 1
    scoreGap = sortedRefinedScore(1) - sortedRefinedScore(2);
else
    scoreGap = NaN;
end
estimate.numStarts = numSelected;
estimate.selectedCandidateIndex = selectedIndex;
estimate.candidateThetaDeg = bank.thetaDeg(selectedIndex);
estimate.candidateRangeM = bank.rangeM(selectedIndex);
estimate.candidateScore = candidateScore(selectedIndex);
estimate.refinedThetaDeg = refinedThetaDeg;
estimate.refinedRangeM = refinedRangeM;
estimate.refinedScore = refinedScore;
estimate.refinedIterations = refinedIterations;
estimate.refinedConverged = refinedConverged;
estimate.scoreGap = scoreGap;
estimate.bankCandidateEvaluations = numCandidates;
estimate.totalResponseEvaluations = sum(responseEvaluations);
end
