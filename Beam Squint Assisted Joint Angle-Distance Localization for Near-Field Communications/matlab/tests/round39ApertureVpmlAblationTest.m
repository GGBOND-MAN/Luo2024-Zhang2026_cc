classdef round39ApertureVpmlAblationTest < matlab.unittest.TestCase
    %ROUND39APERTUREVPMLABLATIONTEST Factorial score identity tests.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addR39Paths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r38", "common")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r38", "schemeF")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r39", "common")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r39", "ablation")));
        end
    end

    methods (Test)
        function fullApertureVpmlMatchesFrozenSchemeFScore(testCase)
            [cfg, snapshots, carrierIndex, thetaDeg, rangeM] = fixture();
            contextR39 = r39PrepareProjectionContext( ...
                cfg, snapshots, carrierIndex, cfg.numAntennas);
            contextR38 = r38PrepareRawArrayVpmlContext( ...
                cfg, snapshots, carrierIndex);
            actual = r39ProjectionScore( ...
                contextR39, thetaDeg, rangeM, "vpml");
            expected = r38RawArrayVpmlScore( ...
                cfg, contextR38, thetaDeg, rangeM);

            testCase.verifyEqual(actual, expected, AbsTol=2e-15);
        end

        function uniformProjectionGivesEqualCarrierInfluence(testCase)
            [cfg, snapshots, carrierIndex, thetaDeg, rangeM] = fixture();
            context = r39PrepareProjectionContext( ...
                cfg, snapshots, carrierIndex, 8);
            [score, diagnostics] = r39ProjectionScore( ...
                context, thetaDeg, rangeM, "uniform");

            testCase.verifyEqual(score, mean(diagnostics.carrierScore), ...
                AbsTol=2e-15);
        end

        function centralL160MatchesFrozenReferenceStart(testCase)
            cfg = jad.defaultConfig();
            snapshots = complex(ones(cfg.numAntennas, 3));
            context = r39PrepareProjectionContext( ...
                cfg, snapshots, (0:2).', 160);
            referenceStart = floor((cfg.numAntennas-160+1+1)/2);

            testCase.verifyEqual(context.startIndex, referenceStart);
            testCase.verifyEqual(context.elementRows([1, end]), [49; 208]);
        end

        function protocolFreezesTwoByTwoAndNoCalibration(testCase)
            protocol = r39AblationProtocol();

            testCase.verifyEqual(protocol.factor.apertureSizes, [160, 256]);
            testCase.verifyEqual(protocol.factor.aggregations, ...
                ["uniform", "vpml"]);
            testCase.verifyEqual(numel(protocol.factor.executedVariants), 3);
            testCase.verifyFalse(protocol.execution.newUsersAllowed);
            testCase.verifyFalse( ...
                protocol.execution.calibrationReadForEstimationAllowed);
            testCase.verifyFalse(protocol.execution.r34FinalAuthorized);
            testCase.verifyFalse(protocol.execution.methodPromotionAuthorized);
        end
    end
end

function [cfg, snapshots, carrierIndex, thetaDeg, rangeM] = fixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 12;
cfg.numSubcarriers = 9;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
carrierIndex = (0:cfg.numSubcarriers-2).';
stream = RandStream("mt19937ar", Seed=39001);
snapshots = randn(stream, cfg.numAntennas, numel(carrierIndex)) ...
    +1i*randn(stream, cfg.numAntennas, numel(carrierIndex));
thetaDeg = 11.3;
rangeM = 30.2;
end
