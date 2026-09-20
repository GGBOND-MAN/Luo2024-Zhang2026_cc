function output = stressPoolDesign(protocol)
%STRESSPOOLDESIGN Generate the fixed-budget natural single-source pool.

arguments
    protocol (1, 1) struct = r52.config()
end

specification = protocol.stressPool;
count = specification.positionCount;
stream = RandStream("mt19937ar", Seed=specification.positionSeed);
positionId = (1:count).';
positionSeed = specification.positionSeed+positionId;
truthThetaDeg = specification.angleLimitsDeg(1) ...
    +diff(specification.angleLimitsDeg)*rand(stream, count, 1);
truthRangeM = specification.rangeLimitsM(1) ...
    +diff(specification.rangeLimitsM)*rand(stream, count, 1);
snrDb = repmat(specification.snrDb, count, 1);
seed = specification.trialSeedRoot+positionId;
trialIndex = positionId;
output = table(positionId, positionSeed, seed, trialIndex, ...
    snrDb, truthThetaDeg, truthRangeM);
end
