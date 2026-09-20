function result = remoteProfile( ...
    cfg, thetaDeg, context, baseInterval, feasibleRangeM, protocol)
%REMOTEPROFILE Select the best q mode outside the frozen local support.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    context (1, 1) struct
    baseInterval (1, 2) double {mustBeFinite}
    feasibleRangeM (:, 1) double {mustBeFinite} = zeros(0, 1)
    protocol (1, 1) struct = r51.config()
end

gap = protocol.recovery.rangeCoarseSpacingM;
physical = cfg.rangeLimitsM(:).';
intervals = zeros(0, 2);
side = zeros(0, 1);
if baseInterval(1)-gap > physical(1)
    intervals(end+1, :) = [physical(1), baseInterval(1)-gap]; %#ok<AGROW>
    side(end+1, 1) = -1; %#ok<AGROW>
end
if baseInterval(2)+gap < physical(2)
    intervals(end+1, :) = [baseInterval(2)+gap, physical(2)]; %#ok<AGROW>
    side(end+1, 1) = 1; %#ok<AGROW>
end
if isempty(side)
    result = invalidResult(thetaDeg);
    return;
end

profiles = cell(size(side));
scores = -inf(size(side));
for index = 1:numel(side)
    feasible = feasibleRangeM(feasibleRangeM >= intervals(index, 1) ...
        & feasibleRangeM <= intervals(index, 2));
    profiles{index} = r51.profileInterval( ...
        cfg, thetaDeg, context, intervals(index, :), feasible, protocol);
    scores(index) = profiles{index}.score;
end
[~, selected] = max(scores);
result = profiles{selected};
result.version = "R51-remote-exact-q-profile-v1";
result.side = side(selected);
result.remoteIntervals = intervals;
result.valid = true;
end

function output = invalidResult(thetaDeg)
output = struct(version="R51-remote-exact-q-profile-v1", ...
    thetaDeg=thetaDeg, value=nan, score=-inf, side=0, ...
    remoteIntervals=zeros(0, 2), valid=false, evaluationCount=0);
end
