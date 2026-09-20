function design = round24ConfirmatoryDesign( ...
    shardId, shardCount, countPerSnr)
%ROUND24CONFIRMATORYDESIGN Deterministic disjoint validation shard design.

arguments
    shardId (1, 1) double {mustBeInteger, mustBePositive}
    shardCount (1, 1) double {mustBeInteger, mustBePositive}
    countPerSnr (1, 1) double {mustBeInteger, mustBePositive} = 10000
end
if shardId > shardCount
    error("fsjad:Round24ShardId", ...
        "shardId cannot exceed shardCount.");
end

snrValuesDb = [-10; 0; 20];
angleLimitsDeg = [-55, 55];
rangeLimitsM = [17, 48];
truthSeedRoot = 32000000;
noiseSeedRoot = 33000000;
trialIndex = (shardId:shardCount:countPerSnr).';
design = table();
for snrIndex = 1:numel(snrValuesDb)
    stream = RandStream("mt19937ar", ...
        Seed=truthSeedRoot + 100000 * snrIndex);
    allThetaDeg = angleLimitsDeg(1) + diff(angleLimitsDeg) ...
        * rand(stream, countPerSnr, 1);
    allRangeM = rangeLimitsM(1) + diff(rangeLimitsM) ...
        * rand(stream, countPerSnr, 1);
    count = numel(trialIndex);
    seed = noiseSeedRoot + 100000 * snrIndex + trialIndex;
    truthThetaDeg = allThetaDeg(trialIndex);
    truthRangeM = allRangeM(trialIndex);
    snrDb = repmat(snrValuesDb(snrIndex), count, 1);
    design = [design; table(trialIndex, seed, truthThetaDeg, ...
        truthRangeM, snrDb)]; %#ok<AGROW>
end
end
