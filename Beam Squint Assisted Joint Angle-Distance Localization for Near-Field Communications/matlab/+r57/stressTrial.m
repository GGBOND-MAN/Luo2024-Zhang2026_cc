function result = stressTrial(cfg, scan, row, rowIndex, protocol)
%STRESSTRIAL One delay-stress row. MODIFIED DATA PATH, never a primary row.

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
    mode=row.mode, levelIndex=row.levelIndex, ...
    sigmaTauSeconds=row.sigmaTauSeconds, tauSeconds=0, ...
    errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    tauStream = RandStream("mt19937ar", Seed=row.tauSeed);
    tauSeconds = double(row.sigmaTauSeconds)*randn(tauStream);
    injected = r57.injectDelay(cfg, replay.observation, replay.snapshots, ...
        tauSeconds, string(row.mode));
    shared = r34.sharedPerformanceSet(cfg, injected.observation, ...
        injected.snapshots, scan, protocol.base.base.r34);
    backend = r57.fromFront(cfg, injected.observation, injected.snapshots, ...
        scan, shared.front, protocol, Branches="P_FACR");
    if backend.P_FACR.thetaDeg ~= backend.P_FA.thetaDeg
        error("r57:StressAngleIdentity", ...
            "The stress branch must preserve the frozen P_FA angle.");
    end
    bound = r57.crlb(cfg, backend.context, backend.P_FA.thetaDeg, ...
        double(row.truthRangeM), double(row.snrDb), ...
        double(row.sigmaTauSeconds));

    result.success = true;
    result.tauSeconds = tauSeconds;
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.P_FA = backend.P_FA;
    result.P_FALF = backend.P_FALF;
    result.P_FACR = backend.P_FACR;
    result.crlbCoherentStdM = double(bound.coherentStdM);
    result.crlbFreeAlphaStdM = double(bound.freeAlphaStdM);
    result.crlbHybridStdM = double(bound.hybridStdM);
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
