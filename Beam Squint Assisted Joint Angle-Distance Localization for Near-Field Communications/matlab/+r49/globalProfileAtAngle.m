function result = globalProfileAtAngle( ...
    cfg, thetaDeg, responseContext, feasibleRangeM, protocol)
%GLOBALPROFILEATANGLE Search the full physical q-profile range support.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    responseContext (1, 1) struct
    feasibleRangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r49.config()
end

score = @(rangeM) r33.fixedAngleProfileLogScore( ...
    cfg, thetaDeg, rangeM, responseContext);
result = r31.maximizeScore1D(score, cfg.rangeLimitsM(:).', ...
    feasibleRangeM, Intervals=protocol.range.intervalCount, ...
    PeakCount=protocol.range.peakCount, TolX=protocol.range.tolXM, ...
    ScoreTolerance=protocol.range.scoreTolerance);
result.version = "R49-full-physical-q-profile-v1";
result.qOnlyResponseEvaluations = result.evaluationCount;
end
