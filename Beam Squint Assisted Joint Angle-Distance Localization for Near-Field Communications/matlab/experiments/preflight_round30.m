function preflight_round30()
%PREFLIGHT_ROUND30 Run regression tests and static analysis before experiments.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
testResults = runtests(fullfile(project, "tests"), Strict=true);
experimentFolder = fullfile(project, "experiments");
listing = [dir(fullfile(experimentFolder, "*round30*.m")); ...
    dir(fullfile(experimentFolder, "audit_round29_600_complete.m"))];
experimentFiles = strings(numel(listing), 1);
for index = 1:numel(listing)
    experimentFiles(index) = fullfile(listing(index).folder, listing(index).name);
end
issues = codeIssues([fullfile(project, "+r30"); experimentFiles; ...
    fullfile(project, "tests", "round30LightweightTest.m")]);
source = r30.manifest(project);
passed = all([testResults.Passed]) && height(issues.Issues) == 0;
folder = fullfile(project, "results", "full_spectrum", "round30_preflight_v1");
if ~isfolder(folder)
    mkdir(folder);
end
save(fullfile(folder, "preflight.mat"), ...
    "testResults", "issues", "source", "passed");
fprintf("R30 TESTS passed=%d failed=%d incomplete=%d static=%d\n", ...
    nnz([testResults.Passed]), nnz([testResults.Failed]), ...
    nnz([testResults.Incomplete]), height(issues.Issues));
assert(passed, "r30:PreflightFailed", ...
    "Round30 preflight failed. Inspect the saved test and static-analysis results.");
end
