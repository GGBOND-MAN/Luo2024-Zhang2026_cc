function result = profileRange(cfg, context, observation, scan, ...
    thetaDeg, centerRangeM, mode, protocol)
%PROFILERANGE Optimize a frozen coherent fixed-angle range score.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    mode (1, 1) string {mustBeMember(mode, ["Y", "ZY"])}
    protocol (1, 1) struct = r43.config()
end

timer = tic;
bounds = [max(cfg.rangeLimitsM(1), ...
    centerRangeM-protocol.profile.halfWidthM), ...
    min(cfg.rangeLimitsM(2), centerRangeM+protocol.profile.halfWidthM)];
intervals = max(protocol.profile.minimumIntervals, ...
    ceil(diff(bounds)/protocol.profile.coarseSpacingM));
score = @(rangeM) scoreValues(rangeM, mode);
result = r31.maximizeScore1D(score, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=protocol.profile.peakCount, ...
    TolX=protocol.profile.tolXM, ...
    ScoreTolerance=protocol.profile.scoreTolerance);
result.version = "R43-"+mode+"-coherent-range-profile-v1";
result.mode = mode;
result.runtimeSeconds = toc(timer);

    function values = scoreValues(rangeValues, selectedMode)
        values = zeros(size(rangeValues));
        for valueIndex = 1:numel(rangeValues)
            currentRange = rangeValues(valueIndex);
            yScore = r43.coherentArrayScore( ...
                cfg, context, thetaDeg, currentRange);
            if selectedMode == "Y"
                values(valueIndex) = yScore;
            else
                q = fsjad.exactSpectralResponse( ...
                    cfg, deg2rad(thetaDeg), currentRange, scan);
                zScore = fsjad.profileScore(q, observation);
                floorValue = protocol.coherent.scoreFloor;
                values(valueIndex) = -0.5*( ...
                    log(max(1-zScore, floorValue)) ...
                    +log(max(1-yScore, floorValue)));
            end
        end
    end
end
