function output = refineBasin(cfg, context, thetaDeg, candidate, protocol)
%REFINEBASIN Maximize the full joint score inside one frozen q basin.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    candidate (1, :) table
    protocol (1, 1) struct = r56.config()
end

timer = tic;
baseRange = candidate.rangeM;
baseState = r53.likelihoodState( ...
    cfg, context, thetaDeg, baseRange, protocol.base);
rangeM = baseRange;
score = baseState.scoreJoint;
optimizerAccepted = false;
optimizerEvaluations = 0;
status = "q-candidate-fallback";
try
    settings = optimset("TolX", protocol.refinement.tolXM, "Display", "off");
    [refined, negativeScore, exitflag, details] = fminbnd( ...
        @(value) -jointScore(value), candidate.lowerM, candidate.upperM, settings);
    optimizerEvaluations = details.funcCount;
    tolerance = protocol.refinement.scoreTolerance;
    if exitflag > 0 && isfinite(refined) && isfinite(negativeScore) ...
            && -negativeScore >= score-tolerance
        rangeM = refined;
        score = -negativeScore;
        optimizerAccepted = true;
        status = "joint-refinement-accepted";
    end
catch exception
    status = "optimizer-exception-"+string(exception.identifier);
end
output = struct(version="R56-q-basin-joint-refinement-v1", ...
    rangeM=rangeM, score=score, qCandidateRangeM=baseRange, ...
    qCandidateScore=candidate.qScore, lowerM=candidate.lowerM, ...
    upperM=candidate.upperM, candidateIndex=candidate.candidateIndex, ...
    peakGridIndex=candidate.peakGridIndex, ...
    optimizerAccepted=optimizerAccepted, ...
    optimizerEvaluations=optimizerEvaluations, status=status, ...
    runtimeSeconds=toc(timer));

    function value = jointScore(rangeValue)
        state = r53.likelihoodState( ...
            cfg, context, thetaDeg, rangeValue, protocol.base);
        value = state.scoreJoint;
    end
end
