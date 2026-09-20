classdef algorithmEstimateTest < matlab.unittest.TestCase
    %ALGORITHMESTIMATETEST Tests public algorithm estimation entry points.

    properties
        MatlabFolder
    end

    methods (TestClassSetup)
        function addAlgorithmPaths(testCase)
            testCase.MatlabFolder = fileparts(fileparts( ...
                mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabFolder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabFolder, "algorithms", "full")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabFolder, ...
                "algorithms", "compressed")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabFolder, ...
                "algorithms", "zhang_reproduction")));
        end
    end

    methods (Test)
        function testFullEstimateNoiseless(testCase)
            [cfg, observation, snapshots, carrierIndex, scan, algorithm] = ...
                compactFixture("full-test");

            result = fsjadFullEstimate(cfg, observation, snapshots, ...
                carrierIndex, scan, algorithm);

            testCase.verifyEqual(result.version, "full-test");
            testCase.verifyTrue(isfinite(result.thetaDeg));
            testCase.verifyTrue(isfinite(result.rangeM));
            testCase.verifyGreaterThanOrEqual( ...
                result.rangeM, cfg.rangeLimitsM(1));
            testCase.verifyLessThanOrEqual( ...
                result.rangeM, cfg.rangeLimitsM(2));
        end

        function testCompressedEstimateIsReproducible(testCase)
            [cfg, observation, snapshots, carrierIndex, scan, algorithm] = ...
                compactFixture("compressed-test");

            first = fsjadCompressedEstimate(cfg, observation, snapshots, ...
                carrierIndex, scan, algorithm);
            second = fsjadCompressedEstimate(cfg, observation, snapshots, ...
                carrierIndex, scan, algorithm);

            testCase.verifyEqual(first.thetaDeg, second.thetaDeg, ...
                AbsTol=1e-12);
            testCase.verifyEqual(first.rangeM, second.rangeM, ...
                AbsTol=1e-12);
            testCase.verifyEqual(first.version, "compressed-test");
        end

        function testCompressedCarrierMismatchErrors(testCase)
            [cfg, observation, snapshots, carrierIndex, scan, algorithm] = ...
                compactFixture("compressed-test");
            algorithm.fusionCarrierCount = numel(carrierIndex) + 2;
            operation = @() fsjadCompressedEstimate(cfg, observation, ...
                snapshots, carrierIndex, scan, algorithm);

            testCase.verifyError(operation, ...
                "fsjadCompressed:CarrierCount");
        end

        function testZhangEstimateMatchesItsMusicOutput(testCase)
            [cfg, observation, snapshots, carrierIndex, scan, algorithm] = ...
                compactFixture("zhang-test");
            algorithm.subarraySize = cfg.subarraySize;
            algorithm.localHalfWidthDeg = cfg.localHalfWidthDeg;
            algorithm.localHalfWidthM = cfg.localHalfWidthM;

            result = zhangEfEstimate(cfg, observation, snapshots, ...
                carrierIndex, scan, algorithm);

            testCase.verifyEqual(result.thetaDeg, result.music.thetaDeg, ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.rangeM, result.music.rangeM, ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.version, "zhang-test");
        end

        function testZhangCarrierMismatchErrors(testCase)
            [cfg, observation, snapshots, carrierIndex, scan, algorithm] = ...
                compactFixture("zhang-test");
            algorithm.subarraySize = cfg.subarraySize;
            algorithm.localHalfWidthDeg = cfg.localHalfWidthDeg;
            algorithm.localHalfWidthM = cfg.localHalfWidthM;
            algorithm.fusionCarrierCount = numel(carrierIndex) + 2;
            operation = @() zhangEfEstimate(cfg, observation, snapshots, ...
                carrierIndex, scan, algorithm);

            testCase.verifyError(operation, "zhangEf:CarrierCount");
        end
    end
end

function [cfg, observation, snapshots, carrierIndex, scan, algorithm] = ...
    compactFixture(version)
cfg = jad.defaultConfig();
cfg.numAntennas = 32;
cfg.numSubcarriers = 128;
cfg.subarraySize = 16;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.elementIndex = (0:cfg.numAntennas - 1).' ...
    - (cfg.numAntennas - 1) / 2;
scan = fsjad.prepareScan(cfg);
truthThetaDeg = 15;
truthRangeM = 30;
observation = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(truthThetaDeg), truthRangeM, scan);
[~, peakPosition] = max(abs(observation).^2);
carrierIndex = fixedCountWindow(peakPosition - 1, 9, cfg.numSubcarriers);
stream = RandStream("mt19937ar", Seed=20260902);
snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, truthRangeM, ...
    100, carrierIndex, stream);
algorithm.version = version;
algorithm.fusionCarrierCount = 9;
algorithm.gridSizes = [11, 9, 7];
algorithm.frontOffsetsDeg = [-0.1; 0; 0.1];
algorithm.profileHalfWidthM = 1;
algorithm.profileSpacingM = 0.25;
algorithm.profileLambda = 0.9;
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end
