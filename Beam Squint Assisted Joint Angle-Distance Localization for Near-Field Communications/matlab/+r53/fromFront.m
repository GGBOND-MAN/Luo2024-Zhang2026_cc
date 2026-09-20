function result = fromFront(cfg, observation, snapshots, scan, front, protocol)
%FROMFRONT Run frozen P_FA followed by the sole R53 joint range profile.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct
    front (1, 1) struct
    protocol (1, 1) struct = r53.config()
end

timer = tic;
pfa = r45.fromFront(cfg, observation, snapshots, scan, front, protocol.base);
context = r42.prepareContext(cfg, scan, observation, ...
    snapshots(:, pfa.carrierIndex+1), pfa.carrierIndex);
joint = r53.profileRange(cfg, context, pfa.thetaDeg, ...
    front.selected.rangeM, "joint", protocol);
result = struct(version=protocol.version, P_FA=location( ...
    pfa.thetaDeg, pfa.rangeM), P_FALF=location(pfa.thetaDeg, joint.value), ...
    pfa=pfa, jointProfile=joint, context=context, ...
    angleIdentityDifferenceDeg=0, backendSeconds=toc(timer));
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end
