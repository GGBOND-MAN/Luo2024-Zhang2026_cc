classdef snrReleasedAlphaTest < matlab.unittest.TestCase
    %SNRRELEASEDALPHATEST Tests for the truth-free release mapping.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            sourceFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(sourceFolder));
        end
    end

    methods (Test)
        function testLowSnrSaturatesExactly(testCase)
            snrDb = [-10; -5; 0];

            alpha = fsjad.snrReleasedAlpha(snrDb, -7, 2, -5);

            testCase.verifyEqual(alpha(1:2), ones(2, 1), AbsTol=0);
            testCase.verifyLessThan(alpha(3), 0.1);
        end

        function testBaseAlphaIsPreservedAtHighSnr(testCase)
            snrDb = 100;
            baseAlpha = 0.25;

            alpha = fsjad.snrReleasedAlpha( ...
                snrDb, -7, 2, -5, baseAlpha);

            testCase.verifyEqual(alpha, baseAlpha, AbsTol=1e-12);
        end

        function testMismatchedSizeErrors(testCase)
            operation = @() fsjad.snrReleasedAlpha( ...
                [-10; 0], -7, 2, -5, 0.5);

            testCase.verifyError(operation, "fsjad:AlphaSizeMismatch");
        end
    end
end
