function cost = complexity(cfg, candidate, result)
%COMPLEXITY Record theoretical units and executable operation counts.

arguments
    cfg (1, 1) struct
    candidate (1, :) table
    result (1, 1) struct
end

front = result.front;
state = result.musicStateCost;
angleEvaluations = result.angleSolver.evaluationCount;
profileEvaluations = result.profileSolver.evaluationCount;
cost.version = "R30-complexity-accounting-v1";
cost.frontSubsetResponses = front.subsetEvaluations;
cost.frontFullResponses = front.fullEvaluations;
cost.frontFullResponseUpperBound = front.fullResponseUpperBound;
cost.frontEquivalentFullResponses = front.fullEquivalentResponses;
cost.profileFullResponses = profileEvaluations;
cost.totalEquivalentFullResponses = front.fullEquivalentResponses ...
    + profileEvaluations;
cost.frontElementCarrierTerms = cfg.numAntennas*( ...
    front.subsetEvaluations*candidate.frontCarrierCount ...
    + front.fullEvaluations*cfg.numSubcarriers);
cost.profileElementCarrierTerms = cfg.numAntennas ...
    *profileEvaluations*cfg.numSubcarriers;
cost.musicPhaseAlignmentTerms = state.phaseAlignmentTerms;
cost.musicCovarianceMacs = state.covarianceMacs;
cost.musicEvdCubicUnits = state.evdCubicUnits;
cost.angleScoreProjectionMacs = candidate.musicCarrierCount ...
    *angleEvaluations*candidate.musicSubarraySize;
cost.paperAngleNoiseSubspaceUnits = candidate.musicCarrierCount ...
    *angleEvaluations*candidate.musicSubarraySize^2;
cost.angleEvaluations = angleEvaluations;
cost.profileEvaluations = profileEvaluations;
cost.onlineSeconds = result.front.runtimeSeconds + state.seconds ...
    + result.angleSeconds + result.profileSeconds;
end
