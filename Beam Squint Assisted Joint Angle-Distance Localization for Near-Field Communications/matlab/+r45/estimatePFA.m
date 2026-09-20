function result = estimatePFA(cfg, observation, snapshots, scan, protocol)
%ESTIMATEPFA Independent online P_FA estimator from current z/Y only.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    protocol (1, 1) struct = r45.config()
end

if numel(observation) ~= cfg.numSubcarriers ...
        || size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= cfg.numSubcarriers
    error("r45:OnlineInputSize", ...
        "P_FA requires a full z vector and the full N-by-M Y array.");
end
totalTimer = tic;
front = r33.front(cfg, observation, scan, protocol.r34.r32, ...
    r32.candidate(protocol.r34.r32));
backend = r45.fromFront( ...
    cfg, observation, snapshots, scan, front, protocol);
result = backend;
result.inputContract = "current-z-current-Y-scan-known-config-only";
result.front = front;
result.frontSeconds = front.runtimeSeconds;
result.totalOnlineSeconds = toc(totalTimer);
result.responseEquivalentCount = front.fullEquivalentResponses ...
    +backend.fullArrayEvaluationCount+backend.profileEvaluationCount;
end
