function result = estimatePFARC2( ...
    cfg, observation, snapshots, scan, protocol)
%ESTIMATEPFARC2 Independent online R52 estimator from current z/Y only.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    protocol (1, 1) struct = r52.config()
end

if numel(observation) ~= cfg.numSubcarriers ...
        || size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= cfg.numSubcarriers
    error("r52:OnlineInputSize", ...
        "P_FARC2 requires full z and N-by-M Y observations.");
end
timer = tic;
front = r33.front(cfg, observation, scan, protocol.base.r34.r32, ...
    r32.candidate(protocol.base.r34.r32));
backend = r52.fromFront( ...
    cfg, observation, snapshots, scan, front, protocol);
result = backend;
result.front = front;
result.thetaDeg = backend.P_FARC2.thetaDeg;
result.rangeM = backend.P_FARC2.rangeM;
result.totalOnlineSeconds = toc(timer);
result.inputContract = "current-z-current-Y-scan-known-config-only";
end
