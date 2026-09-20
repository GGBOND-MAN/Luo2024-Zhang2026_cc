function output = front(cfg, observation, scan, protocol, candidate)
%FRONT Sparse full-band screening followed by bounded full-spectrum refinement.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
    protocol (1, 1) struct
    candidate (1, :) table
end

if numel(observation) ~= cfg.numSubcarriers
    error("r30:FrontObservationSize", ...
        "The observation must contain every system subcarrier.");
end
timer = tic;
[~, peakColumn] = max(abs(observation).^2);
peakCarrierIndex = peakColumn - 1;
carrierIndex = r30.selectUniformCarriers(cfg.numSubcarriers, ...
    candidate.frontCarrierCount, peakCarrierIndex);
reducedScan = r30.subsetScan(scan, carrierIndex);
reducedObservation = observation(carrierIndex + 1);
peakThetaDeg = scan.focusThetaDeg(peakColumn);
initialThetaDeg = unique(min(max(peakThetaDeg + protocol.angleOffsetsDeg, ...
    cfg.thetaLimitsDeg(1)), cfg.thetaLimitsDeg(2)), "stable");

intervalCount = ceil(diff(cfg.rangeLimitsM)/candidate.frontRangeSpacingM);
rangeGridM = linspace(cfg.rangeLimitsM(1), cfg.rangeLimitsM(2), ...
    intervalCount + 1).';
candidateParts = cell(numel(initialThetaDeg), 1);
subsetEvaluations = 0;
for angleIndex = 1:numel(initialThetaDeg)
    score = reducedRangeScore(cfg, reducedObservation, ...
        initialThetaDeg(angleIndex), rangeGridM, reducedScan);
    subsetEvaluations = subsetEvaluations + numel(rangeGridM);
    peaks = localPeakIndices(score);
    candidateParts{angleIndex} = table( ...
        repmat(initialThetaDeg(angleIndex), numel(peaks), 1), ...
        rangeGridM(peaks), score(peaks), ...
        repmat("sparse_grid_" + angleIndex, numel(peaks), 1), ...
        'VariableNames', {'thetaDeg', 'rangeM', 'subsetLogScore', 'source'});
end
bank = vertcat(candidateParts{:});
coarseScore = reducedRangeScore(cfg, reducedObservation, peakThetaDeg, ...
    scan.focusRangeM(peakColumn), reducedScan);
subsetEvaluations = subsetEvaluations + 1;
bank = [bank; table(peakThetaDeg, scan.focusRangeM(peakColumn), ...
    coarseScore, "trajectory_peak", 'VariableNames', bank.Properties.VariableNames)];
bank = mergeLocations(bank, 1e-10, 1e-5);
[~, order] = sort(bank.subsetLogScore, "descend");
selectedRows = order(1:min(candidate.frontCandidateCount, numel(order)));
selectedBank = bank(selectedRows, :);

refined = cell(height(selectedBank), 1);
fullEvaluations = 0;
for index = 1:height(selectedBank)
    refined{index} = fsjad.refineProfileMonotone(cfg, observation, ...
        selectedBank.thetaDeg(index), selectedBank.rangeM(index), scan, ...
        MaxIterations=candidate.frontMaxIterations, StepTolerance=1e-6);
    fullEvaluations = fullEvaluations + refined{index}.responseEvaluations;
end
scores = cellfun(@(item) item.score, refined);
[~, selectedIndex] = max(scores);
selected = refined{selectedIndex};

output.version = protocol.frontVersion;
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
output.selected = selected;
output.subsetEvaluations = subsetEvaluations;
output.fullEvaluations = fullEvaluations;
output.fullEquivalentResponses = fullEvaluations ...
    + subsetEvaluations*numel(carrierIndex)/cfg.numSubcarriers;
output.fullResponseUpperBound = height(selectedBank) ...
    *(106*candidate.frontMaxIterations + 1);
output.runtimeSeconds = toc(timer);
end

function logScore = reducedRangeScore(cfg, observation, thetaDeg, rangeM, scan)
logScore = zeros(size(rangeM));
for index = 1:numel(rangeM)
    response = fsjad.exactSpectralResponse(cfg, deg2rad(thetaDeg), ...
        rangeM(index), scan);
    logScore(index) = log(max(fsjad.profileScore(response, observation), ...
        realmin));
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
