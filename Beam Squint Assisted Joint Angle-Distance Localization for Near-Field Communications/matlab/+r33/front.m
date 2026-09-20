function output = front(cfg, observation, scan, protocol, candidate)
%FRONT Reproduce L06 with q-only scoring and invariant reuse.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
    protocol (1, 1) struct
    candidate (1, :) table
end

if numel(observation) ~= cfg.numSubcarriers
    error("r33:FrontObservationSize", ...
        "The observation must contain every system subcarrier.");
end
timer = tic;
fullContext = r33.prepareResponseContext(cfg, scan, observation);
[~, peakColumn] = max(abs(observation).^2);
peakCarrierIndex = peakColumn-1;
carrierIndex = r30.selectUniformCarriers(cfg.numSubcarriers, ...
    candidate.frontCarrierCount, peakCarrierIndex);
carrierColumn = carrierIndex+1;
reducedContext = r33.subsetResponseContext(fullContext, carrierColumn);
peakThetaDeg = scan.focusThetaDeg(peakColumn);
initialThetaDeg = unique(min(max(peakThetaDeg ...
    + protocol.front.angleOffsetsDeg, cfg.thetaLimitsDeg(1)), ...
    cfg.thetaLimitsDeg(2)), "stable");

intervalCount = ceil(diff(cfg.rangeLimitsM)/candidate.frontRangeSpacingM);
rangeGridM = linspace(cfg.rangeLimitsM(1), cfg.rangeLimitsM(2), ...
    intervalCount+1).';
candidateParts = cell(numel(initialThetaDeg), 1);
subsetEvaluations = 0;
for angleIndex = 1:numel(initialThetaDeg)
    score = reducedRangeScore(cfg, initialThetaDeg(angleIndex), ...
        rangeGridM, reducedContext);
    subsetEvaluations = subsetEvaluations+numel(rangeGridM);
    peaks = localPeakIndices(score);
    candidateParts{angleIndex} = table( ...
        repmat(initialThetaDeg(angleIndex), numel(peaks), 1), ...
        rangeGridM(peaks), score(peaks), ...
        repmat("sparse_grid_"+angleIndex, numel(peaks), 1), ...
        'VariableNames', {'thetaDeg', 'rangeM', 'subsetLogScore', 'source'});
end
coarseScore = reducedRangeScore(cfg, peakThetaDeg, ...
    scan.focusRangeM(peakColumn), reducedContext);
subsetEvaluations = subsetEvaluations+1;
bank = vertcat(candidateParts{:});
bank = [bank; table(peakThetaDeg, scan.focusRangeM(peakColumn), ...
    coarseScore, "trajectory_peak", 'VariableNames', ...
    bank.Properties.VariableNames)];
bank = mergeLocations(bank, 1e-10, 1e-5);
[~, order] = sort(bank.subsetLogScore, "descend");
selectedRows = order(1:min(candidate.frontCandidateCount, numel(order)));
selectedBank = bank(selectedRows, :);

refined = cell(height(selectedBank), 1);
fullEvaluations = 0;
derivativeEvaluations = 0;
qOnlyEvaluations = 0;
for index = 1:height(selectedBank)
    refined{index} = r33.refineProfileMonotone(cfg, ...
        selectedBank.thetaDeg(index), selectedBank.rangeM(index), ...
        fullContext, MaxIterations=candidate.frontMaxIterations, ...
        StepTolerance=1e-6);
    fullEvaluations = fullEvaluations+refined{index}.responseEvaluations;
    derivativeEvaluations = derivativeEvaluations ...
        + refined{index}.derivativeResponseEvaluations;
    qOnlyEvaluations = qOnlyEvaluations ...
        + refined{index}.qOnlyResponseEvaluations;
end
scores = cellfun(@(item) item.score, refined);
[~, selectedIndex] = max(scores);

output.version = "R33-L06-q-only-invariant-front-v1";
output.candidateId = candidate.candidateId;
output.peakCarrierIndex = peakCarrierIndex;
output.peakThetaDeg = peakThetaDeg;
output.carrierIndex = carrierIndex;
output.initialThetaDeg = initialThetaDeg;
output.rangeGridM = rangeGridM;
output.candidateBank = bank;
output.selectedBank = selectedBank;
output.refined = refined;
output.selectedIndex = selectedIndex;
output.selected = refined{selectedIndex};
output.subsetEvaluations = subsetEvaluations;
output.fullEvaluations = fullEvaluations;
output.derivativeFullEvaluations = derivativeEvaluations;
output.qOnlyFullEvaluations = qOnlyEvaluations;
output.fullEquivalentResponses = fullEvaluations ...
    + subsetEvaluations*numel(carrierIndex)/cfg.numSubcarriers;
output.runtimeSeconds = toc(timer);
end

function logScore = reducedRangeScore(cfg, thetaDeg, rangeM, context)
logScore = zeros(size(rangeM));
for index = 1:numel(rangeM)
    response = r33.exactSpectralResponse( ...
        cfg, deg2rad(thetaDeg), rangeM(index), context);
    logScore(index) = log(max(r33.profileScore(response, context), realmin));
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

function output = mergeLocations(input, angleToleranceDeg, rangeToleranceM)
keep = true(height(input), 1);
for index = 2:height(input)
    previous = find(keep(1:index-1));
    duplicate = abs(input.thetaDeg(previous)-input.thetaDeg(index)) ...
        <= angleToleranceDeg ...
        & abs(input.rangeM(previous)-input.rangeM(index)) <= rangeToleranceM;
    keep(index) = ~any(duplicate);
end
output = input(keep, :);
end
