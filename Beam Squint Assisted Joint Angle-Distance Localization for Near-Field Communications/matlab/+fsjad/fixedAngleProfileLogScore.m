function logScore = fixedAngleProfileLogScore( ...
    cfg, observation, thetaDeg, rangeM, scan)
%FIXEDANGLEPROFILELOGSCORE Evaluate concentrated spectral log likelihood.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM double {mustBeFinite, mustBePositive}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
end

score = zeros(size(rangeM));
for index = 1:numel(rangeM)
    response = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(thetaDeg), rangeM(index), scan);
    score(index) = fsjad.profileScore(response, observation);
end
logScore = log(max(score, realmin));
end
