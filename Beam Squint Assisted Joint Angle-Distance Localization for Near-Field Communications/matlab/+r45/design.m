function output = design(protocol)
%DESIGN Create the new position-clustered R45 calibration design.

arguments
    protocol (1, 1) struct = r45.config()
end

count = protocol.design.positionCount;
stream = RandStream("mt19937ar", Seed=protocol.design.positionSeed);
positionIdBase = (1:count).';
thetaBase = protocol.design.angleLimitsDeg(1) ...
    +diff(protocol.design.angleLimitsDeg)*rand(stream, count, 1);
rangeBase = protocol.design.rangeLimitsM(1) ...
    +diff(protocol.design.rangeLimitsM)*rand(stream, count, 1);
positionSeedBase = protocol.design.positionSeed+positionIdBase;
snrValues = protocol.design.snrDb(:);
numSnr = numel(snrValues);
positionId = repelem(positionIdBase, numSnr, 1);
positionSeed = repelem(positionSeedBase, numSnr, 1);
truthThetaDeg = repelem(thetaBase, numSnr, 1);
truthRangeM = repelem(rangeBase, numSnr, 1);
snrIndex = repmat((1:numSnr).', count, 1);
snrDb = snrValues(snrIndex);
withinSnrIndex = repelem(positionIdBase, numSnr, 1);
seed = protocol.design.trialSeedRoot ...
    +100000*snrIndex+withinSnrIndex;
trialIndex = (1:numel(seed)).';
subset = repmat("holdout540", numel(seed), 1);
subset(ismember(positionId, protocol.design.diagnosticPositionIds)) = ...
    "diagnostic60";
output = table(positionId, positionSeed, seed, trialIndex, snrIndex, ...
    snrDb, truthThetaDeg, truthRangeM, subset);
end
