function result = repairL06Trial(cfg, scan, row, replay, inputHash, ...
    oldItem, protocol)
%REPAIRL06TRIAL Reuse the L06 front/subspace and repair scalar candidate logic.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    replay (1, 1) struct
    inputHash (1, 1) struct
    oldItem (1, 1) struct
    protocol (1, 1) struct
end

result = struct(success=false, errorIdentifier="", errorMessage="", ...
    seed=row.seed, snrDb=row.snrDb, version="R31-L06-scalar-repair-v2");
timer = tic;
try
    front = oldItem.front.selected;
    musicCfg = cfg;
    musicCfg.subarraySize = oldItem.musicState.subarraySize;
    musicCfg.numSubarrays = cfg.numAntennas-musicCfg.subarraySize+1;
    angleBounds = oldItem.angleSolver.interval;
    angleScore = @(thetaDeg) jad.localMusicLogScore( ...
        musicCfg, oldItem.musicState, thetaDeg, front.rangeM);
    angleTimer = tic;
    angle = r31.maximizeScore1D(angleScore, angleBounds, front.thetaDeg, ...
        Intervals=numel(oldItem.angleSolver.grid)-1, PeakCount=4, ...
        TolX=protocol.angleToleranceDeg, ...
        ScoreTolerance=protocol.scoreTolerance);
    angleSeconds = toc(angleTimer);
    profileTimer = tic;
    profile = r31.profileAtAngle(cfg, replay.observation, scan, ...
        angle.value, front.rangeM, protocol);
    profileSeconds = toc(profileTimer);

    result.oldThetaDeg = oldItem.thetaDeg(2);
    result.oldRangeM = oldItem.rangeM(3);
    result.newThetaDeg = angle.value;
    result.newRangeM = profile.value;
    result.angleSolver = angle;
    result.profileSolver = profile;
    result.hash = inputHash;
    result.angleSeconds = angleSeconds;
    result.profileSeconds = profileSeconds;
    result.frontRecomputed = false;
    result.subspaceRecomputed = false;
    result.profileRecomputedAtNewAngle = true;
    result.success = all(isfinite([result.newThetaDeg, result.newRangeM]));
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
result.experimentSessionSeconds = toc(timer);
end
