function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R47 development row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r47.config()
end

result = failureResult(row, rowIndex);
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.r45.r34);
    paProxy = struct(thetaDeg=shared.P_A.thetaDeg, ...
        rangeM=shared.P_A.rangeM, estimate=shared.P_A.estimate, ...
        front=shared.front);
    g = r41.gFromPA(cfg, scan, replay, paProxy, ...
        protocol.r45.r41);
    backend = r47.fromFront(cfg, replay.observation, ...
        replay.snapshots, scan, shared.front, protocol);
    result.success = true;
    result.methodNames = ["P_FA", "P_FAM3", "P_FAM5", ...
        "P_A", "G_schur", "C_enhanced"];
    result.P_FA = location(backend.thetaDeg, backend.hardRangeM);
    result.P_FAM3 = location(backend.thetaDeg, backend.marginal3RangeM);
    result.P_FAM5 = location(backend.thetaDeg, backend.marginal5RangeM);
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.G_schur = location(g.angle.thetaDeg, g.transport.rangeM);
    result.C_enhanced = location( ...
        shared.C_enhanced.thetaDeg, shared.C_enhanced.rangeM);
    result.backend = backend;
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

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end

function result = failureResult(row, rowIndex)
result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
end
