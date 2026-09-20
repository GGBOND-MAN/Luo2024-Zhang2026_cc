function result = estimate(cfg, observation, snapshots, scan, method, protocol)
%ESTIMATE Run one formal A-only online entry with direct EVD fixed.
% The public signature intentionally exposes no Gram or implementation switch.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct
    method (1, 1) string {mustBeMember(method, ...
        ["C_enhanced", "H_A", "P_A", "C_public"])}
    protocol (1, 1) struct = r34.config()
end

result = r33.estimate(cfg, observation, snapshots, scan, method, ...
    protocol.r33, UseFastResponse=true, UseGram=false);
solver = r34.assertAOnlyCost(result.cost, method, protocol);
if result.version ~= protocol.estimatorVersion
    error("r34:EstimatorIdentityMismatch", ...
        "The formal entry did not execute the accepted R33 A-only identity.");
end
result.finalEntryVersion = "R34-explicit-A-only-online-entry-v1";
result.frozenEstimatorVersion = protocol.estimatorVersion;
result.implementationOptions = struct( ...
    UseFastResponse=true, UseGram=false);
result.solverAudit = solver;
end
