function output = sharedPerformanceSet( ...
    cfg, observation, snapshots, scan, protocol)
%SHAREDPERFORMANCESET Compute the frozen comparison set with A-only kernels.
% Shared work is permitted only for performance evaluation and does not define
% independent deployment timing.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct
    protocol (1, 1) struct = r34.config()
end

output = r33.sharedRegressionSet(cfg, observation, snapshots, scan, ...
    protocol.r33, UseFastResponse=true, UseGram=false);
if output.version ~= "R33-A-shared-equivalence-regression-v1"
    error("r34:SharedEstimatorIdentityMismatch", ...
        "The shared calculation did not execute the accepted A-only path.");
end
enhanced = r34.assertAOnlyCost( ...
    output.enhancedStateCost, "enhanced-shared-state", protocol);
public = r34.assertAOnlyCost( ...
    output.publicStateCost, "public-shared-state", protocol);
output.finalSharedVersion = "R34-A-only-shared-performance-body-v1";
output.frozenEstimatorVersion = protocol.estimatorVersion;
output.implementationOptions = struct( ...
    UseFastResponse=true, UseGram=false);
output.solverAudit = struct(enhanced=enhanced, public=public, ...
    totalDirectCount=enhanced.directCount+public.directCount, ...
    totalGramCount=enhanced.gramSuccessCount+public.gramSuccessCount, ...
    totalFallbackCount=enhanced.fallbackCount+public.fallbackCount);
end
