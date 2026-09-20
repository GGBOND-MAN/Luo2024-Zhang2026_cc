classdef round54PfaLikelihoodFusionCalibrationTest < matlab.unittest.TestCase
    %ROUND54PFALIKELIHOODFUSIONCALIBRATIONTEST R54 protocol tests.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDesignIsDeterministicAndSeparated(testCase)
            protocol = r54.config();
            first = r54.design(protocol);
            second = r54.design(protocol);
            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 600);
            testCase.verifyEqual(sum(first.subset == "diagnostic60"), 60);
            testCase.verifyEqual(sum(first.subset == "holdout540"), 540);
        end

        function testFrozenDigestsMatch(testCase)
            protocol = r54.config();
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.verifyEqual(r32.sourceDigest(r53.manifest(project)), ...
                protocol.freeze.expectedR53SourceDigest);
            testCase.verifyEqual(r32.sourceDigest(r45.manifest(project)), ...
                protocol.freeze.expectedPfaSourceDigest);
        end

        function testCalibrationGovernance(testCase)
            protocol = r54.config();
            testCase.verifyFalse(protocol.execution.finalRowsAccessible);
            testCase.verifyFalse(protocol.execution.priorCalibrationRowsAccessible);
            testCase.verifyFalse(protocol.execution.parameterTuningAllowed);
            testCase.verifyFalse(protocol.execution.modifyFrozenR53);
            testCase.verifyEqual(protocol.gate.requiredPopulations, ...
                ["all600", "holdout540"]);
            testCase.verifyEqual(protocol.gate.maxBootstrapUpper95ToPA, 1.02);
        end
    end
end
