function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R49 development row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r49.config()
end

result = failureResult(row, rowIndex);
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.r48.r47.r45.r34);
    backend = r49.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol);
    result.success = true;
    result.methodNames = ["P_FA", "P_FAM5", ...
        protocol.method.candidates, "P_A", "C_enhanced"];
    result.P_FA = backend.P_FA;
    result.P_FAM5 = backend.P_FAM5;
    for candidate = protocol.method.candidates
        result.(candidate) = location(backend.candidates.(candidate));
    end
    result.P_A = location(shared.P_A);
    result.C_enhanced = location(shared.C_enhanced);
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

function output = location(input)
output = struct(thetaDeg=input.thetaDeg, rangeM=input.rangeM);
end

function result = failureResult(row, rowIndex)
result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
end
