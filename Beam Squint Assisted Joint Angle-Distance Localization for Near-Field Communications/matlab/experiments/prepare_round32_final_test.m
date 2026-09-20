function prepare_round32_final_test()
%PREPARE_ROUND32_FINAL_TEST Freeze but do not authorize the final design.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
protocol = r32.config();
design = r32.finalTestDesign(protocol);
source = r32.manifest(project);
sourceDigest = r32.sourceDigest(source);
identity = struct(version="R32-final-test-frozen-protocol-v1", ...
    protocol=protocol, designHash=r32.designHash(design), ...
    sourceDigest=sourceDigest, preparedAt=string(datetime("now")), ...
    status="LOCKED-WAITING-FOR-USER-CONFIRMATION");
folder = fullfile(project, "results", "full_spectrum", ...
    "round32_final_test_protocol_v1");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(design, fullfile(folder, "frozen_design_1400.csv"));
writetable(source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "protocol.mat"), "identity", "design", ...
    "source", "-v7.3");
commands = [ ...
    "LOCKED: do not run final shards before explicit user confirmation."; ...
    "After confirmation only: authorize_round32_final_test"; ...
    "Server 1: run_round32_final_shard(1,2,NumWorkers=32,BatchSize=16)"; ...
    "Server 2: run_round32_final_shard(2,2,NumWorkers=32,BatchSize=16)"];
writelines(commands, fullfile(folder, "FUTURE_COMMANDS_AFTER_APPROVAL.txt"));
fprintf("ROUND32_FINAL_TEST_PREPARED_AND_LOCKED rows=%d\n", height(design));
end
