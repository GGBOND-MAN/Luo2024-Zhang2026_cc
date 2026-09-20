function aggregate_round32_final_test(shardCount)
%AGGREGATE_ROUND32_FINAL_TEST Aggregate only a complete authorized run.

arguments
    shardCount (1, 1) double {mustBeInteger, mustBePositive} = 2
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
protocolFolder = fullfile(project, "results", "full_spectrum", ...
    "round32_final_test_protocol_v1");
protocolSaved = load(fullfile(protocolFolder, "protocol.mat"), ...
    "identity", "design");
if r32.designHash(protocolSaved.design) ~= protocolSaved.identity.designHash ...
        || r32.sourceDigest(r32.manifest(project)) ...
        ~= protocolSaved.identity.sourceDigest
    error("r32:FinalAggregateIdentityDrift", ...
        "The final protocol design or executable source has drifted.");
end
r32.assertFinalTestAuthorized(protocolFolder, protocolSaved.identity);
results = cell(height(protocolSaved.design), 1);
for shardIndex = 1:shardCount
    folder = fullfile(project, "results", "full_spectrum", ...
        "round32_final_test_v1", sprintf("shard_%02d_of_%02d", ...
        shardIndex, shardCount));
    if ~isfile(fullfile(folder, "COMPLETE.mat")) ...
            || ~isfile(fullfile(folder, "result.mat"))
        error("r32:IncompleteFinalShard", ...
            "Final shard %d is not complete.", shardIndex);
    end
    shard = load(fullfile(folder, "result.mat"), ...
        "identity", "design", "results");
    if shard.identity.protocolIdentity.designHash ...
            ~= protocolSaved.identity.designHash
        error("r32:FinalShardIdentityMismatch", ...
            "Final shard %d has a different protocol.", shardIndex);
    end
    results(shard.identity.globalRowIndex) = shard.results;
end

output = r32.summarizeFinal(protocolSaved.design, results, ...
    protocolSaved.identity.protocol);
folder = fullfile(project, "results", "full_spectrum", ...
    "round32_final_test_v1", "aggregate");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(output.perUser, fullfile(folder, "per_user.csv"));
writetable(output.summary, fullfile(folder, "method_summary.csv"));
writetable(output.primary, fullfile(folder, "primary_simultaneous_inference.csv"));
writetable(output.secondary, fullfile(folder, "secondary_descriptive.csv"));
source = r32.manifest(project);
writetable(source, fullfile(folder, "source_hashes.csv"));
identity = protocolSaved.identity;
save(fullfile(folder, "result.mat"), "identity", "output", ...
    "source", "-v7.3");
fprintf("ROUND32_FINAL_AGGREGATE_COMPLETE users=%d\n", ...
    height(protocolSaved.design));
end
