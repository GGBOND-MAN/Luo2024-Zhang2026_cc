function estimate = convergedFrontEstimate(cfg, observation, scan, legacy, options)
%CONVERGEDFRONTESTIMATE Continue all legacy starts with monotone refinement.
arguments
    cfg (1,1) struct
    observation (:,1) double
    scan (1,1) struct
    legacy (1,1) struct
    options.MaxIterations (1,1) double {mustBeInteger,mustBePositive} = 200
    options.StepTolerance (1,1) double {mustBePositive} = 1e-6
end
count=numel(legacy.refinedThetaDeg);
refined=cell(count,1);
scores=zeros(count,1);
converged=false(count,1);
evaluations=zeros(count,1);
for index=1:count
    refined{index}=fsjad.refineProfileMonotone(cfg,observation, ...
        legacy.refinedThetaDeg(index),legacy.refinedRangeM(index),scan, ...
        MaxIterations=options.MaxIterations,StepTolerance=options.StepTolerance);
    scores(index)=refined{index}.score;
    converged(index)=refined{index}.converged;
    evaluations(index)=refined{index}.responseEvaluations;
end
[~,best]=max(scores);
estimate=refined{best};
estimate.version="FS-Front-Monotone-R27-v2";
estimate.legacyScore=legacy.score;
estimate.maxIterations=options.MaxIterations;
estimate.stepTolerance=options.StepTolerance;
estimate.selectedStart=best;
estimate.startScores=scores;
estimate.startConverged=converged;
estimate.totalResponseEvaluations=legacy.totalResponseEvaluations+sum(evaluations);
estimate.allStarts=refined;
assert(estimate.score>=legacy.score-1e-12,"fsjad:FrontScoreDecreased");
end
