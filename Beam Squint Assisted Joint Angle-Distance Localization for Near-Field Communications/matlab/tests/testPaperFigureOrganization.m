function tests = testPaperFigureOrganization
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectDir = fileparts(fileparts(mfilename("fullpath")));
addpath(projectDir);
testCase.TestData.outputDir = string(tempname);
mkdir(testCase.TestData.outputDir);
reproduce_figures_02_13("Figures", [2, 10], ...
    "OutputDir", testCase.TestData.outputDir);
end

function teardownOnce(testCase)
if isfolder(testCase.TestData.outputDir)
    rmdir(testCase.TestData.outputDir, "s");
end
end

function testUnifiedRunnerWritesBothFigureGroups(testCase)
verifyTrue(testCase, isfile(fullfile(testCase.TestData.outputDir, ...
    "fig02_array_gain.png")));
verifyTrue(testCase, isfile(fullfile(testCase.TestData.outputDir, ...
    "fig10_proposed_cbs.png")));
verifyTrue(testCase, isfile(fullfile(testCase.TestData.outputDir, ...
    "fig10_proposed_cbs.mat")));
verifyTrue(testCase, isfile(fullfile(testCase.TestData.outputDir, ...
    "PROVENANCE.txt")));
end
