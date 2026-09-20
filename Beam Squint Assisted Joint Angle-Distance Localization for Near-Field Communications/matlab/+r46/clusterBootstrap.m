function output = clusterBootstrap(perUser, protocol)
%CLUSTERBOOTSTRAP Build simultaneous log-ratio upper bounds.

arguments
    perUser table
    protocol (1, 1) struct = r46.config()
end

positions = unique(perUser.positionId, "stable");
snrValues = protocol.design.snrDb(:).';
numPositions = numel(positions);
numSnr = numel(snrValues);
[angleCandidate, angleReference, rangeCandidate, rangeReference] = ...
    errorMatrices(perUser, positions, snrValues);
angleObserved = ratioBySnr(angleCandidate, angleReference, 1:numPositions);
rangeObserved = ratioBySnr(rangeCandidate, rangeReference, 1:numPositions);
stream = RandStream("mt19937ar", Seed=protocol.statistics.bootstrapSeed);
replicates = protocol.statistics.bootstrapCount;
angleRatio = zeros(replicates, numSnr);
rangeRatio = zeros(replicates, numSnr);
angleAggregate = zeros(replicates, 1);
rangeAggregate = zeros(replicates, 1);
for replicate = 1:replicates
    sampled = randi(stream, numPositions, numPositions, 1);
    angleRatio(replicate, :) = ratioBySnr( ...
        angleCandidate, angleReference, sampled);
    rangeRatio(replicate, :) = ratioBySnr( ...
        rangeCandidate, rangeReference, sampled);
    angleAggregate(replicate) = aggregateRatio( ...
        angleCandidate, angleReference, sampled);
    rangeAggregate(replicate) = aggregateRatio( ...
        rangeCandidate, rangeReference, sampled);
end
confidence = protocol.statistics.familyConfidence;
angleCritical = quantile(max(log(angleRatio) ...
    -log(angleObserved), [], 2), confidence);
rangeCritical = quantile(max(log(rangeRatio) ...
    -log(rangeObserved), [], 2), confidence);
angleUpper = angleObserved.*exp(angleCritical);
rangeUpper = rangeObserved.*exp(rangeCritical);
anglePass = angleUpper < protocol.statistics.angleLimit;
rangePass = rangeUpper < protocol.statistics.rangeLimit;
angleFamily = table(snrValues.', angleObserved.', angleUpper.', ...
    repmat(protocol.statistics.angleLimit, numSnr, 1), anglePass.', ...
    'VariableNames', {'snrDb', 'observedRatio', ...
    'simultaneousUpper975', 'limit', 'pass'});
rangeFamily = table(snrValues.', rangeObserved.', rangeUpper.', ...
    repmat(protocol.statistics.rangeLimit, numSnr, 1), rangePass.', ...
    'VariableNames', {'snrDb', 'observedRatio', ...
    'simultaneousUpper975', 'limit', 'pass'});
aggregate = table( ...
    ["angle"; "range"], ...
    [aggregateRatio(angleCandidate, angleReference, 1:numPositions); ...
    aggregateRatio(rangeCandidate, rangeReference, 1:numPositions)], ...
    [quantile(angleAggregate, 0.95); quantile(rangeAggregate, 0.95)], ...
    'VariableNames', {'metric', 'observedRatio', 'percentileUpper95'});
output = struct(version=protocol.statistics.version, ...
    positionCount=numPositions, replicateCount=replicates, ...
    seed=protocol.statistics.bootstrapSeed, ...
    familyConfidence=confidence, angleFamily=angleFamily, ...
    rangeFamily=rangeFamily, aggregate=aggregate, ...
    angleCritical=angleCritical, rangeCritical=rangeCritical, ...
    primaryPass=all(anglePass) && all(rangePass));
end

function [ac, ar, rc, rr] = errorMatrices(perUser, positions, snrValues)
numPositions = numel(positions);
numSnr = numel(snrValues);
ac = zeros(numPositions, numSnr);
ar = zeros(numPositions, numSnr);
rc = zeros(numPositions, numSnr);
rr = zeros(numPositions, numSnr);
for positionIndex = 1:numPositions
    for snrIndex = 1:numSnr
        selected = perUser.positionId == positions(positionIndex) ...
            & perUser.snrDb == snrValues(snrIndex);
        if nnz(selected) ~= 1
            error("r46:BootstrapClusterBalance", ...
                "Every position must contribute one row per SNR.");
        end
        ac(positionIndex, snrIndex) = perUser.angleError_P_FA(selected)^2;
        ar(positionIndex, snrIndex) = perUser.angleError_P_A(selected)^2;
        rc(positionIndex, snrIndex) = perUser.rangeError_P_FA(selected)^2;
        rr(positionIndex, snrIndex) = perUser.rangeError_P_A(selected)^2;
    end
end
end

function ratio = ratioBySnr(candidate, reference, selected)
ratio = mean(candidate(selected, :), 1)./mean(reference(selected, :), 1);
end

function ratio = aggregateRatio(candidate, reference, selected)
ratio = mean(mean(candidate(selected, :), 1)) ...
    /mean(mean(reference(selected, :), 1));
end
