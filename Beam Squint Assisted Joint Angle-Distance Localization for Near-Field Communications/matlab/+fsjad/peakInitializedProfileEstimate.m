function estimate = peakInitializedProfileEstimate( ...
    cfg, observation, scan, rangeSeedsM)
%PEAKINITIALIZEDPROFILEESTIMATE Initialize and refine the joint profile fit.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    rangeSeedsM (:, 1) double {mustBePositive} = ...
        linspace(cfg.rangeLimitsM(1), cfg.rangeLimitsM(2), 15).'
end

[~, peakIndex] = max(abs(observation).^2);
initialThetaDeg = scan.focusThetaDeg(peakIndex);
seedScore = zeros(numel(rangeSeedsM), 1);
for seedIndex = 1:numel(rangeSeedsM)
    q = fsjad.exactSpectralResponse(cfg, deg2rad(initialThetaDeg), ...
        rangeSeedsM(seedIndex), scan);
    seedScore(seedIndex) = fsjad.profileScore(q, observation);
end
[bestSeedScore, bestSeedIndex] = max(seedScore);
lowerIndex = max(1, bestSeedIndex - 1);
upperIndex = min(numel(rangeSeedsM), bestSeedIndex + 1);
options = optimset("TolX", 1e-5, "Display", "off");
[initialRangeM, ~, ~, distanceOutput] = fminbnd( ...
    @(rangeM) -fsjad.profileScore( ...
    fsjad.exactSpectralResponse(cfg, deg2rad(initialThetaDeg), ...
    rangeM, scan), observation), rangeSeedsM(lowerIndex), ...
    rangeSeedsM(upperIndex), options);

estimate = fsjad.refineProfileEstimate(cfg, observation, initialThetaDeg, ...
    initialRangeM, scan, 8);
estimate.initialThetaDeg = initialThetaDeg;
estimate.initialRangeM = initialRangeM;
estimate.initialScore = bestSeedScore;
estimate.discreteSeedRangeM = rangeSeedsM(bestSeedIndex);
estimate.peakCarrierIndex = peakIndex - 1;
estimate.rangeSeedsM = rangeSeedsM;
estimate.seedScore = seedScore;
estimate.seedResponseEvaluations = numel(rangeSeedsM);
estimate.distanceResponseEvaluations = distanceOutput.funcCount;
estimate.totalResponseEvaluations = numel(rangeSeedsM) ...
    + distanceOutput.funcCount + estimate.responseEvaluations;
end
