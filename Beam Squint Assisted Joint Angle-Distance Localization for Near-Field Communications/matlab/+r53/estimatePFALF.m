function result = estimatePFALF(cfg, observation, snapshots, scan, protocol)
%ESTIMATEPFALF Standalone PA-free P_FALF estimator from current z and Y.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    protocol (1, 1) struct = r53.config()
end

if numel(observation) ~= cfg.numSubcarriers ...
        || size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= cfg.numSubcarriers
    error("r53:OnlineInputSize", ...
        "P_FALF requires a full z vector and the full N-by-M Y array.");
end
timer = tic;
front = r33.front(cfg, observation, scan, protocol.base.r34.r32, ...
    r32.candidate(protocol.base.r34.r32));
backend = r53.fromFront(cfg, observation, snapshots, scan, front, protocol);
result = backend;
result.front = front;
result.thetaDeg = backend.P_FALF.thetaDeg;
result.rangeM = backend.P_FALF.rangeM;
result.totalOnlineSeconds = toc(timer);
result.inputContract = "current-z-current-Y-scan-known-config-only";
end
