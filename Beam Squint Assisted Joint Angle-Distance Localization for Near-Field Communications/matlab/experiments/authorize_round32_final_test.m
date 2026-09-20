function authorize_round32_final_test()
%AUTHORIZE_ROUND32_FINAL_TEST Create the exact post-confirmation gate token.
% This function is intentionally not called by any preparation workflow.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
folder = fullfile(project, "results", "full_spectrum", ...
    "round32_final_test_protocol_v1");
file = fullfile(folder, "protocol.mat");
if ~isfile(file)
    error("r32:MissingFinalProtocol", ...
        "Run prepare_round32_final_test before authorization.");
end
saved = load(file, "identity");
currentSource = r32.manifest(project);
if r32.sourceDigest(currentSource) ~= saved.identity.sourceDigest
    error("r32:FinalSourceDrift", ...
        "Re-run preparation and review because the frozen source has changed.");
end
authorization = struct(approved=true, ...
    designHash=saved.identity.designHash, ...
    sourceDigest=saved.identity.sourceDigest, ...
    protocolVersion=saved.identity.protocol.version, ...
    approvedAt=string(datetime("now")), ...
    statement="user-explicitly-confirmed-one-final-1400-trial-test");
save(fullfile(folder, "FINAL_TEST_AUTHORIZATION.mat"), "authorization");
fprintf("ROUND32_FINAL_TEST_AUTHORIZED identity=%s\n", authorization.designHash);
end
