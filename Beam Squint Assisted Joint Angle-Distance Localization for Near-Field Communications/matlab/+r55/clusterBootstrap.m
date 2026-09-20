function output = clusterBootstrap(perUser, candidate, reference, protocol, seedOffset)
%CLUSTERBOOTSTRAP Build simultaneous range-ratio upper bounds.

arguments
    perUser table
    candidate (1, 1) string
    reference (1, 1) string
    protocol (1, 1) struct = r55.config()
    seedOffset (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
end

positions = unique(perUser.positionId, "stable");
snrValues = protocol.design.snrDb(:).';
candidateMatrix = errorMatrix(perUser, positions, snrValues, candidate);
referenceMatrix = errorMatrix(perUser, positions, snrValues, reference);
observed = ratioBySnr(candidateMatrix, referenceMatrix, 1:numel(positions));
aggregateObserved = aggregateRatio( ...
    candidateMatrix, referenceMatrix, 1:numel(positions));
stream = RandStream("mt19937ar", ...
    Seed=protocol.statistics.bootstrapSeed+seedOffset);
replicates = protocol.statistics.bootstrapCount;
ratio = zeros(replicates, numel(snrValues));
aggregate = zeros(replicates, 1);
for replicate = 1:replicates
    sampled = randi(stream, numel(positions), numel(positions), 1);
    ratio(replicate, :) = ratioBySnr( ...
        candidateMatrix, referenceMatrix, sampled);
    aggregate(replicate) = aggregateRatio( ...
        candidateMatrix, referenceMatrix, sampled);
end
critical = quantile(max(log(ratio)-log(observed), [], 2), ...
    protocol.statistics.familyConfidence);
upper = observed.*exp(critical);
limit = protocol.statistics.rangeNoninferiorityLimit;
family = table(snrValues.', observed.', upper.', ...
    repmat(limit, numel(snrValues), 1), (upper < limit).', ...
    'VariableNames', {'snrDb', 'observedRatio', ...
    'simultaneousUpper975', 'limit', 'pass'});
aggregateUpper95 = quantile(aggregate, ...
    protocol.statistics.aggregateConfidence);
aggregateTable = table(candidate, reference, aggregateObserved, ...
    aggregateUpper95, protocol.statistics.aggregateSuperiorityLimit, ...
    aggregateUpper95 < protocol.statistics.aggregateSuperiorityLimit, ...
    'VariableNames', {'candidate', 'reference', 'observedRatio', ...
    'percentileUpper95', 'limit', 'pass'});
output = struct(version=protocol.statistics.version, ...
    candidate=candidate, reference=reference, ...
    positionCount=numel(positions), replicateCount=replicates, ...
    seed=protocol.statistics.bootstrapSeed+seedOffset, ...
    family=family, aggregate=aggregateTable, critical=critical);
end

function output = errorMatrix(perUser, positions, snrValues, method)
output = zeros(numel(positions), numel(snrValues));
for positionIndex = 1:numel(positions)
    for snrIndex = 1:numel(snrValues)
        selected = perUser.positionId == positions(positionIndex) ...
            & perUser.snrDb == snrValues(snrIndex);
        if nnz(selected) ~= 1
            error("r55:BootstrapClusterBalance", ...
                "Every position must contribute one row per SNR.");
        end
        output(positionIndex, snrIndex) = ...
            perUser.("rangeError_"+method)(selected)^2;
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
