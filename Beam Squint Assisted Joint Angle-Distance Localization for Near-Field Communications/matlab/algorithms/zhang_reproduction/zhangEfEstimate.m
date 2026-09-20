function result = zhangEfEstimate( ...
    cfg, observation, snapshots, carrierIndex, scan, algorithm)
%ZHANGEFESTIMATE Run a versioned enhanced-front Zhang-style estimator.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    snapshots (:, :) double
    carrierIndex (:, 1) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    algorithm (1, 1) struct = zhangEf513Config()
end

validateInputs(cfg, observation, snapshots, carrierIndex, algorithm);
musicCfg = configureMusic(cfg, algorithm);
front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
    algorithm.frontOffsetsDeg);
music = jad.localMusicEstimate(musicCfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);

result.version = algorithm.version;
result.thetaDeg = music.thetaDeg;
result.rangeM = music.rangeM;
result.front = front;
result.music = music;
result.algorithm = algorithm;
end

function validateInputs(cfg, observation, snapshots, carrierIndex, algorithm)
if numel(observation) ~= cfg.numSubcarriers
    error("zhangEf:ObservationSize", ...
        "The observation must contain cfg.numSubcarriers samples.");
end
if size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= numel(carrierIndex)
    error("zhangEf:SnapshotSize", ...
        "Snapshot dimensions must match cfg and carrierIndex.");
end
if numel(carrierIndex) ~= algorithm.fusionCarrierCount
    error("zhangEf:CarrierCount", ...
        "carrierIndex must match algorithm.fusionCarrierCount.");
end
if algorithm.subarraySize > cfg.numAntennas
    error("zhangEf:SubarraySize", ...
        "algorithm.subarraySize cannot exceed cfg.numAntennas.");
end
end

function musicCfg = configureMusic(cfg, algorithm)
musicCfg = cfg;
musicCfg.subarraySize = algorithm.subarraySize;
musicCfg.numSubarrays = cfg.numAntennas - algorithm.subarraySize + 1;
musicCfg.localHalfWidthDeg = algorithm.localHalfWidthDeg;
musicCfg.localHalfWidthM = algorithm.localHalfWidthM;
musicCfg.gridSizes = algorithm.gridSizes;
end
