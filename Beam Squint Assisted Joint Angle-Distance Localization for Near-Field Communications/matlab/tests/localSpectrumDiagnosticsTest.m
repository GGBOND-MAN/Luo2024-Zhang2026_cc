classdef localSpectrumDiagnosticsTest < matlab.unittest.TestCase
    %LOCALSPECTRUMDIAGNOSTICSTEST Tests for local curvature diagnostics.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            sourceFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(sourceFolder));
        end
    end

    methods (Test)
        function testTiltedGaussianCurvature(testCase)
            thetaGridDeg = -1:0.1:1;
            rangeGridM = 1:0.1:3;
            [theta, range] = meshgrid(thetaGridDeg, rangeGridM);
            centeredRange = range - 2;
            correlation = 0.4;
            spectrum = exp(-0.5 * (theta.^2 ...
                + 2 * correlation * theta .* centeredRange ...
                + centeredRange.^2));

            diagnostics = jad.localSpectrumDiagnostics( ...
                spectrum, thetaGridDeg, rangeGridM);

            testCase.verifyFalse(diagnostics.thetaBoundary);
            testCase.verifyFalse(diagnostics.rangeBoundary);
            testCase.verifyTrue(diagnostics.locallyConcave);
            testCase.verifyEqual(diagnostics.curvatureCoupling, ...
                correlation, AbsTol=1e-10);
            testCase.verifyEqual(diagnostics.ridgeSlopeMPerDeg, ...
                -correlation, AbsTol=1e-10);
        end

        function testBoundaryPeakHasNoCentralHessian(testCase)
            thetaGridDeg = -1:1;
            rangeGridM = 1:3;
            spectrum = reshape(1:9, 3, 3);

            diagnostics = jad.localSpectrumDiagnostics( ...
                spectrum, thetaGridDeg, rangeGridM);

            testCase.verifyTrue(diagnostics.thetaBoundary);
            testCase.verifyTrue(diagnostics.rangeBoundary);
            testCase.verifyTrue(all(isnan(diagnostics.hessian), "all"));
        end

        function testGridSizeMismatchErrors(testCase)
            operation = @() jad.localSpectrumDiagnostics( ...
                ones(2), -1:1, 1:2);

            testCase.verifyError(operation, ...
                "jad:SpectrumGridSizeMismatch");
        end
    end
end
