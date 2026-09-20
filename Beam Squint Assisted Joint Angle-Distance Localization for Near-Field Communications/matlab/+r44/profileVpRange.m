function result = profileVpRange( ...
    cfg, context, thetaDeg, centerRangeM, protocol)
%PROFILEVPRANGE Phase-invariant full-aperture fixed-angle range profile.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r44.config()
end

timer = tic;
bounds = [max(cfg.rangeLimitsM(1), ...
    centerRangeM-protocol.profile.halfWidthM), ...
    min(cfg.rangeLimitsM(2), centerRangeM+protocol.profile.halfWidthM)];
intervals = max(protocol.profile.minimumIntervals, ...
    ceil(diff(bounds)/protocol.profile.coarseSpacingM));
score = @(rangeM) scoreValues(rangeM);
result = r31.maximizeScore1D(score, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=protocol.profile.peakCount, ...
    TolX=protocol.profile.tolXM, ...
    ScoreTolerance=protocol.profile.scoreTolerance);
result.version = "R44-full-array-phase-invariant-range-v1";
result.runtimeSeconds = toc(timer);

    function values = scoreValues(rangeValues)
        values = zeros(size(rangeValues));
        for valueIndex = 1:numel(rangeValues)
            values(valueIndex) = r38RawArrayVpmlScore( ...
                cfg, context, thetaDeg, rangeValues(valueIndex));
        end
    end
end
