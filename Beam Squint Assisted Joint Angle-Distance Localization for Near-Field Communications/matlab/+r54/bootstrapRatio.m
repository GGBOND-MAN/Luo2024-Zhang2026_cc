function output = bootstrapRatio(perUser, population, protocol, seedOffset)
%BOOTSTRAPRATIO Position-cluster bootstrap of P_FALF/P_A range MSE.

arguments
    perUser table
    population (1, 1) string
    protocol (1, 1) struct = r54.config()
    seedOffset (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
end

positions = unique(perUser.positionId, "stable");
snrValues = protocol.design.snrDb(:);
candidateError = perUser.rangeError_P_FALF;
referenceError = perUser.rangeError_P_A;
observed = aggregateRatio(perUser.positionId, perUser.snrDb, ...
    candidateError, referenceError, positions, snrValues);
stream = RandStream("mt19937ar", Seed=protocol.bootstrap.seed+seedOffset);
draws = zeros(protocol.bootstrap.count, 1);
for draw = 1:protocol.bootstrap.count
    sampled = positions(randi(stream, numel(positions), ...
        numel(positions), 1));
    draws(draw) = aggregateRatio(perUser.positionId, perUser.snrDb, ...
        candidateError, referenceError, sampled, snrValues);
end
alpha = 1-protocol.bootstrap.confidence;
output = table(population, observed, quantile(draws, alpha/2), ...
    quantile(draws, 1-alpha/2), ...
    quantile(draws, protocol.bootstrap.confidence), ...
    protocol.bootstrap.count, protocol.bootstrap.seed+seedOffset, ...
    'VariableNames', {'population', 'observedRatio', 'lower95', ...
    'upper95', 'oneSidedUpper95', 'bootstrapCount', 'seed'});
end

function ratio = aggregateRatio(positionId, snrDb, ...
    candidateError, referenceError, sampledPositions, snrValues)
candidateMse = zeros(numel(snrValues), 1);
referenceMse = zeros(numel(snrValues), 1);
for snrIndex = 1:numel(snrValues)
    candidateValues = zeros(numel(sampledPositions), 1);
    referenceValues = zeros(numel(sampledPositions), 1);
    for positionIndex = 1:numel(sampledPositions)
        row = positionId == sampledPositions(positionIndex) ...
            & snrDb == snrValues(snrIndex);
        candidateValues(positionIndex) = candidateError(row).^2;
        referenceValues(positionIndex) = referenceError(row).^2;
    end
    candidateMse(snrIndex) = mean(candidateValues);
    referenceMse(snrIndex) = mean(referenceValues);
end
ratio = mean(candidateMse)/mean(referenceMse);
end
