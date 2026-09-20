function result = profileAtAngle(cfg, observation, scan, ...
    thetaDeg, centerRangeM, protocol)
%PROFILEATANGLE Run the frozen full-spectrum conditional complex profile.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r32.config()
end

bounds = [max(cfg.rangeLimitsM(1), ...
    centerRangeM-protocol.profile.halfWidthM), ...
    min(cfg.rangeLimitsM(2), centerRangeM+protocol.profile.halfWidthM)];
intervals = max(protocol.profile.minimumIntervals, ...
    ceil(diff(bounds)/protocol.profile.coarseSpacingM));
score = @(rangeM) fsjad.fixedAngleProfileLogScore( ...
    cfg, observation, thetaDeg, rangeM, scan);
result = r31.maximizeScore1D(score, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=protocol.profile.peakCount, ...
    TolX=protocol.profile.tolXM, ...
    ScoreTolerance=protocol.profile.scoreTolerance);
result.version = "R32-frozen-full-spectrum-profile-v1";
result.lambda = protocol.profile.lambda;
result.coarseSpacingM = protocol.profile.coarseSpacingM;
result.peakCount = protocol.profile.peakCount;
end
