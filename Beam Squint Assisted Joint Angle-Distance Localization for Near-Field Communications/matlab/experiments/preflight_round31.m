function preflight_round31()
%PREFLIGHT_ROUND31 Run all tests and static checks for the isolated repair.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
testResults = runtests(fullfile(project, "tests"), Strict=true);
experimentListing = dir(fullfile(project, "experiments", "*round31*.m"));
experimentFiles = strings(numel(experimentListing), 1);
for index = 1:numel(experimentListing)
    experimentFiles(index) = fullfile( ...
        experimentListing(index).folder, experimentListing(index).name);
end
issues = codeIssues([fullfile(project, "+r31"); experimentFiles; ...
    fullfile(project, "tests", "round31CorrectnessTest.m")]);
source = r31.manifest(project);
passed = all([testResults.Passed]) && height(issues.Issues) == 0;
folder = fullfile(project, "results", "full_spectrum", ...
    "round31_preflight_v2");
if ~isfolder(folder)
    mkdir(folder);
end
save(fullfile(folder, "preflight.mat"), ...
    "testResults", "issues", "source", "passed");
writetable(source, fullfile(folder, "source_hashes.csv"));
fprintf("R31 TESTS passed=%d failed=%d incomplete=%d static=%d\n", ...
    nnz([testResults.Passed]), nnz([testResults.Failed]), ...
    nnz([testResults.Incomplete]), height(issues.Issues));
assert(passed, "r31:PreflightFailed", ...
    "Round31 preflight failed. Inspect the saved test and static results.");
end
