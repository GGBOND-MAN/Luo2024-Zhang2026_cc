function output = design(protocol, stage)
%DESIGN Generate independent seven-SNR R57 rows for smoke or development.

arguments
    protocol (1, 1) struct = r57.config()
    stage (1, 1) string {mustBeMember(stage, ["smoke", "development"])} ...
        = "development"
end

if stage == "smoke"
    positionCount = protocol.smoke.positionCount;
    positionSeed = protocol.smoke.positionSeed;
    trialSeedRoot = protocol.smoke.trialSeedRoot;
else
    positionCount = protocol.design.positionCount;
    positionSeed = protocol.design.positionSeed;
    trialSeedRoot = protocol.design.trialSeedRoot;
end
stream = RandStream("mt19937ar", Seed=positionSeed);
baseId = (1:positionCount).';
theta = protocol.design.angleLimitsDeg(1) ...
    +diff(protocol.design.angleLimitsDeg)*rand(stream, positionCount, 1);
rangeM = protocol.design.rangeLimitsM(1) ...
    +diff(protocol.design.rangeLimitsM)*rand(stream, positionCount, 1);
snrValues = protocol.design.snrDb(:);
numSnr = numel(snrValues);
positionId = repelem(baseId, numSnr, 1);
positionSeedColumn = repelem(positionSeed+baseId, numSnr, 1);
truthThetaDeg = repelem(theta, numSnr, 1);
truthRangeM = repelem(rangeM, numSnr, 1);
snrIndex = repmat((1:numSnr).', positionCount, 1);
snrDb = snrValues(snrIndex);
seed = trialSeedRoot+100000*snrIndex+positionId;
trialIndex = (1:numel(seed)).';
output = table(positionId, positionSeedColumn, seed, trialIndex, ...
    snrIndex, snrDb, truthThetaDeg, truthRangeM);
output.Properties.VariableNames{2} = 'positionSeed';
end
