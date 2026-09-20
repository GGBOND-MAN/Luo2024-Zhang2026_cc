function estimate = profileRangeAtAngle( ...
    cfg, observation, thetaDeg, scan, rangeSeedsM)
%PROFILERANGEATANGLE Concentrated-likelihood range fit at a fixed angle.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    thetaDeg (1, 1) double {mustBeFinite}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    rangeSeedsM (:, 1) double {mustBeFinite, mustBePositive} = ...
        linspace(cfg.rangeLimitsM(1), cfg.rangeLimitsM(2), 71).'
end

if isempty(observation)
    error("fsjad:profileRangeAtAngle:EmptyObservation", ...
        "The observation must be nonempty.");
end
if thetaDeg < cfg.thetaLimitsDeg(1) || thetaDeg > cfg.thetaLimitsDeg(2)
    error("fsjad:profileRangeAtAngle:AngleOutOfBounds", ...
        "The fixed angle must lie inside cfg.thetaLimitsDeg.");
end
if numel(rangeSeedsM) < 2 || any(diff(rangeSeedsM) <= 0)
    error("fsjad:profileRangeAtAngle:InvalidRangeSeeds", ...
        "At least two strictly increasing range seeds are required.");
end
if rangeSeedsM(1) < cfg.rangeLimitsM(1) ...
        || rangeSeedsM(end) > cfg.rangeLimitsM(2)
    error("fsjad:profileRangeAtAngle:RangeOutOfBounds", ...
        "Range seeds must lie inside cfg.rangeLimitsM.");
end

numSeeds = numel(rangeSeedsM);
seedScore = zeros(numSeeds, 1);
for seedIndex = 1:numSeeds
    response = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(thetaDeg), rangeSeedsM(seedIndex), scan);
    seedScore(seedIndex) = fsjad.profileScore(response, observation);
end
[gridScore, bestSeedIndex] = max(seedScore);
lowerIndex = max(1, bestSeedIndex - 1);
upperIndex = min(numSeeds, bestSeedIndex + 1);
options = optimset("TolX", 1e-6, "Display", "off");
[refinedRangeM, negativeScore, ~, output] = fminbnd( ...
    @(rangeM) -rangeScore(cfg, observation, thetaDeg, rangeM, scan), ...
    rangeSeedsM(lowerIndex), rangeSeedsM(upperIndex), options);
refinedScore = -negativeScore;

if gridScore >= refinedScore
    rangeM = rangeSeedsM(bestSeedIndex);
    score = gridScore;
    usedGridPoint = true;
else
    rangeM = refinedRangeM;
    score = refinedScore;
    usedGridPoint = false;
end

estimate.thetaDeg = thetaDeg;
estimate.rangeM = rangeM;
estimate.score = score;
estimate.rangeSeedsM = rangeSeedsM;
estimate.seedScore = seedScore;
estimate.bestSeedIndex = bestSeedIndex;
estimate.refinementIntervalM = ...
    rangeSeedsM([lowerIndex, upperIndex]);
estimate.usedGridPoint = usedGridPoint;
estimate.responseEvaluations = numSeeds + output.funcCount;
end

function score = rangeScore(cfg, observation, thetaDeg, rangeM, scan)
response = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(thetaDeg), rangeM, scan);
score = fsjad.profileScore(response, observation);
end
