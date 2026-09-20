function output = stressDesign(protocol)
%STRESSDESIGN Build the controlled front-support stress design.

arguments
    protocol (1, 1) struct = r51.config()
end

specification = protocol.stressDesign;
count = specification.positionCount;
stream = RandStream("mt19937ar", Seed=specification.positionSeed);
baseId = (1:count).';
theta = specification.angleLimitsDeg(1) ...
    + diff(specification.angleLimitsDeg)*rand(stream, count, 1);
rangeM = specification.rangeLimitsM(1) ...
    + diff(specification.rangeLimitsM)*rand(stream, count, 1);
snrValues = specification.snrDb(:);
types = specification.types(:);
rowsPerPosition = numel(snrValues)*numel(types);
positionId = repelem(baseId, rowsPerPosition, 1);
positionSeed = repelem(specification.positionSeed+baseId, rowsPerPosition, 1);
truthThetaDeg = repelem(theta, rowsPerPosition, 1);
truthRangeM = repelem(rangeM, rowsPerPosition, 1);
snrDb = repmat(repelem(snrValues, numel(types)), count, 1);
stressType = repmat(types, count*numel(snrValues), 1);
snrIndex = repmat(repelem((1:numel(snrValues)).', numel(types)), count, 1);
stressIndex = repmat((1:numel(types)).', count*numel(snrValues), 1);
stressSign = repelem((-1).^baseId, rowsPerPosition, 1);
seed = specification.trialSeedRoot+100000*snrIndex ...
    +1000*stressIndex+positionId;
trialIndex = (1:numel(seed)).';
output = table(positionId, positionSeed, seed, trialIndex, snrIndex, ...
    stressIndex, snrDb, stressType, stressSign, ...
    truthThetaDeg, truthRangeM);
end
