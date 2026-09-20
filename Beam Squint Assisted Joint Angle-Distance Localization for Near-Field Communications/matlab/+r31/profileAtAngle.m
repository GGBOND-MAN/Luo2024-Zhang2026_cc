function result = profileAtAngle(cfg, observation, scan, ...
    thetaDeg, centerRangeM, protocol)
%PROFILEATANGLE Recompute the conditional profile at the supplied angle.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct
end

bounds = [max(cfg.rangeLimitsM(1), ...
    centerRangeM-protocol.profileHalfWidthM), ...
    min(cfg.rangeLimitsM(2), centerRangeM+protocol.profileHalfWidthM)];
score = @(rangeM) fsjad.fixedAngleProfileLogScore( ...
    cfg, observation, thetaDeg, rangeM, scan);
intervals = max(40, ceil(diff(bounds)/0.05));
result = r31.maximizeScore1D(score, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=8, ...
    TolX=protocol.profileToleranceM, ...
    ScoreTolerance=protocol.scoreTolerance);
end
