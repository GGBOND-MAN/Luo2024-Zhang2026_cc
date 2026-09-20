function logScore = fixedAngleProfileLogScore( ...
    cfg, thetaDeg, rangeM, context)
%FIXEDANGLEPROFILELOGSCORE Score ranges without constructing derivatives.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM double {mustBeFinite, mustBePositive}
    context (1, 1) struct
end

score = zeros(size(rangeM));
for index = 1:numel(rangeM)
    response = r33.exactSpectralResponse( ...
        cfg, deg2rad(thetaDeg), rangeM(index), context);
    score(index) = r33.profileScore(response, context);
end
logScore = log(max(score, realmin));
end
