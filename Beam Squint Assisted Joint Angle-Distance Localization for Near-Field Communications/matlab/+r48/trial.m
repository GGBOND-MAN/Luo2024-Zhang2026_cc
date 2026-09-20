function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one shared-accuracy R48 row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r48.config()
end

result = struct(success=false, rowIndex=rowIndex, positionId=row.positionId, ...
    seed=row.seed, snrDb=row.snrDb, truthThetaDeg=row.truthThetaDeg, ...
    truthRangeM=row.truthRangeM, errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.r47.r45.r34);
    paProxy = struct(thetaDeg=shared.P_A.thetaDeg, ...
        rangeM=shared.P_A.rangeM, estimate=shared.P_A.estimate, ...
        front=shared.front);
    g = r41.gFromPA(cfg, scan, replay, paProxy, ...
        protocol.r47.r45.r41);
    b = r48.backend(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol);
    result.success = true;
    result.P_FAM5 = location(b.thetaDeg, b.marginalRangeM);
    result.P_FA = location(b.thetaDeg, b.hardRangeM);
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.G_schur = location(g.angle.thetaDeg, g.transport.rangeM);
    result.C_enhanced = location( ...
        shared.C_enhanced.thetaDeg, shared.C_enhanced.rangeM);
    result.backend = b;
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
