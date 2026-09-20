function result = estimatePA(cfg, observation, snapshots, scan, protocol)
%ESTIMATEPA Independent online P_A estimator from current z/Y only.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    protocol (1, 1) struct = r32.config()
end

r32.assertFrozenConfig(cfg, protocol);
validateInputs(cfg, observation, snapshots);
totalTimer = tic;
frontProtocol = r30.config();
frontProtocol.frontVersion = protocol.front.version;
frontProtocol.angleOffsetsDeg = protocol.front.angleOffsetsDeg;
candidate = r32.candidate(protocol);
frontOutput = r30.front(cfg, observation, scan, frontProtocol, candidate);
front = frontOutput.selected;

carrierIndex = r30.selectLocalCarriers(cfg.numSubcarriers, ...
    protocol.music.carrierCount, frontOutput.peakCarrierIndex);
[state, musicCfg, stateCost] = r30.prepareMusicState(cfg, ...
    snapshots(:, carrierIndex+1), carrierIndex, ...
    front.thetaDeg, front.rangeM, protocol.music.subarraySize);

angleTimer = tic;
angle = r31.stagedAngleMusic(musicCfg, state, front.thetaDeg, ...
    front.rangeM, protocol.music.angleHalfWidthDeg, ...
    protocol.music.gridSizes);
angleSeconds = toc(angleTimer);
profileTimer = tic;
profile = r32.profileAtAngle(cfg, observation, scan, ...
    angle.thetaDeg, front.rangeM, protocol);
profileSeconds = toc(profileTimer);

result.version = protocol.methodVersion;
result.inputContract = "current-z-current-Y-scan-known-config-only";
result.front = frontOutput;
result.state = state;
result.musicCfg = musicCfg;
result.angle = angle;
result.profile = profile;
result.H_A = struct(thetaDeg=angle.thetaDeg, rangeM=front.rangeM, ...
    version="HA-independent-online-R32-v1");
result.P_A = struct(thetaDeg=angle.thetaDeg, rangeM=profile.value, ...
    version=protocol.methodVersion, lambda=protocol.profile.lambda);
result.carrierIndex = carrierIndex;
result.cost = costRecord(frontOutput, stateCost, angleSeconds, ...
    profileSeconds, angle.evaluationCount, profile.evaluationCount);
result.cost.totalOnlineSeconds = toc(totalTimer);
end

function validateInputs(cfg, observation, snapshots)
if numel(observation) ~= cfg.numSubcarriers ...
        || size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= cfg.numSubcarriers
    error("r32:OnlineInputSize", ...
        "P_A requires a full z vector and the full N-by-M Y array.");
end
end

function cost = costRecord(front, state, angleSeconds, profileSeconds, ...
    angleEvaluations, profileEvaluations)
cost.frontSeconds = front.runtimeSeconds;
cost.stateSeconds = state.seconds;
cost.angleSeconds = angleSeconds;
cost.profileSeconds = profileSeconds;
cost.frontEquivalentResponses = front.fullEquivalentResponses;
cost.profileResponses = profileEvaluations;
cost.phaseAlignmentTerms = state.phaseAlignmentTerms;
cost.covarianceMacs = state.covarianceMacs;
cost.evdCubicUnits = state.evdCubicUnits;
cost.angleProjectionMacs = state.carrierCount ...
    *state.subarraySize*angleEvaluations;
cost.searchEvaluations = angleEvaluations;
end
