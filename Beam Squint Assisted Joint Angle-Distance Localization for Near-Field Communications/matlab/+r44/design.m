function output = design(positionCount, protocol)
%DESIGN Generate deterministic new R44 development positions and trials.

arguments
    positionCount (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r44.config()
end

stream = RandStream("mt19937ar", Seed=protocol.development.positionSeed);
basePositionId = (1:positionCount).';
baseThetaDeg = protocol.development.angleLimitsDeg(1) ...
    +diff(protocol.development.angleLimitsDeg)*rand(stream, positionCount, 1);
baseRangeM = protocol.development.rangeLimitsM(1) ...
    +diff(protocol.development.rangeLimitsM)*rand(stream, positionCount, 1);
basePositionSeed = protocol.development.positionSeed+basePositionId;
snrValues = protocol.development.snrDb(:);
numSnr = numel(snrValues);
positionId = repelem(basePositionId, numSnr, 1);
positionSeed = repelem(basePositionSeed, numSnr, 1);
truthThetaDeg = repelem(baseThetaDeg, numSnr, 1);
truthRangeM = repelem(baseRangeM, numSnr, 1);
snrIndex = repmat((1:numSnr).', positionCount, 1);
snrDb = snrValues(snrIndex);
withinSnrIndex = repelem((1:positionCount).', numSnr, 1);
seed = protocol.development.trialSeedRoot ...
    +100000*snrIndex+withinSnrIndex;
trialIndex = (1:numel(seed)).';
output = table(positionId, positionSeed, seed, trialIndex, snrIndex, ...
    snrDb, truthThetaDeg, truthRangeM);
end
