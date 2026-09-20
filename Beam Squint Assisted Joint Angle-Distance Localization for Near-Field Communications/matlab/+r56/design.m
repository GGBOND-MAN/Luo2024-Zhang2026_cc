function output = design(protocol)
%DESIGN Generate independent seven-SNR R56 development rows.

arguments
    protocol (1, 1) struct = r56.config()
end

specification = protocol.design;
stream = RandStream("mt19937ar", Seed=specification.positionSeed);
baseId = (1:specification.positionCount).';
theta = specification.angleLimitsDeg(1) ...
    +diff(specification.angleLimitsDeg)*rand(stream, specification.positionCount, 1);
rangeM = specification.rangeLimitsM(1) ...
    +diff(specification.rangeLimitsM)*rand(stream, specification.positionCount, 1);
snrValues = specification.snrDb(:);
numSnr = numel(snrValues);
positionId = repelem(baseId, numSnr, 1);
positionSeed = repelem(specification.positionSeed+baseId, numSnr, 1);
truthThetaDeg = repelem(theta, numSnr, 1);
truthRangeM = repelem(rangeM, numSnr, 1);
snrIndex = repmat((1:numSnr).', specification.positionCount, 1);
snrDb = snrValues(snrIndex);
seed = specification.trialSeedRoot+100000*snrIndex+positionId;
trialIndex = (1:numel(seed)).';
output = table(positionId, positionSeed, seed, trialIndex, snrIndex, ...
    snrDb, truthThetaDeg, truthRangeM);
end
