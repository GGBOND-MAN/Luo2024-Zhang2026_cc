function output = design(protocol)
%DESIGN Generate the independent R53 development design.

arguments
    protocol (1, 1) struct = r53.config()
end

specification = protocol.design;
count = specification.positionCount;
stream = RandStream("mt19937ar", Seed=specification.positionSeed);
baseId = (1:count).';
theta = specification.angleLimitsDeg(1) ...
    +diff(specification.angleLimitsDeg)*rand(stream, count, 1);
rangeM = specification.rangeLimitsM(1) ...
    +diff(specification.rangeLimitsM)*rand(stream, count, 1);
snrValues = specification.snrDb(:);
numSnr = numel(snrValues);
positionId = repelem(baseId, numSnr, 1);
positionSeed = repelem(specification.positionSeed+baseId, numSnr, 1);
truthThetaDeg = repelem(theta, numSnr, 1);
truthRangeM = repelem(rangeM, numSnr, 1);
snrIndex = repmat((1:numSnr).', count, 1);
snrDb = snrValues(snrIndex);
seed = specification.trialSeedRoot+100000*snrIndex+positionId;
trialIndex = (1:numel(seed)).';
output = table(positionId, positionSeed, seed, trialIndex, snrIndex, ...
    snrDb, truthThetaDeg, truthRangeM);
end
