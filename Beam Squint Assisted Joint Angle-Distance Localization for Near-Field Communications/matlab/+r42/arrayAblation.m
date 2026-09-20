function result = arrayAblation(cfg, context, observation, scan, front, protocol)
%ARRAYABLATION Full-aperture angle followed by one frozen q profile.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    observation (:, 1) double
    scan (1, 1) struct
    front (1, 1) struct
    protocol (1, 1) struct = r42.config()
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
continuousTheta = grid(best);
continuousScore = score(best);
optimizerEvaluations = 0;
if right > left
    settings = optimset("TolX", protocol.array.tolXDeg, "Display", "off");
    [candidateTheta, negativeScore, exitflag, details] = fminbnd( ...
        @(theta) -r38RawArrayVpmlScore( ...
        cfg, context, theta, front.rangeM), ...
        grid(left), grid(right), settings);
    optimizerEvaluations = details.funcCount;
    if exitflag > 0 && isfinite(negativeScore) ...
            && -negativeScore >= continuousScore
        continuousTheta = candidateTheta;
        continuousScore = -negativeScore;
    end
end
profile = r32.profileAtAngle(cfg, observation, scan, ...
    continuousTheta, front.rangeM, r32.config());
result = struct(version="R42-full-array-sequential-ablation-v1", ...
    thetaDeg=continuousTheta, rangeM=profile.value, ...
    score=continuousScore, angleBoundsDeg=bounds, ...
    angleGridEvaluationCount=numel(grid), ...
    angleOptimizerEvaluationCount=optimizerEvaluations, ...
    profileEvaluationCount=profile.evaluationCount, ...
    profileEndpointHit=profile.endpointHit, runtimeSeconds=toc(timer));
end
