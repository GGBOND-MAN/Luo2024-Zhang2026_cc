function output = design(protocol)
%DESIGN Generate the new position-clustered R49 design.

arguments
    protocol (1, 1) struct = r49.config()
end

count = protocol.design.positionCount;
stream = RandStream("mt19937ar", Seed=protocol.design.positionSeed);
baseId = (1:count).';
theta = protocol.design.angleLimitsDeg(1) ...
    +diff(protocol.design.angleLimitsDeg)*rand(stream, count, 1);
rangeM = protocol.design.rangeLimitsM(1) ...
    +diff(protocol.design.rangeLimitsM)*rand(stream, count, 1);
snrValues = protocol.design.snrDb(:);
numSnr = numel(snrValues);
positionId = repelem(baseId, numSnr, 1);
positionSeed = repelem(protocol.design.positionSeed+baseId, numSnr, 1);
truthThetaDeg = repelem(theta, numSnr, 1);
truthRangeM = repelem(rangeM, numSnr, 1);
snrIndex = repmat((1:numSnr).', count, 1);
snrDb = snrValues(snrIndex);
seed = protocol.design.trialSeedRoot+100000*snrIndex+positionId;
trialIndex = (1:numel(seed)).';
output = table(positionId, positionSeed, seed, trialIndex, snrIndex, ...
    snrDb, truthThetaDeg, truthRangeM);
end
