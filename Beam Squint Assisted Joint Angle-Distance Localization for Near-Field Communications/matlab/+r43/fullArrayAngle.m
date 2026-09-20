function result = fullArrayAngle(cfg, context, front, protocol)
%FULLARRAYANGLE Refine angle with the full raw aperture and fixed range.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    front (1, 1) struct
    protocol (1, 1) struct = r43.config()
end

timer = tic;
bounds = [max(cfg.thetaLimitsDeg(1), ...
    front.thetaDeg-protocol.array.angleHalfWidthDeg), ...
    min(cfg.thetaLimitsDeg(2), ...
    front.thetaDeg+protocol.array.angleHalfWidthDeg)];
grid = linspace(bounds(1), bounds(2), protocol.array.coarseAngleGridSize);
score = zeros(size(grid));
for index = 1:numel(grid)
    score(index) = r38RawArrayVpmlScore( ...
        cfg, context, grid(index), front.rangeM);
end
[~, best] = max(score);
left = max(1, best-1);
right = min(numel(grid), best+1);
thetaDeg = grid(best);
selectedScore = score(best);
optimizerEvaluations = 0;
if right > left
    settings = optimset("TolX", protocol.array.tolXDeg, "Display", "off");
    [candidateTheta, negativeScore, exitflag, details] = fminbnd( ...
        @(theta) -r38RawArrayVpmlScore( ...
        cfg, context, theta, front.rangeM), ...
        grid(left), grid(right), settings);
    optimizerEvaluations = details.funcCount;
    if exitflag > 0 && isfinite(negativeScore) ...
            && -negativeScore >= selectedScore
        thetaDeg = candidateTheta;
        selectedScore = -negativeScore;
    end
end
result = struct(version="R43-full-array-angle-v1", ...
    thetaDeg=thetaDeg, rangeLinearizationM=front.rangeM, ...
    score=selectedScore, boundsDeg=bounds, gridDeg=grid, ...
    gridScore=score, gridEvaluationCount=numel(grid), ...
    optimizerEvaluationCount=optimizerEvaluations, ...
    runtimeSeconds=toc(timer));
end
