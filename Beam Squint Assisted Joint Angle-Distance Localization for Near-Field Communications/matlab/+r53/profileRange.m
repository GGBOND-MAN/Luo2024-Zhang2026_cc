function result = profileRange(cfg, context, thetaDeg, centerRangeM, branch, protocol)
%PROFILERANGE Run the frozen P_A local search with an R53 likelihood branch.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    branch (1, 1) string {mustBeMember(branch, ["Y", "joint"])}
    protocol (1, 1) struct = r53.config()
end

timer = tic;
bounds = [max(cfg.rangeLimitsM(1), ...
    centerRangeM-protocol.profile.halfWidthM), ...
    min(cfg.rangeLimitsM(2), centerRangeM+protocol.profile.halfWidthM)];
intervals = max(protocol.profile.minimumIntervals, ...
    ceil(diff(bounds)/protocol.profile.coarseSpacingM));
score = @(rangeValues) scoreValues(rangeValues);
result = r31.maximizeScore1D(score, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=protocol.profile.peakCount, ...
    TolX=protocol.profile.tolXM, ...
    ScoreTolerance=protocol.profile.scoreTolerance);
result.version = "R53-"+branch+"-range-profile-v1";
result.branch = branch;
result.runtimeSeconds = toc(timer);

    function values = scoreValues(rangeValues)
        values = zeros(size(rangeValues));
        for valueIndex = 1:numel(rangeValues)
            state = r53.likelihoodState( ...
                cfg, context, thetaDeg, rangeValues(valueIndex), protocol);
            if branch == "Y"
                values(valueIndex) = state.scoreY;
            else
                values(valueIndex) = state.scoreJoint;
            end
        end
    end
end
