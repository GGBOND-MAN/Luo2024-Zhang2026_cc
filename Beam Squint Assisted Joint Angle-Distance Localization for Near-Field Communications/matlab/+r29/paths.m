function paths = paths(project)
%PATHS Resolve immutable data locally or in the original download locations.
arguments
    project (1,1) string
end
workspace = string(fileparts(fileparts(project)));
paths.r27 = fullfile(project,"results","full_spectrum", ...
    "round27_v3_0200_per_snr","aggregate","round27_aggregate.mat");
if ~isfile(paths.r27)
    paths.r27 = fullfile(workspace,"server_packages", ...
        "round27_v3_upload_20260906_144745","matlab","results", ...
        "full_spectrum","round27_v3_0200_per_snr","aggregate","round27_aggregate.mat");
end
paths.v2 = fullfile(project,"results","full_spectrum", ...
    "round28_front_candidate_closure_v2","front_candidate_closure_v2.mat");
if ~isfile(paths.v2)
    paths.v2 = fullfile(workspace,"server_packages", ...
        "round28_front_v2_upload_20260907_110547","matlab","results", ...
        "full_spectrum","round28_front_candidate_closure_v2","front_candidate_closure_v2.mat");
end
assert(isfile(paths.r27) && isfile(paths.v2),"r29:MissingInputs");
end
