function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R52 normal or natural-stress row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r52.config()
end

result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.base.r34);
    backend = r52.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol);
    angleSupportMiss = abs(row.truthThetaDeg-backend.frontThetaDeg) ...
        > protocol.support.angleHalfWidthDeg;
    rangeSupportMiss = abs(row.truthRangeM-backend.frontRangeM) ...
        > protocol.support.rangeHalfWidthM;
    supportClass = classifySupport(angleSupportMiss, rangeSupportMiss);
    oldCertificate = backend.frozenR51.certificate;
    stableInterior = (angleSupportMiss || rangeSupportMiss) ...
        && ~oldCertificate.C1 && ~oldCertificate.C2 ...
        && ~oldCertificate.C3 && ~oldCertificate.C4;

    result.success = true;
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.C_enhanced = location( ...
        shared.C_enhanced.thetaDeg, shared.C_enhanced.rangeM);
    result.P_FA = backend.P_FA;
    result.R51_PFARC = backend.R51_PFARC;
    result.R51_trigger_simple = backend.R51_trigger_simple;
    result.P_FARC2 = backend.P_FARC2;
    result.angleSupportMiss = angleSupportMiss;
    result.rangeSupportMiss = rangeSupportMiss;
    result.supportClass = supportClass;
    result.stableInteriorSupportMiss = stableInterior;
    result.backend = backend;
    result.sharedAudit = struct(totalDirectEvdCount= ...
        shared.solverAudit.totalDirectCount, totalGramCount= ...
        shared.solverAudit.totalGramCount, totalFallbackCount= ...
        shared.solverAudit.totalFallbackCount);
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function output = classifySupport(angleMiss, rangeMiss)
output = "none";
if angleMiss && rangeMiss
    output = "joint";
elseif angleMiss
    output = "angle";
elseif rangeMiss
    output = "range";
end
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end
