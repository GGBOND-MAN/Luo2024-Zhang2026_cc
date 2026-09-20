function estimate = angleMultistartProfileEstimate( ...
    cfg, observation, scan, angleOffsetsDeg, rangeSeedsM)
%ANGLEMULTISTARTPROFILEESTIMATE Refine continuous range at nearby angles.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    angleOffsetsDeg (:, 1) double = [-0.1; 0; 0.1]
    rangeSeedsM (:, 1) double {mustBePositive} = ...
        linspace(cfg.rangeLimitsM(1), cfg.rangeLimitsM(2), 15).'
end

[~, peakIndex] = max(abs(observation).^2);
peakThetaDeg = scan.focusThetaDeg(peakIndex);
initialThetaDeg = min(max(peakThetaDeg + angleOffsetsDeg, ...
    cfg.thetaLimitsDeg(1)), cfg.thetaLimitsDeg(2));
numStarts = numel(initialThetaDeg);
initialRangeM = zeros(numStarts, 1);
initialScore = zeros(numStarts, 1);
distanceResponseEvaluations = zeros(numStarts, 1);
refinedThetaDeg = zeros(numStarts, 1);
refinedRangeM = zeros(numStarts, 1);
refinedScore = zeros(numStarts, 1);
refinedIterations = zeros(numStarts, 1);
refinedConverged = false(numStarts, 1);
responseEvaluations = zeros(numStarts, 1);
refinedEstimate = cell(numStarts, 1);
options = optimset("TolX", 1e-5, "Display", "off");

for startIndex = 1:numStarts
    seedScore = zeros(numel(rangeSeedsM), 1);
    for seedIndex = 1:numel(rangeSeedsM)
        response = fsjad.exactSpectralResponse(cfg, ...
            deg2rad(initialThetaDeg(startIndex)), ...
            rangeSeedsM(seedIndex), scan);
        seedScore(seedIndex) = fsjad.profileScore(response, observation);
    end
    [initialScore(startIndex), bestSeedIndex] = max(seedScore);
    lowerIndex = max(1, bestSeedIndex - 1);
    upperIndex = min(numel(rangeSeedsM), bestSeedIndex + 1);
    [initialRangeM(startIndex), ~, ~, distanceOutput] = fminbnd( ...
        @(rangeM) -fsjad.profileScore(fsjad.exactSpectralResponse( ...
        cfg, deg2rad(initialThetaDeg(startIndex)), rangeM, scan), ...
        observation), rangeSeedsM(lowerIndex), rangeSeedsM(upperIndex), ...
        options);
    distanceResponseEvaluations(startIndex) = distanceOutput.funcCount;
    refinedEstimate{startIndex} = fsjad.refineProfileEstimate( ...
        cfg, observation, initialThetaDeg(startIndex), ...
        initialRangeM(startIndex), scan, 12);
    refinedThetaDeg(startIndex) = refinedEstimate{startIndex}.thetaDeg;
    refinedRangeM(startIndex) = refinedEstimate{startIndex}.rangeM;
    refinedScore(startIndex) = refinedEstimate{startIndex}.score;
    refinedIterations(startIndex) = refinedEstimate{startIndex}.iterations;
    refinedConverged(startIndex) = refinedEstimate{startIndex}.converged;
    responseEvaluations(startIndex) = numel(rangeSeedsM) ...
        + distanceOutput.funcCount ...
        + refinedEstimate{startIndex}.responseEvaluations;
end

[~, bestStart] = max(refinedScore);
estimate = refinedEstimate{bestStart};
sortedScore = sort(refinedScore, "descend");
if numStarts > 1
    scoreGap = sortedScore(1) - sortedScore(2);
else
    scoreGap = NaN;
end
estimate.peakCarrierIndex = peakIndex - 1;
estimate.peakThetaDeg = peakThetaDeg;
estimate.angleOffsetsDeg = angleOffsetsDeg;
estimate.initialThetaDeg = initialThetaDeg;
estimate.initialRangeM = initialRangeM;
estimate.initialScore = initialScore;
estimate.distanceResponseEvaluations = distanceResponseEvaluations;
estimate.refinedThetaDeg = refinedThetaDeg;
estimate.refinedRangeM = refinedRangeM;
estimate.refinedScore = refinedScore;
estimate.refinedIterations = refinedIterations;
estimate.refinedConverged = refinedConverged;
estimate.responseEvaluationsPerStart = responseEvaluations;
estimate.scoreGap = scoreGap;
estimate.numStarts = numStarts;
estimate.totalResponseEvaluations = sum(responseEvaluations);
end
