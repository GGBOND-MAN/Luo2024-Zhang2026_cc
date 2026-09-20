function aggregate_round34_final_test(shardCount)
%AGGREGATE_ROUND34_FINAL_TEST Aggregate one complete authorized final run.

arguments
    shardCount (1, 1) double {mustBeInteger, mustBePositive} = 2
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
protocolFolder = fullfile(project, "results", "full_spectrum", ...
    "round34_final_test_protocol_v1");
protocolFile = fullfile(protocolFolder, "protocol.mat");
if ~isfile(protocolFile)
    error("r34:MissingFinalProtocol", ...
        "The reviewed R34 protocol is missing.");
end
saved = load(protocolFile, "identity", "design");
r34.assertFinalTestAuthorized(protocolFolder, saved.identity);
if shardCount ~= saved.identity.protocol.finalTest.expectedShardCount ...
        || r32.designHash(saved.design) ~= saved.identity.designHash ...
        || r32.sourceDigest(r34.manifest(project)) ...
        ~= saved.identity.sourceDigest
    error("r34:FinalAggregateIdentityDrift", ...
        "Final source, design, or fixed two-shard layout has drifted.");
end

payloads = cell(shardCount, 1);
for shardIndex = 1:shardCount
    folder = fullfile(project, "results", "full_spectrum", ...
        "round34_final_test_v1", sprintf("shard_%02d_of_%02d", ...
        shardIndex, shardCount));
    if ~isfile(fullfile(folder, "COMPLETE.mat")) ...
            || ~isfile(fullfile(folder, "result.mat"))
        error("r34:IncompleteFinalShard", ...
            "Final shard %d is not complete.", shardIndex);
    end
    payloads{shardIndex} = load(fullfile(folder, "result.mat"), ...
        "identity", "design", "results", "environment");
end
results = r34.mergeShardPayloads(saved.design, payloads, saved.identity);
output = r34.summarizeFinal( ...
    saved.design, results, saved.identity.protocol);
folder = fullfile(project, "results", "full_spectrum", ...
    "round34_final_test_v1", "aggregate");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(output.perUser, fullfile(folder, "per_user.csv"));
writetable(output.summary, fullfile(folder, "method_summary.csv"));
writetable(output.primary, ...
    fullfile(folder, "primary_simultaneous_inference.csv"));
writetable(output.secondary, ...
    fullfile(folder, "secondary_descriptive.csv"));
source = r34.manifest(project);
writetable(source, fullfile(folder, "source_hashes.csv"));
identity = saved.identity;
save(fullfile(folder, "result.mat"), "identity", "output", ...
    "source", "-v7.3");
fprintf("ROUND34_FINAL_AGGREGATE_COMPLETE rows=%d positions=%d\n", ...
    height(saved.design), numel(unique(saved.design.positionId)));
end
