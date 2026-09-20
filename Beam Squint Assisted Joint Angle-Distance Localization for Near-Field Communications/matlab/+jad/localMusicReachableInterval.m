function interval = localMusicReachableInterval(cfg, centerRangeM)
%LOCALMUSICREACHABLEINTERVAL Bound all ranges reachable by local MUSIC grids.

arguments
    cfg (1, 1) struct
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
end

gridSizes = cfg.gridSizes(:).';
if any(gridSizes < 2) || any(mod(gridSizes, 1) ~= 0)
    error("jad:InvalidMusicGridSizes", ...
        "Every MUSIC grid size must be an integer of at least two.");
end

levelHalfWidthM = zeros(size(gridSizes));
levelStepM = zeros(size(gridSizes));
levelHalfWidthM(1) = cfg.localHalfWidthM;
for level = 1:numel(gridSizes)
    levelStepM(level) = 2*levelHalfWidthM(level)/(gridSizes(level) - 1);
    if level < numel(gridSizes)
        levelHalfWidthM(level + 1) = 2*levelStepM(level);
    end
end
totalHalfWidthM = sum(levelHalfWidthM);
lowerM = max(cfg.rangeLimitsM(1), centerRangeM - totalHalfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerRangeM + totalHalfWidthM);

interval.version = "Local-MUSIC-Reachable-Interval-v1";
interval.centerRangeM = centerRangeM;
interval.boundsM = [lowerM, upperM];
interval.unclippedBoundsM = centerRangeM + [-1, 1]*totalHalfWidthM;
interval.totalHalfWidthM = totalHalfWidthM;
interval.levelHalfWidthM = levelHalfWidthM;
interval.levelStepM = levelStepM;
interval.gridSizes = gridSizes;
interval.clipped = any(abs(interval.boundsM - interval.unclippedBoundsM) > eps);
end
