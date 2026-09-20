function tests = testFigures1013WithCbs
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectDir = fileparts(fileparts(mfilename("fullpath")));
addpath(projectDir);
testCase.TestData.outputDir = string(tempname);
mkdir(testCase.TestData.outputDir);
reproduce_figures_10_13_with_cbs("OutputDir", testCase.TestData.outputDir);
end

function teardownOnce(testCase)
if isfolder(testCase.TestData.outputDir)
    rmdir(testCase.TestData.outputDir, "s");
end
end

function testArtifactsAndProvenance(testCase)
baseNames = ["fig10_proposed_cbs", "fig11_proposed_cbs", ...
    "fig12_proposed_cbs", "fig13_proposed_cbs"];
for index = 1:numel(baseNames)
    for extension = [".png", ".fig", ".csv", ".mat"]
        verifyTrue(testCase, isfile(fullfile(testCase.TestData.outputDir, ...
            baseNames(index) + extension)));
    end
    stored = load(fullfile(testCase.TestData.outputDir, baseNames(index) + ".mat"));
    verifySubstring(testCase, stored.source, "vector paths");
    verifySubstring(testCase, stored.cbsHighStatus, "absent");
    verifyFalse(testCase, any(contains(stored.data.Properties.VariableNames, "CBS_High")));
end
provenance = fileread(fullfile(testCase.TestData.outputDir, "PROVENANCE.txt"));
verifySubstring(testCase, provenance, "CBS-Low: recovered");
verifySubstring(testCase, provenance, "CBS-High is not shown");
end

function testPublishedTrends(testCase)
fig10 = load(fullfile(testCase.TestData.outputDir, "fig10_proposed_cbs.mat"));
verifyTrue(testCase, all(diff(fig10.data.CBS_Low_Angle_RMSE_deg) < 0));
verifyTrue(testCase, all(diff(fig10.data.CBS_Low_Range_RMSE_m) < 0));

fig11 = load(fullfile(testCase.TestData.outputDir, "fig11_proposed_cbs.mat"));
cbs11 = fig11.data{:, contains(fig11.data.Properties.VariableNames, "CBS_Low")};
verifyTrue(testCase, all(diff(cbs11, 1, 1) < 0, "all"));

fig12 = load(fullfile(testCase.TestData.outputDir, "fig12_proposed_cbs.mat"));
verifyTrue(testCase, all(diff(fig12.data.CBS_Low_Angle_RMSE_deg) > 0));
verifyTrue(testCase, all(diff(fig12.data.CBS_Low_Range_RMSE_m) > 0));
verifyEqual(testCase, fig12.data.CBS_Low_Angle_RMSE_deg.', ...
    [0.01099949483, 0.01499947249, 0.01999923195, 0.02299921974, 0.02499907597], ...
    "AbsTol", 1e-12);
verifyEqual(testCase, fig12.data.CBS_Low_Range_RMSE_m.', ...
    [0.0200011593, 0.05000174185, 0.09000314039, 0.1400034817, 0.2000023033], ...
    "AbsTol", 1e-12);

fig13 = load(fullfile(testCase.TestData.outputDir, "fig13_proposed_cbs.mat"));
cbs13 = fig13.data{:, contains(fig13.data.Properties.VariableNames, "CBS_Low")};
verifyTrue(testCase, all(diff(cbs13, 1, 1) < 0, "all"));
verifyGreaterThan(testCase, fig13.data.CBS_Low_Angle_50deg, ...
    fig13.data.CBS_Low_Angle_10deg);
verifyGreaterThan(testCase, fig13.data.CBS_Low_Range_50m, ...
    fig13.data.CBS_Low_Range_10m);
end
