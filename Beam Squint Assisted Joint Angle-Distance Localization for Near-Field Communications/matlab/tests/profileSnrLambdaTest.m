classdef profileSnrLambdaTest < matlab.unittest.TestCase
    %PROFILESNRLAMBDATEST Tests for truth-free profile shrinkage release.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            sourceFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(sourceFolder));
        end
    end

    methods (Test)
        function testLowSnrApproachesLowLambda(testCase)
            lambda = fsjad.profileSnrLambda(-100, 0.9, -5, 1);

            testCase.verifyEqual(lambda, 0.9, AbsTol=1e-12);
        end

        function testHighSnrApproachesFullProfile(testCase)
            lambda = fsjad.profileSnrLambda(100, 0.9, -5, 1);

            testCase.verifyEqual(lambda, 1, AbsTol=1e-12);
        end

        function testMonotoneAndBounded(testCase)
            lambda = fsjad.profileSnrLambda( ...
                (-20:5:20).', 0.75, -5, 2);

            testCase.verifyGreaterThanOrEqual(lambda, 0.75);
            testCase.verifyLessThanOrEqual(lambda, 1);
            testCase.verifyGreaterThanOrEqual(diff(lambda), 0);
        end

        function testInvalidLowLambdaErrors(testCase)
            operation = @() fsjad.profileSnrLambda(0, 1.1, -5, 2);

            testCase.verifyError(operation, ...
                "fsjad:profileSnrLambda:InvalidLowLambda");
        end

        function testInvalidSlopeErrors(testCase)
            operation = @() fsjad.profileSnrLambda(0, 0.9, -5, 0);

            testCase.verifyError(operation, ...
                "fsjad:profileSnrLambda:InvalidSlope");
        end
    end
end
