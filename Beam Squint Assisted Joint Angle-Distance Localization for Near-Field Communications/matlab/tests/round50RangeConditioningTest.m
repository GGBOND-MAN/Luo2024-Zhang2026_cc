classdef round50RangeConditioningTest < matlab.unittest.TestCase
    %ROUND50RANGECONDITIONINGTEST Tests for frozen R50 diagnostics.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testFiniteDifferenceQuadratic(testCase)
            score = @(x, y) -(x-2).^2-3*(y+1).^2+0.5*x.*y;
            result = r50.finiteDifference2D(score, 0.4, -0.2, 1e-4, 2e-4);
            expectedGradient = [-2*(0.4-2)+0.5*(-0.2); ...
                -6*(-0.2+1)+0.5*0.4];
            expectedHessian = [-2, 0.5; 0.5, -6];

            testCase.verifyEqual(result.gradient, expectedGradient, ...
                AbsTol=1e-7);
            testCase.verifyEqual(result.hessian, expectedHessian, ...
                AbsTol=1e-6);
        end

        function testProfileModeIdentity(testCase)
            profile = struct(grid=(0:4).', ...
                gridScore=[0; 2; 0; 1; 0], peakIndex=[1; 2; 4; 5], ...
                value=1.1, score=2.1);
            result = r50.profileMode(profile);

            testCase.verifyEqual(result.selectedPeakGridIndex, 2);
            testCase.verifyEqual(result.selectedPeakRangeM, 1, AbsTol=1e-12);
            testCase.verifyEqual(result.scoreMargin, 1.1, AbsTol=1e-12);
        end

        function testFrozenEvidenceBoundary(testCase)
            protocol = r50.config();

            testCase.verifyFalse(protocol.source.newUsers);
            testCase.verifyFalse(protocol.source.finalRowsUsedForSelection);
            testCase.verifyFalse(protocol.execution.modifyFrozenMethods);
            testCase.verifyFalse(protocol.execution.implementCandidates);
            testCase.verifyTrue(protocol.execution.pauseAfterDiagnostics);
        end

        function testDerivativeAndEquivalenceConstants(testCase)
            protocol = r50.config();

            testCase.verifyEqual(protocol.derivative.thetaStepDeg, 1e-4);
            testCase.verifyEqual(protocol.derivative.rangeStepM, 1e-3);
            testCase.verifyEqual(protocol.derivative.modeSensitivityM, ...
                [0.05, 0.10, 0.20], AbsTol=1e-12);
            testCase.verifyEqual(protocol.bootstrap.practicalEquivalence, ...
                [0.98, 1.02], AbsTol=1e-12);
        end
    end
end
