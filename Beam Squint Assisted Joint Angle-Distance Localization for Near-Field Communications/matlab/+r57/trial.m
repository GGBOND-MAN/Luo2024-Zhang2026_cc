function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R57 row. The data path is unchanged from R53/R56.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r57.config()
end

result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.base.base.r34);
    backend = r57.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol);
    methods = ["P_FA", "P_FALF", "P_FACR", "P_FACR_A", ...
        "P_FACR_D", "P_FACR_T", "P_FACR_Yonly"];
    for method = methods
        if backend.(method).thetaDeg ~= backend.P_FA.thetaDeg
            error("r57:AngleIdentity", ...
                "Every R57 method must preserve the frozen P_FA angle.");
        end
    end
    bound = r57.crlb(cfg, backend.context, backend.P_FA.thetaDeg, ...
        double(row.truthRangeM), double(row.snrDb));

    result.success = true;
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.C_enhanced = location( ...
        shared.C_enhanced.thetaDeg, shared.C_enhanced.rangeM);
    for method = methods
        result.(method) = backend.(method);
    end
    result.frontThetaDeg = double(shared.front.selected.thetaDeg);
    result.frontRangeM = double(shared.front.selected.rangeM);
    result.angleIdentityDifferenceDeg = 0;
    result.crlbCoherentStdM = double(bound.coherentStdM);
    result.crlbFreeAlphaStdM = double(bound.freeAlphaStdM);
    result.crlbGainFactor = double(bound.gainFactor);
    result.coarseSpacingM = double(backend.profiles.P_FACR.coarseSpacingM);
    result.backendSeconds = double(backend.backendSeconds);
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=double(thetaDeg), rangeM=double(rangeM));
end
