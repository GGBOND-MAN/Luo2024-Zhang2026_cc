function preflight_round28(round27AggregateFile)
%PREFLIGHT_ROUND28 Run required tests and freeze the source manifest.

arguments
    round27AggregateFile (1, 1) string = ""
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
originalPath = path;
addpath(project);
cleanup = onCleanup(@() path(originalPath));
if round27AggregateFile == ""
    round27AggregateFile = fullfile(project, "results", ...
        "full_spectrum", "round27_v3_0200_per_snr", "aggregate", ...
        "round27_aggregate.mat");
end
suite = matlab.unittest.TestSuite.fromFile( ...
    fullfile(project, "tests", "localMusicLogScoreTest.m"));
suite = [suite, matlab.unittest.TestSuite.fromFile( ...
    fullfile(project, "tests", "maximizeRangeScoreTest.m"))];
suite = [suite, matlab.unittest.TestSuite.fromFile( ...
    fullfile(project, "tests", "round28FixedAngleTest.m"))];
testResults = run(suite);
assert(all([testResults.Passed]), "fsjad:Round28PreflightTestsFailed");
setup = fsjad.round28Setup(project, round27AggregateFile, 200, "formal");
source = setup.source;
folder = fullfile(project, "results", "full_spectrum", "round28_preflight");
if ~isfolder(folder)
    mkdir(folder);
end
save(fullfile(folder, "preflight_passed.mat"), "source", ...
    "testResults", "round27AggregateFile", "-v7.3");
writetable(source, fullfile(folder, "source_hashes.csv"));
fprintf("ROUND28_PREFLIGHT_COMPLETE %s\n", folder);
end
