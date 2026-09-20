function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one shared-accuracy R45 calibration row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r45.config()
end

result = failureResult(row, rowIndex);
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.r34);
    paProxy = struct(thetaDeg=shared.P_A.thetaDeg, ...
        rangeM=shared.P_A.rangeM, estimate=shared.P_A.estimate, ...
        front=shared.front);
    g = r41.gFromPA(cfg, scan, replay, paProxy, protocol.r41);
    pfa = r45.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol);
    pa = locationRecord(shared.P_A.thetaDeg, shared.P_A.rangeM);
    c = locationRecord(shared.C_enhanced.thetaDeg, ...
        shared.C_enhanced.rangeM);
    gRecord = locationRecord(g.angle.thetaDeg, g.transport.rangeM);
    pfaRecord = locationRecord(pfa.thetaDeg, pfa.rangeM);
    result.success = true;
    result.runtimeOrder = "shared-accuracy-no-complete-runtime-claim";
    result.methodNames = ["P_FA", "P_A", "G_schur", "C_enhanced"];
    result.thetaDeg = [pfaRecord.thetaDeg, pa.thetaDeg, ...
        gRecord.thetaDeg, c.thetaDeg];
    result.rangeM = [pfaRecord.rangeM, pa.rangeM, ...
        gRecord.rangeM, c.rangeM];
    result.P_FA = pfaRecord;
    result.P_A = pa;
    result.G_schur = gRecord;
    result.C_enhanced = c;
    result.frontThetaDeg = shared.front.selected.thetaDeg;
    result.frontRangeM = shared.front.selected.rangeM;
    result.pfaDiagnostics = struct(angle=pfa.angle, ...
        profile=pfa.profile, carrierIndex=pfa.carrierIndex, ...
        backendSeconds=pfa.backendSeconds, ...
        fullArrayEvaluationCount=pfa.fullArrayEvaluationCount, ...
        profileEvaluationCount=pfa.profileEvaluationCount);
    result.gDiagnostics = struct(angle=g.angle, transport=g.transport);
    result.sharedAudit = struct(version=shared.finalSharedVersion, ...
        totalDirectEvdCount=shared.solverAudit.totalDirectCount, ...
        totalGramCount=shared.solverAudit.totalGramCount, ...
        totalFallbackCount=shared.solverAudit.totalFallbackCount);
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function output = locationRecord(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end

function result = failureResult(row, rowIndex)
result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
end
