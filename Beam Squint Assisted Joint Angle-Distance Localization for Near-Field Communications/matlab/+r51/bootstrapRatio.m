function output = bootstrapRatio( ...
    perUser, candidate, reference, endpoint, protocol, seedOffset)
%BOOTSTRAPRATIO Position-cluster bootstrap of the equal-SNR MSE ratio.

arguments
    perUser table
    candidate (1, 1) string
    reference (1, 1) string
    endpoint (1, 1) string {mustBeMember(endpoint, ["angle", "range"])}
    protocol (1, 1) struct = r51.config()
    seedOffset (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
end

positions = unique(perUser.positionId, "stable");
snrValues = unique(perUser.snrDb, "stable");
candidateError = perUser.(endpoint+"Error_"+candidate);
referenceError = perUser.(endpoint+"Error_"+reference);
observed = aggregateRatio(perUser.positionId, perUser.snrDb, ...
    candidateError, referenceError, positions, snrValues);
stream = RandStream("mt19937ar", ...
    Seed=protocol.bootstrap.seed+seedOffset);
draws = zeros(protocol.bootstrap.count, 1);
for draw = 1:protocol.bootstrap.count
    sampled = positions(randi(stream, numel(positions), ...
        numel(positions), 1));
    draws(draw) = aggregateRatio(perUser.positionId, perUser.snrDb, ...
        candidateError, referenceError, sampled, snrValues);
end
alpha = 1-protocol.bootstrap.confidence;
output = table(candidate, reference, endpoint, observed, ...
    quantile(draws, alpha/2), quantile(draws, 1-alpha/2), ...
    quantile(draws, protocol.bootstrap.confidence), ...
    protocol.bootstrap.count, protocol.bootstrap.seed+seedOffset, ...
    'VariableNames', {'candidate', 'reference', 'endpoint', ...
    'observedRatio', 'lower95', 'upper95', 'oneSidedUpper95', ...
    'bootstrapCount', 'seed'});
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
