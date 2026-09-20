function output = front(cfg, observation, scan, protocol)
%FRONT Observation-only numerical reference; no seed or saved estimates.
arguments
    cfg (1,1) struct
    observation (:,1) double {mustBeFinite}
    scan (1,1) struct
    protocol (1,1) struct
end
assert(protocol.anchorPolicy == "none-observation-only-not-identical-to-R28-v2", ...
    "r29:AnchorPolicy");
timer = tic;
output = r29.candidateFront(cfg, observation, scan, protocol.angleOffsetsDeg, ...
    IterationCaps=protocol.maxIterations, ...
    InitialSpacingM=protocol.initialSpacingM, PeakCount=protocol.peakCount, ...
    RefinementLevels=protocol.refinementLevels, ...
    StepTolerance=protocol.stepTolerance);
output.version = protocol.frontVersion;
output.selected = output.selectedEstimates{1};
output.cost.diagnosticEvaluations = 0;
output.cost.diagnosticSeconds = 0;
output.diagnostics = cell(0,1);
if ~output.selected.converged
    diagnosticTimer = tic;
    for cap = [400,800]
        refined = fsjad.refineProfileMonotone(cfg,observation, ...
            output.selected.thetaDeg,output.selected.rangeM,scan, ...
            MaxIterations=cap,StepTolerance=protocol.stepTolerance);
        output.diagnostics{end+1,1} = refined;
        output.cost.diagnosticEvaluations = output.cost.diagnosticEvaluations ...
            + refined.responseEvaluations;
        if refined.score>=output.selected.score
            output.selected = refined;
        end
        if output.selected.converged, break; end
    end
    output.cost.diagnosticSeconds = toc(diagnosticTimer);
end
output.cost.cacheGenerationSeconds = 0;
output.cost.cacheGenerationEvaluations = 0;
output.runtimeSeconds = toc(timer);
output.totalEvaluations = output.cost.candidateEvaluations ...
    + output.cost.stageOneEvaluations + output.cost.profileEvaluations ...
    + sum(output.cost.finalEvaluations) + output.cost.diagnosticEvaluations;
end
