classdef profileRangeAtAngleTest < matlab.unittest.TestCase
    %PROFILERANGEATANGLETEST Tests for fixed-angle range profiling.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            sourceFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(sourceFolder));
        end
    end

    methods (Test)
        function testNoiselessRecoveryAtKnownAngle(testCase)
            [cfg, scan] = compactConfiguration();
            truthThetaDeg = 15;
            truthRangeM = 30;
            observation = exp(1i * 0.7) * fsjad.exactSpectralResponse( ...
                cfg, deg2rad(truthThetaDeg), truthRangeM, scan);
            rangeSeedsM = (29:0.25:31).';

            estimate = fsjad.profileRangeAtAngle(cfg, observation, ...
                truthThetaDeg, scan, rangeSeedsM);

            testCase.verifyEqual(estimate.thetaDeg, ...
                truthThetaDeg, AbsTol=1e-12);
            testCase.verifyEqual(estimate.rangeM, ...
                truthRangeM, AbsTol=1e-4);
            testCase.verifyGreaterThan(estimate.score, 1 - 1e-10);
        end

        function testEstimateRemainsInsideSearchInterval(testCase)
            [cfg, scan] = compactConfiguration();
            observation = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(15), 30, scan);
            rangeSeedsM = [29.8; 29.9];

            estimate = fsjad.profileRangeAtAngle( ...
                cfg, observation, 15, scan, rangeSeedsM);

            testCase.verifyGreaterThanOrEqual( ...
                estimate.rangeM, rangeSeedsM(1));
            testCase.verifyLessThanOrEqual( ...
                estimate.rangeM, rangeSeedsM(end));
        end

        function testEmptyObservationErrors(testCase)
            [cfg, scan] = compactConfiguration();
            operation = @() fsjad.profileRangeAtAngle( ...
                cfg, complex(zeros(0, 1)), 15, scan, [29; 31]);

            testCase.verifyError(operation, ...
                "fsjad:profileRangeAtAngle:EmptyObservation");
        end

        function testOutOfBoundsAngleErrors(testCase)
            [cfg, scan] = compactConfiguration();
            observation = ones(cfg.numSubcarriers, 1);
            operation = @() fsjad.profileRangeAtAngle( ...
                cfg, observation, 61, scan, [29; 31]);

            testCase.verifyError(operation, ...
                "fsjad:profileRangeAtAngle:AngleOutOfBounds");
        end

        function testUnorderedRangeSeedsError(testCase)
            [cfg, scan] = compactConfiguration();
            observation = ones(cfg.numSubcarriers, 1);
            operation = @() fsjad.profileRangeAtAngle( ...
                cfg, observation, 15, scan, [30; 29]);

            testCase.verifyError(operation, ...
                "fsjad:profileRangeAtAngle:InvalidRangeSeeds");
        end

        function testOutOfBoundsRangeSeedsError(testCase)
            [cfg, scan] = compactConfiguration();
            observation = ones(cfg.numSubcarriers, 1);
            operation = @() fsjad.profileRangeAtAngle( ...
                cfg, observation, 15, scan, [14; 16]);

            testCase.verifyError(operation, ...
                "fsjad:profileRangeAtAngle:RangeOutOfBounds");
        end
    end
end

function [cfg, scan] = compactConfiguration()
cfg = jad.defaultConfig();
cfg.numAntennas = 32;
cfg.numSubcarriers = 128;
cfg.elementIndex = (0:cfg.numAntennas - 1).' ...
    - (cfg.numAntennas - 1) / 2;
scan = fsjad.prepareScan(cfg);
end
