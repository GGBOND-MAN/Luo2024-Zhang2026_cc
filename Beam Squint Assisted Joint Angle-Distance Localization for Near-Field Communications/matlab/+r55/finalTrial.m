function result = finalTrial(cfg, scan, row, rowIndex, protocol)
%FINALTRIAL Execute one lean frozen R55 accuracy row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r55.config()
end

result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.r53.base.r34);
    backend = r53.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol.r53);
    paProxy = struct(thetaDeg=shared.P_A.thetaDeg, ...
        rangeM=shared.P_A.rangeM, estimate=shared.P_A.estimate, ...
        front=shared.front);
    g = r41.gFromPA(cfg, scan, replay, paProxy, protocol.r53.base.r41);

    result.success = true;
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.P_FA = backend.P_FA;
    result.P_FALF = backend.P_FALF;
    result.G_schur = location(g.angle.thetaDeg, g.transport.rangeM);
    result.C_enhanced = location( ...
        shared.C_enhanced.thetaDeg, shared.C_enhanced.rangeM);
    result.angleIdentityDifferenceDeg = ...
        abs(result.P_FALF.thetaDeg-result.P_FA.thetaDeg);
    result.rangeShiftM = result.P_FALF.rangeM-result.P_FA.rangeM;
    result.runtime = struct(pfaBackendSeconds=backend.pfa.backendSeconds, ...
        jointProfileSeconds=backend.jointProfile.runtimeSeconds, ...
        r53BackendSeconds=backend.backendSeconds);
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

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end
