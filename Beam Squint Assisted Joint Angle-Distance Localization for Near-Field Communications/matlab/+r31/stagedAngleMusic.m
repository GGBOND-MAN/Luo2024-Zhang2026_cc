function result = stagedAngleMusic(cfg, state, coarseThetaDeg, ...
    fixedRangeM, halfWidthDeg, gridSizes)
%STAGEDANGLEMUSIC Apply the published staged grid rule only to angle.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    coarseThetaDeg (1, 1) double {mustBeFinite}
    fixedRangeM (1, 1) double {mustBeFinite, mustBePositive}
    halfWidthDeg (1, 1) double {mustBePositive}
    gridSizes (1, :) double {mustBeInteger, mustBePositive}
end

if any(gridSizes < 2)
    error("r31:InvalidAngleGrid", ...
        "Every staged angle grid must contain at least two points.");
end
initialBounds = [max(cfg.thetaLimitsDeg(1), coarseThetaDeg-halfWidthDeg), ...
    min(cfg.thetaLimitsDeg(2), coarseThetaDeg+halfWidthDeg)];
thetaCenter = coarseThetaDeg;
currentHalfWidth = halfWidthDeg;
stages = repmat(emptyStage(), numel(gridSizes), 1);
evaluationCount = 0;

for level = 1:numel(gridSizes)
    gridSize = gridSizes(level);
    thetaGrid = linspace(max(thetaCenter-currentHalfWidth, initialBounds(1)), ...
        min(thetaCenter+currentHalfWidth, initialBounds(2)), gridSize);
    score = jad.localMusicLogScore(cfg, state, thetaGrid, fixedRangeM);
    [selectedScore, selectedIndex] = max(score);
    thetaCenter = thetaGrid(selectedIndex);
    thetaStep = thetaGrid(2)-thetaGrid(1);
    currentHalfWidth = 2*thetaStep;
    evaluationCount = evaluationCount + gridSize;
    stages(level).thetaGridDeg = thetaGrid;
    stages(level).score = score;
    stages(level).selectedIndex = selectedIndex;
    stages(level).selectedThetaDeg = thetaCenter;
    stages(level).selectedScore = selectedScore;
    stages(level).endpointHit = selectedIndex == 1 ...
        || selectedIndex == gridSize;
end

result.version = "R31-staged-fixed-range-angle-MUSIC-v1";
result.thetaDeg = thetaCenter;
result.fixedRangeM = fixedRangeM;
result.score = stages(end).selectedScore;
result.initialBoundsDeg = initialBounds;
result.gridSizes = gridSizes;
result.evaluationCount = evaluationCount;
result.stages = stages;
result.finalEndpointHit = stages(end).endpointHit;
end

function stage = emptyStage()
stage = struct(thetaGridDeg=zeros(1, 0), score=zeros(1, 0), ...
    selectedIndex=nan, selectedThetaDeg=nan, selectedScore=nan, ...
    endpointHit=false);
end
