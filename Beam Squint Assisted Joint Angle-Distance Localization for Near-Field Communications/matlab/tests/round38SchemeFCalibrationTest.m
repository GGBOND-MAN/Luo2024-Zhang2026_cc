classdef round38SchemeFCalibrationTest < matlab.unittest.TestCase
    %ROUND38SCHEMEFCALIBRATIONTEST Frozen inputs and summary plumbing.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addCalibrationPaths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            folders = ["common", "schemeF", "calibration"];
            for folder = folders
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                    fullfile(testCase.MatlabRoot, "+r38", folder)));
            end
        end
    end

    methods (Test)
        function frozenCalibrationIdentityPasses(testCase)
            setup = r30.setup(testCase.MatlabRoot, "calibration600");
            report = r38AssertSchemeFCalibration( ...
                testCase.MatlabRoot, setup);

            testCase.verifyTrue(report.passed);
            testCase.verifyFalse(report.estimationExecuted);
            testCase.verifyEqual(report.allRows, 600);
            testCase.verifyEqual(report.holdoutRows, 540);
            testCase.verifyEqual(nnz(report.developmentMask), 60);
            testCase.verifyEqual(report.algorithmDigest, ...
                r38SchemeFCalibrationProtocol().algorithmDigest);
        end

        function syntheticBalancedCalibrationSummaryPasses(testCase)
            development = load(fullfile(testCase.MatlabRoot, "results", ...
                "full_spectrum", ...
                "round38_schemeF_raw_array_vpml_development_v1", ...
                "result.mat"), "design", "results");
            [design, results, r37PerUser, mask] = ...
                repeatedCalibrationFixture(development);
            summary = r38SummarizeSchemeFCalibration(design, results, ...
                r37PerUser, mask, development.results);

            testCase.verifyEqual(height(summary.perUser), 600);
            testCase.verifyEqual(height(summary.holdout540.perUser), 540);
            testCase.verifyTrue(summary.calibrationReady);
            testCase.verifyTrue(all(summary.gate.pass));
            testCase.verifyTrue(all(summary.reproduction.pass));
            testCase.verifyEqual(unique(summary.perUser.subset), ...
                ["development-overlap60"; "holdout540"]);
        end

        function protocolForbidsNewFinalAndSingleProfileCombination(testCase)
            protocol = r38SchemeFCalibrationProtocol();

            testCase.verifyFalse(protocol.calibration.newUsersAllowed);
            testCase.verifyFalse(protocol.r34FinalAuthorized);
            testCase.verifyFalse(protocol.parameterChangesAuthorized);
            testCase.verifyFalse( ...
                protocol.singleProfileCombinationAuthorized);
            testCase.verifyEqual(protocol.calibration.allUsers, 600);
            testCase.verifyEqual(protocol.calibration.holdoutUsers, 540);
        end
    end
end

function [design, results, r37, developmentMask] = ...
    repeatedCalibrationFixture(development)
design = repmat(development.design, 10, 1);
results = repmat(development.results, 10, 1);
for block = 2:10
    rows = (block-1)*60+(1:60);
    design.seed(rows) = development.design.seed+(block-1)*1e8;
    design.trialIndex(rows) = development.design.trialIndex+(block-1)*60;
end
developmentMask = false(600, 1);
developmentMask(1:60) = true;
theta = cellfun(@(x) x.E_reference.thetaDeg, results);
rangeM = cellfun(@(x) x.E_reference.rangeM, results);
runtime = cellfun(@(x) x.E_reference.runtimeSeconds, results);
response = cellfun(@(x) x.E_reference.responseEvaluationCount, results);
music = cellfun(@(x) x.E_reference.musicEvaluationCount, results);
evd = cellfun(@(x) x.E_reference.evdCount, results);
profilePA = cellfun(@(x) x.firstProfileEvaluationCount, results);
r37 = table(design.seed, theta, rangeM, runtime, response, music, evd, ...
    ones(600, 1), 2*ones(600, 1), ones(600, 1), profilePA, ...
    cellfun(@(x) x.E_reference.profileEvaluationCount, results), ...
    profilePA, 'VariableNames', {'seed', 'theta_E_single', ...
    'range_E_single', 'runtime_E_single', 'responseCount_E_single', ...
    'musicCount_E_single', 'evdCount_E_single', ...
    'profilePasses_P_A', 'profilePasses_E_full', ...
    'profilePasses_E_single', 'profileEvaluations_P_A', ...
    'profileEvaluations_E_full', 'profileEvaluations_E_single'});
end
