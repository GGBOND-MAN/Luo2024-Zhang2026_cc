function result = fromFront( ...
    cfg, observation, snapshots, scan, front, protocol)
%FROMFRONT Run frozen R51 references and primary R52 from one L06 front.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct
    front (1, 1) struct
    protocol (1, 1) struct = r52.config()
end

timer = tic;
frozenR51 = r51.fromFront(cfg, observation, snapshots, ...
    scan, front, protocol.r51);
certificate = r52.basinCertificate(front, frozenR51, protocol);
base = frozenR51.P_FA;
oldSimple = frozenR51.unconditional_wide_global;
oldTrigger = frozenR51.certificate.trigger;

recovery = fallbackRecovery(base);
if certificate.trigger
    if oldTrigger
        recovery = struct(version="R52-reused-R51-simple-control-v1", ...
            valid=true, accepted=true, status="accepted-reused-wide-global", ...
            thetaDeg=oldSimple.thetaDeg, rangeM=oldSimple.rangeM, ...
            angle=struct(), profile=struct(), runtimeSeconds=0, ...
            errorIdentifier="", errorMessage="");
    else
        recovery = r52.simpleRecovery(cfg, observation, snapshots, ...
            scan, front, base, protocol);
    end
end
primary = location(recovery.thetaDeg, recovery.rangeM);
if ~certificate.trigger
    primary = base;
end
result = struct(version=protocol.version, P_FA=base, ...
    R51_PFARC=frozenR51.P_FARC, ...
    R51_trigger_simple=oldSimple, P_FARC2=primary, ...
    frontThetaDeg=front.selected.thetaDeg, ...
    frontRangeM=front.selected.rangeM, ...
    frozenR51=frozenR51, certificate=certificate, recovery=recovery, ...
    backendSeconds=toc(timer), musicEvaluationCount=0, evdCount=0);
end

function output = fallbackRecovery(base)
output = struct(version="R52-simple-conditional-wide-global-v1", ...
    valid=true, accepted=false, status="not-triggered", ...
    thetaDeg=base.thetaDeg, rangeM=base.rangeM, ...
    angle=struct(), profile=struct(), runtimeSeconds=0, ...
    errorIdentifier="", errorMessage="");
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end
