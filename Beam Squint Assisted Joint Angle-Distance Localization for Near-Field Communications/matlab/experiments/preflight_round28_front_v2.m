function preflight_round28_front_v2()
%PREFLIGHT_ROUND28_FRONT_V2 Test and freeze the front-v2 source manifest.

project = string(fileparts(fileparts(mfilename("fullpath"))));
originalPath = path;
addpath(project);
cleanup = onCleanup(@() path(originalPath));
suite = matlab.unittest.TestSuite.fromFile(fullfile( ...
    project, "tests", "maximizeRangeScoreTest.m"));
suite = [suite, matlab.unittest.TestSuite.fromFile(fullfile( ...
    project, "tests", "deterministicMultipeakFrontTest.m"))];
testResults = run(suite);
assert(all([testResults.Passed]), "fsjad:Round28FrontV2PreflightFailed");
setup = fsjad.round28FrontV2Setup(project);
source = setup.source;
folder = fullfile(project, "results", "full_spectrum", ...
    "round28_front_candidate_preflight_v2");
if ~isfolder(folder)
    mkdir(folder);
end
save(fullfile(folder, "preflight_passed.mat"), ...
    "source", "testResults", "-v7.3");
writetable(source, fullfile(folder, "source_hashes.csv"));
fprintf("ROUND28_FRONT_V2_PREFLIGHT_COMPLETE %s\n", folder);
end
