function result = estimate( ...
    cfg, observation, snapshots, scan, method, protocol, options)
%ESTIMATE Run one R32-equivalent method using a declared fast variant.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct
    method (1, 1) string {mustBeMember(method, ...
        ["C_enhanced", "H_A", "P_A", "C_public"])}
    protocol (1, 1) struct = r33.config()
    options.UseFastResponse (1, 1) logical = true
    options.UseGram (1, 1) logical = true
end

r32.assertFrozenConfig(cfg, protocol.r32);
if numel(observation) ~= cfg.numSubcarriers ...
        || size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= cfg.numSubcarriers
    error("r33:OnlineInputSize", ...
        "Every fast method requires the full z vector and N-by-M Y array.");
end
totalTimer = tic;
if options.UseFastResponse
    frontOutput = r33.front(cfg, observation, scan, protocol.r32, ...
        r32.candidate(protocol.r32));
else
    frontProtocol = r30.config();
    frontProtocol.frontVersion = protocol.r32.front.version;
    frontProtocol.angleOffsetsDeg = protocol.r32.front.angleOffsetsDeg;
    frontOutput = r30.front(cfg, observation, scan, frontProtocol, ...
        r32.candidate(protocol.r32));
end
front = frontOutput.selected;
[carrierCount, subarraySize] = methodDimensions(method, protocol.r32);
carrierIndex = r30.selectLocalCarriers( ...
    cfg.numSubcarriers, carrierCount, frontOutput.peakCarrierIndex);
[state, musicCfg, stateCost] = r33.prepareMusicState(cfg, ...
    snapshots(:, carrierIndex+1), carrierIndex, ...
    front.thetaDeg, front.rangeM, subarraySize, protocol.gram, ...
    UseGram=options.UseGram);

searchTimer = tic;
if method == "C_enhanced"
    estimate = r31.stagedJointMusic(musicCfg, state, ...
        front.thetaDeg, front.rangeM, ...
        protocol.r32.enhancedC.angleHalfWidthDeg, ...
        protocol.r32.enhancedC.rangeHalfWidthM, ...
        protocol.r32.enhancedC.gridSizes);
elseif method == "C_public"
    estimate = r31.stagedJointMusic(musicCfg, state, ...
        front.thetaDeg, front.rangeM, ...
        protocol.r32.publicC.angleHalfWidthDeg, ...
        protocol.r32.publicC.rangeHalfWidthM, ...
        protocol.r32.publicC.gridSizes);
else
    estimate = r31.stagedAngleMusic(musicCfg, state, ...
        front.thetaDeg, front.rangeM, ...
        protocol.r32.music.angleHalfWidthDeg, ...
        protocol.r32.music.gridSizes);
end
searchSeconds = toc(searchTimer);

profile = struct();
profileSeconds = 0;
if method == "P_A"
    profileTimer = tic;
    if options.UseFastResponse
        profile = r33.profileAtAngle(cfg, observation, scan, ...
            estimate.thetaDeg, front.rangeM, protocol);
    else
        profile = r32.profileAtAngle(cfg, observation, scan, ...
            estimate.thetaDeg, front.rangeM, protocol.r32);
    end
    profileSeconds = toc(profileTimer);
end
[thetaDeg, rangeM] = outputLocation(method, estimate, profile, front);

result.version = variantVersion(options.UseFastResponse, options.UseGram);
result.method = method;
result.options = options;
result.front = frontOutput;
result.state = state;
result.musicCfg = musicCfg;
result.estimate = estimate;
result.profile = profile;
result.thetaDeg = thetaDeg;
result.rangeM = rangeM;
result.carrierIndex = carrierIndex;
result.cost = stateCost;
result.cost.frontSeconds = frontOutput.runtimeSeconds;
result.cost.searchSeconds = searchSeconds;
result.cost.profileSeconds = profileSeconds;
result.cost.totalOnlineSeconds = toc(totalTimer);
result.cost.sparseResponseCalls = frontOutput.subsetEvaluations;
result.cost.frontFullResponseCalls = frontOutput.fullEvaluations;
result.cost.profileResponseCalls = profileCalls(profile);
result.cost.responseContextBytes = responseContextBytes(cfg, carrierCount);
end

function [carrierCount, subarraySize] = methodDimensions(method, protocol)
if method == "C_public"
    carrierCount = protocol.publicC.carrierCount;
    subarraySize = protocol.publicC.subarraySize;
else
    carrierCount = protocol.music.carrierCount;
    subarraySize = protocol.music.subarraySize;
end
end

function [thetaDeg, rangeM] = outputLocation(method, estimate, profile, front)
thetaDeg = estimate.thetaDeg;
if method == "P_A"
    rangeM = profile.value;
elseif method == "H_A"
    rangeM = front.rangeM;
else
    rangeM = estimate.rangeM;
end
end

function version = variantVersion(useFastResponse, useGram)
if useFastResponse && useGram
    version = "R33-AB-combined-equivalent-fast-v1";
elseif useFastResponse
    version = "R33-A-q-only-invariants-direct-EVD-v1";
elseif useGram
    version = "R33-B-reference-response-Gram-subspace-v1";
else
    version = "R33-invariant-direct-EVD-reference-response-v1";
end
end

function count = profileCalls(profile)
count = 0;
if isfield(profile, "evaluationCount")
    count = profile.evaluationCount;
end
end

function bytes = responseContextBytes(cfg, carrierCount)
complexBytes = 16;
realBytes = 8;
bytes = complexBytes*cfg.numAntennas*cfg.numSubcarriers ...
    + complexBytes*cfg.numSubcarriers ...
    + realBytes*(2*cfg.numAntennas+cfg.numSubcarriers) ...
    + complexBytes*cfg.numAntennas*carrierCount;
end
