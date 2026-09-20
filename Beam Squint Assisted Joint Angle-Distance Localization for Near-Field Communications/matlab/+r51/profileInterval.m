function result = profileInterval( ...
    cfg, thetaDeg, context, interval, feasibleRangeM, protocol)
%PROFILEINTERVAL Maximize the frozen exact q score on one fixed interval.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    context (1, 1) struct
    interval (1, 2) double {mustBeFinite}
    feasibleRangeM (:, 1) double {mustBeFinite} = zeros(0, 1)
    protocol (1, 1) struct = r51.config()
end

width = diff(interval);
if width <= 0
    error("r51:InvalidProfileInterval", ...
        "A recovery profile interval must have positive width.");
end
intervals = max(1, ceil(width/protocol.recovery.rangeCoarseSpacingM));
score = @(rangeM) r33.fixedAngleProfileLogScore( ...
    cfg, thetaDeg, rangeM, context);
result = r31.maximizeScore1D(score, interval, feasibleRangeM, ...
    Intervals=intervals, PeakCount=protocol.recovery.peakCount, ...
    TolX=protocol.recovery.tolXM, ...
    ScoreTolerance=protocol.recovery.scoreTolerance);
result.version = "R51-fixed-interval-exact-q-profile-v1";
result.thetaDeg = thetaDeg;
result.coarseSpacingM = protocol.recovery.rangeCoarseSpacingM;
end
