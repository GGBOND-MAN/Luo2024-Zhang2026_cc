function result = profileAtAngle( ...
    cfg, observation, scan, thetaDeg, centerRangeM, protocol)
%PROFILEATANGLE Preserve the frozen R32 profile with q-only scoring.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r33.config()
end

r32Protocol = protocol.r32;
bounds = [max(cfg.rangeLimitsM(1), ...
    centerRangeM-r32Protocol.profile.halfWidthM), ...
    min(cfg.rangeLimitsM(2), ...
    centerRangeM+r32Protocol.profile.halfWidthM)];
intervals = max(r32Protocol.profile.minimumIntervals, ...
    ceil(diff(bounds)/r32Protocol.profile.coarseSpacingM));
context = r33.prepareResponseContext(cfg, scan, observation);
score = @(rangeM) r33.fixedAngleProfileLogScore( ...
    cfg, thetaDeg, rangeM, context);
result = r31.maximizeScore1D(score, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=r32Protocol.profile.peakCount, ...
    TolX=r32Protocol.profile.tolXM, ...
    ScoreTolerance=r32Protocol.profile.scoreTolerance);
result.version = "R33-q-only-frozen-full-spectrum-profile-v1";
result.lambda = r32Protocol.profile.lambda;
result.coarseSpacingM = r32Protocol.profile.coarseSpacingM;
result.peakCount = r32Protocol.profile.peakCount;
result.qOnlyResponseEvaluations = result.evaluationCount;
end
