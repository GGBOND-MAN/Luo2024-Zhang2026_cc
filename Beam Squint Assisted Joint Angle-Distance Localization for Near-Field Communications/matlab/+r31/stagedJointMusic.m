function result = stagedJointMusic(cfg, state, coarseThetaDeg, ...
    coarseRangeM, halfWidthDeg, halfWidthM, gridSizes)
%STAGEDJOINTMUSIC Reproduce the constrained staged two-dimensional grid.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    coarseThetaDeg (1, 1) double {mustBeFinite}
    coarseRangeM (1, 1) double {mustBeFinite, mustBePositive}
    halfWidthDeg (1, 1) double {mustBePositive}
    halfWidthM (1, 1) double {mustBePositive}
    gridSizes (1, :) double {mustBeInteger, mustBePositive}
end

initialThetaBounds = [max(cfg.thetaLimitsDeg(1), ...
    coarseThetaDeg-halfWidthDeg), ...
    min(cfg.thetaLimitsDeg(2), coarseThetaDeg+halfWidthDeg)];
initialRangeBounds = [max(cfg.rangeLimitsM(1), coarseRangeM-halfWidthM), ...
    min(cfg.rangeLimitsM(2), coarseRangeM+halfWidthM)];
thetaCenter = coarseThetaDeg;
rangeCenter = coarseRangeM;
thetaHalfWidth = halfWidthDeg;
rangeHalfWidth = halfWidthM;
stages = repmat(emptyStage(), numel(gridSizes), 1);
evaluationCount = 0;

for level = 1:numel(gridSizes)
    gridSize = gridSizes(level);
    thetaGrid = linspace(max(thetaCenter-thetaHalfWidth, ...
        initialThetaBounds(1)), min(thetaCenter+thetaHalfWidth, ...
        initialThetaBounds(2)), gridSize);
    rangeGrid = linspace(max(rangeCenter-rangeHalfWidth, ...
        initialRangeBounds(1)), min(rangeCenter+rangeHalfWidth, ...
        initialRangeBounds(2)), gridSize);
    [thetaMesh, rangeMesh] = meshgrid(thetaGrid, rangeGrid);
    score = jad.localMusicLogScore( ...
        cfg, state, thetaMesh, rangeMesh);
    [selectedScore, linearIndex] = max(score, [], "all", "linear");
    [rangeIndex, thetaIndex] = ind2sub(size(score), linearIndex);
    thetaCenter = thetaGrid(thetaIndex);
    rangeCenter = rangeGrid(rangeIndex);
    thetaStep = thetaGrid(2)-thetaGrid(1);
    rangeStep = rangeGrid(2)-rangeGrid(1);
    thetaHalfWidth = 2*thetaStep;
    rangeHalfWidth = 2*rangeStep;
    evaluationCount = evaluationCount + gridSize^2;
    stages(level).thetaGridDeg = thetaGrid;
    stages(level).rangeGridM = rangeGrid;
    stages(level).selectedThetaIndex = thetaIndex;
    stages(level).selectedRangeIndex = rangeIndex;
    stages(level).selectedScore = selectedScore;
    stages(level).thetaEndpointHit = thetaIndex == 1 ...
        || thetaIndex == gridSize;
    stages(level).rangeEndpointHit = rangeIndex == 1 ...
        || rangeIndex == gridSize;
end

result.version = "R31-constrained-staged-joint-MUSIC-v1";
result.thetaDeg = thetaCenter;
result.rangeM = rangeCenter;
result.score = stages(end).selectedScore;
result.initialThetaBoundsDeg = initialThetaBounds;
result.initialRangeBoundsM = initialRangeBounds;
result.gridSizes = gridSizes;
result.evaluationCount = evaluationCount;
result.stages = stages;
end

function stage = emptyStage()
stage = struct(thetaGridDeg=zeros(1, 0), rangeGridM=zeros(1, 0), ...
    selectedThetaIndex=nan, selectedRangeIndex=nan, selectedScore=nan, ...
    thetaEndpointHit=false, rangeEndpointHit=false);
end
