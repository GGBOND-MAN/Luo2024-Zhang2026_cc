function result = fsjadRound23ComparisonEstimate( ...
    cfg, observation, snapshots, carrierIndex, scan, algorithm)
%FSJADROUND23COMPARISONESTIMATE Reproduce the effective Round 23 pipeline.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    snapshots (:, :) double
    carrierIndex (:, 1) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    algorithm (1, 1) struct = fsjadRound23ComparisonConfig()
end

validateInputs(cfg, observation, snapshots, carrierIndex, algorithm);
musicCfg = cfg;
musicCfg.subarraySize = algorithm.subarraySize;
musicCfg.numSubarrays = cfg.numAntennas - algorithm.subarraySize + 1;
musicCfg.localHalfWidthDeg = algorithm.localHalfWidthDeg;
musicCfg.localHalfWidthM = algorithm.localHalfWidthM;
musicCfg.gridSizes = algorithm.gridSizes;

front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
    algorithm.frontOffsetsDeg);
music = jad.localMusicEstimate(musicCfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);
rangeSeedsM = localRangeSeeds(cfg, front.rangeM, ...
    algorithm.profileHalfWidthM, algorithm.profileSpacingM);
profile = fsjad.profileRangeAtAngle(cfg, observation, ...
    music.thetaDeg, scan, rangeSeedsM);

result.version = algorithm.version;
result.thetaDeg = music.thetaDeg;
result.rangeM = front.rangeM + algorithm.profileLambda ...
    * (profile.rangeM - front.rangeM);
result.front = front;
result.music = music;
result.profile = profile;
result.algorithm = algorithm;
end

function validateInputs(cfg, observation, snapshots, carrierIndex, algorithm)
if numel(observation) ~= cfg.numSubcarriers
    error("fsjadRound23:ObservationSize", ...
        "The observation must contain cfg.numSubcarriers samples.");
end
if size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= numel(carrierIndex)
    error("fsjadRound23:SnapshotSize", ...
        "Snapshot dimensions must match cfg and carrierIndex.");
end
if numel(carrierIndex) ~= algorithm.fusionCarrierCount
    error("fsjadRound23:CarrierCount", ...
        "carrierIndex must match algorithm.fusionCarrierCount.");
end
if algorithm.subarraySize > cfg.numAntennas
    error("fsjadRound23:SubarraySize", ...
        "algorithm.subarraySize cannot exceed cfg.numAntennas.");
end
end

function seedsM = localRangeSeeds(cfg, centerM, halfWidthM, spacingM)
lowerM = max(cfg.rangeLimitsM(1), centerM - halfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerM + halfWidthM);
numIntervals = max(1, ceil((upperM - lowerM) / spacingM));
seedsM = linspace(lowerM, upperM, numIntervals + 1).';
end
