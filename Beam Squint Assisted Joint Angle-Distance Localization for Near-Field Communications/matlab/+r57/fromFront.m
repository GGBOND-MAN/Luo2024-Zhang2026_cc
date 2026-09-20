function result = fromFront(cfg, observation, snapshots, scan, front, protocol)
%FROMFRONT Run frozen P_FA and P_FALF, then every R57 coherent range branch.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct
    front (1, 1) struct
    protocol (1, 1) struct = r57.config()
end

timer = tic;
base = r53.fromFront(cfg, observation, snapshots, scan, front, protocol.base);
thetaDeg = base.P_FA.thetaDeg;
phaseBasis = r57.basis(base.context, protocol);

branches = ["P_FACR", "P_FACR_A", "P_FACR_D", "P_FACR_T", "P_FACR_Yonly"];
profiles = struct();
result = struct(version=protocol.version, ...
    P_FA=base.P_FA, P_FALF=base.P_FALF);
for branch = branches
    profiles.(branch) = r57.profileRange(cfg, base.context, phaseBasis, ...
        thetaDeg, front.selected.rangeM, branch, protocol);
    result.(branch) = struct(thetaDeg=thetaDeg, ...
        rangeM=profiles.(branch).value);
end

% Every R57 branch must return the frozen P_FA angle exactly.
for branch = ["P_FALF", branches]
    if result.(branch).thetaDeg ~= thetaDeg
        error("r57:AngleIdentity", ...
            "Branch %s did not preserve the frozen P_FA angle.", branch);
    end
end

result.base = base;
result.context = base.context;
result.phaseBasis = phaseBasis;
result.profiles = profiles;
result.angleIdentityDifferenceDeg = 0;
result.backendSeconds = toc(timer);
end
