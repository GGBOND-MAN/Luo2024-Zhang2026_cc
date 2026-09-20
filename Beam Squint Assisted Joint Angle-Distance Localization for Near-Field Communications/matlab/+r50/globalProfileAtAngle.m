function result = globalProfileAtAngle( ...
    cfg, thetaDeg, responseContext, feasibleRangeM, protocol)
%GLOBALPROFILEATANGLE Search the full physical q-only distance support.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    responseContext (1, 1) struct
    feasibleRangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r50.config()
end

score = @(rangeM) r33.fixedAngleProfileLogScore( ...
    cfg, thetaDeg, rangeM, responseContext);
result = r31.maximizeScore1D(score, cfg.rangeLimitsM(:).', ...
    feasibleRangeM, Intervals=protocol.globalProfile.intervalCount, ...
    PeakCount=protocol.globalProfile.peakCount, ...
    TolX=protocol.globalProfile.tolXM, ...
    ScoreTolerance=protocol.globalProfile.scoreTolerance);
result.version = "R50-oracle-global-q-profile-v1";
end
