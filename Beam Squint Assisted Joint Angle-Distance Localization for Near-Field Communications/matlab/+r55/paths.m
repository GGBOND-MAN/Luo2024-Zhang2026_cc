function output = paths(project)
%PATHS Return immutable R55 protocol and execution locations.

arguments
    project (1, 1) string
end

root = fullfile(project, "results", "full_spectrum");
output = struct( ...
    protocolFolder=fullfile(root, "round55_p_falf_final_protocol_v1"), ...
    executionFolder=fullfile(root, "round55_p_falf_independent_final_v1"), ...
    benchmarkFolder=fullfile(root, "round55_p_falf_runtime_benchmark_v1"));
output.protocolFile = fullfile(output.protocolFolder, "protocol.mat");
output.authorizationFile = fullfile(output.protocolFolder, "authorization.mat");
output.benchmarkFile = fullfile(output.benchmarkFolder, "result.mat");
end
