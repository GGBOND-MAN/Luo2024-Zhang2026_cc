function result = profileRange(cfg, context, phaseBasis, thetaDeg, ...
    centerRangeM, branch, protocol)
%PROFILERANGE Maximize one R57 branch over the frozen local range support.
%   The coarse spacing is c/(4B), four samples per delay mainlobe c/B. It is
%   fixed by the sampling theorem and is never retuned from any outcome.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    phaseBasis (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    branch (1, 1) string {mustBeMember(branch, ["P_FALF", "P_FACR", ...
        "P_FACR_A", "P_FACR_D", "P_FACR_T", "P_FACR_Yonly"])}
    protocol (1, 1) struct = r57.config()
end

timer = tic;
bounds = [max(cfg.rangeLimitsM(1), centerRangeM-protocol.profile.halfWidthM), ...
    min(cfg.rangeLimitsM(2), centerRangeM+protocol.profile.halfWidthM)];
intervals = max(protocol.profile.minimumIntervals, ...
    ceil(diff(bounds)/protocol.profile.coarseSpacingM));
result = r31.maximizeScore1D(@scoreValues, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=protocol.profile.peakCount, ...
    TolX=protocol.profile.tolXM, ...
    ScoreTolerance=protocol.profile.scoreTolerance);
result.version = "R57-"+branch+"-range-profile-v1";
result.branch = branch;
result.coarseSpacingM = diff(bounds)/intervals;
result.runtimeSeconds = toc(timer);

    function values = scoreValues(rangeValues)
        values = zeros(size(rangeValues));
        for index = 1:numel(rangeValues)
            state = r57.likelihoodState(cfg, context, phaseBasis, ...
                thetaDeg, rangeValues(index), protocol);
            values(index) = state.(branch);
        end
    end
end
