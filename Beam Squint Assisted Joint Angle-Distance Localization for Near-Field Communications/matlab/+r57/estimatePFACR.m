function result = estimatePFACR(cfg, observation, snapshots, scan, protocol)
%ESTIMATEPFACR Standalone PA-free P_FACR estimator from current z and Y.
%   This is the deployable method: the frozen L06 front, the frozen P_FA
%   angle, and one coherent range profile. The ablation branches are
%   reporting-only and are not executed here, matching the R53 convention
%   that excluded the Y-only diagnostic profile from its matched timing.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    protocol (1, 1) struct = r57.config()
end

if numel(observation) ~= cfg.numSubcarriers ...
        || size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= cfg.numSubcarriers
    error("r57:OnlineInputSize", ...
        "P_FACR requires a full z vector and the full N-by-M Y array.");
end
timer = tic;
front = r33.front(cfg, observation, scan, protocol.base.base.r34.r32, ...
    r32.candidate(protocol.base.base.r34.r32));
backend = r57.fromFront(cfg, observation, snapshots, scan, front, ...
    protocol, Branches="P_FACR");
result = backend;
result.front = front;
result.thetaDeg = backend.P_FACR.thetaDeg;
result.rangeM = backend.P_FACR.rangeM;
result.totalOnlineSeconds = toc(timer);
result.inputContract = "current-z-current-Y-scan-known-config-only";
end
