classdef round36SchemeECalibrationTest < matlab.unittest.TestCase
    %ROUND36SCHEMEECALIBRATIONTEST Frozen calibration identity and reports.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addR36CalibrationPaths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            folders = ["common", "schemeE", "calibration"];
            for folder = folders
                testCase.applyFixture( ...
                    matlab.unittest.fixtures.PathFixture(fullfile( ...
                    testCase.MatlabRoot, "+r36", folder)));
            end
        end
    end

    methods (Test)
        function frozenCalibrationIdentityPasses(testCase)
            setup = r30.setup(testCase.MatlabRoot, "calibration600");
            report = r36AssertSchemeECalibration( ...
                testCase.MatlabRoot, setup, ...
                r36SchemeECalibrationProtocol());

            testCase.verifyTrue(report.passed);
            testCase.verifyFalse(report.estimationExecuted);
            testCase.verifyEqual(report.allRows, 600);
            testCase.verifyEqual(report.holdoutRows, 540);
            testCase.verifyEqual(nnz(report.developmentMask), 60);
            testCase.verifyEqual(report.algorithmDigest, ...
                r36SchemeECalibrationProtocol().algorithmDigest);
        end

        function fixedPartitionIsBalanced(testCase)
            setup = r30.setup(testCase.MatlabRoot, "calibration600");
            report = r36AssertSchemeECalibration( ...
                testCase.MatlabRoot, setup);
            developmentCounts = groupcounts( ...
                setup.design(report.developmentMask, :), "snrDb");
            holdoutCounts = groupcounts( ...
                setup.design(report.holdoutMask, :), "snrDb");

            testCase.verifyEqual(developmentCounts.GroupCount, ...
                20*ones(3, 1));
            testCase.verifyEqual(holdoutCounts.GroupCount, ...
                180*ones(3, 1));
            testCase.verifyEmpty(intersect( ...
                setup.design.seed(report.developmentMask), ...
                setup.design.seed(report.holdoutMask)));
        end

        function syntheticCalibrationSummaryAndFiguresComplete(testCase)
            [design, results, developmentMask] = syntheticFixture();
            summary = r36SummarizeSchemeECalibration( ...
                design, results, developmentMask);
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));

            manifest = r36BuildSchemeECalibrationFigures(summary, folder);

            testCase.verifyEqual(height(summary.perUser), 600);
            testCase.verifyEqual(height(summary.holdout540.perUser), 540);
            testCase.verifyEqual(height(summary.developmentOverlap60.perUser), 60);
            testCase.verifyEqual(height(summary.gate), 16);
            testCase.verifyTrue(summary.calibrationReady);
            testCase.verifyTrue(all(summary.gate.pass));
            testCase.verifyEqual(height(manifest), 5);
            testCase.verifyTrue(all(isfile(manifest.file)));
            testCase.verifyEqual(unique(summary.perUser.subset), ...
                ["development-overlap60"; "holdout540"]);
        end

        function calibrationSourcesContainNoNewEstimator(testCase)
            folder = fullfile(testCase.MatlabRoot, "+r36", "calibration");
            files = dir(fullfile(folder, "*.m"));
            source = "";
            for index = 1:numel(files)
                source = source+newline+string(fileread( ...
                    fullfile(files(index).folder, files(index).name)));
            end
            schemeFCall = regexp(source, ...
                'r36SchemeF[A-Za-z0-9_]*\s*\(', 'once');
            testCase.verifyEmpty(schemeFCall);
            testCase.verifyFalse(contains(lower(source), "fminbnd"));
            testCase.verifyFalse(contains(lower(source), ...
                "i_explicitly_authorize_r34_final_1400"));
        end
    end
end

function [design, results, developmentMask] = syntheticFixture()
seed = (1:600).';
trialIndex = seed;
snrDb = repelem([-10; 0; 20], 200);
truthThetaDeg = zeros(600, 1);
truthRangeM = 30*ones(600, 1);
design = table(seed, trialIndex, snrDb, truthThetaDeg, truthRangeM);
developmentMask = false(600, 1);
developmentMask([1:20, 201:220, 401:420]) = true;
results = cell(600, 1);
for index = 1:600
    thetaPA = 0.001*(1+mod(index, 17));
    thetaE = 0.98*thetaPA;
    results{index} = syntheticResult(thetaPA, thetaE);
end
end

function result = syntheticResult(thetaPA, thetaE)
record = @(theta, range, runtime, response, music) struct( ...
    thetaDeg=theta, rangeM=range, runtimeSeconds=runtime, ...
    responseEvaluationCount=response, musicEvaluationCount=music, ...
    evdCount=2047);
linearization = struct(cost=0.01, gradient=[-1; 0.01], ...
    information=[100, 0.1; 0.1, 2]);
refinement = struct(bracketDeg=[thetaPA-0.001, thetaPA+0.001], ...
    rawDisplacementDeg=thetaE-thetaPA, ...
    diagnosticRangeDisplacementM=1e-6, validUpdate=true, ...
    clippedToBracket=false, status="completed", ...
    linearization=linearization, predictedCostReduction=1e-4, ...
    actualCostReduction=9e-5, effectiveGradient=-1, ...
    effectiveInformation=100, couplingCoefficient=0.01);
result = struct(success=true, runtimeOrder="synthetic", ...
    frontThetaDeg=thetaPA+0.01, frontRangeM=30.1, ...
    P_A=record(thetaPA, 30.01, 2, 100, 93), ...
    E_one_step=record(thetaE, 30.008, 2.1, 101, 95), ...
    C_enhanced=record(thetaPA, 30.02, 4, 90, 3083), ...
    refinement=refinement);
result.E_one_step.refinementSeconds = 0.01;
result.E_one_step.profileSeconds = 0.2;
end
