classdef round42SchemeHTest < matlab.unittest.TestCase
    %ROUND42SCHEMEHTEST Unit tests for the PA-free joint estimator.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r38", "schemeF")));
        end
    end

    methods (Test)
        function protocolFreezesFinalDataBoundary(testCase)
            protocol = r42.config();
            testCase.verifyFalse(protocol.execution.r34FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.r41FinalReadAllowed);
            testCase.verifyEqual(protocol.execution.finalTrialsExecuted, 0);
            testCase.verifyFalse(protocol.execution.parameterTuningFromPilotAllowed);
            testCase.verifyEqual(protocol.joint.numStarts, 3);
        end

        function developmentDesignIsNewAndBalanced(testCase)
            design = r42.design(10);
            counts = groupcounts(design, "snrDb");
            testCase.verifyEqual(height(design), 30);
            testCase.verifyEqual(counts.GroupCount, 10*ones(3, 1));
            testCase.verifyEqual(numel(unique(design.seed)), 30);
            testCase.verifyGreaterThan(min(design.seed), 56100000);
        end

        function jointGradientMatchesFiniteDifference(testCase)
            [cfg, context, thetaDeg, rangeM] = smallFixture();
            protocol = r42.config();
            testCase.verifyEqual(context.numAntennas, cfg.numAntennas);
            testCase.verifyEqual(context.totalEnergy, ...
                sum(context.snapshotEnergy), AbsTol=1e-12);
            state = r42.blockState( ...
                cfg, context, deg2rad(thetaDeg), rangeM, protocol);
            thetaStepRad = 1e-7;
            rangeStepM = 1e-4;
            thetaFinite = (r42.jointCost(cfg, context, ...
                rad2deg(deg2rad(thetaDeg)+thetaStepRad), rangeM, protocol) ...
                -r42.jointCost(cfg, context, ...
                rad2deg(deg2rad(thetaDeg)-thetaStepRad), rangeM, protocol)) ...
                /(2*thetaStepRad);
            rangeFinite = (r42.jointCost(cfg, context, thetaDeg, ...
                rangeM+rangeStepM, protocol)-r42.jointCost( ...
                cfg, context, thetaDeg, rangeM-rangeStepM, protocol)) ...
                /(2*rangeStepM);
            testCase.verifyEqual(state.gradient, ...
                [thetaFinite; rangeFinite], AbsTol=2e-5, RelTol=2e-4);
        end

        function jointRefinementIsMonotoneAndPhysical(testCase)
            [cfg, context, thetaDeg, rangeM] = smallFixture();
            result = r42.refineJoint( ...
                cfg, context, thetaDeg+0.03, rangeM+0.25);
            testCase.verifyLessThanOrEqual(result.cost, result.initialCost+1e-12);
            testCase.verifyGreaterThanOrEqual(result.thetaDeg, cfg.thetaLimitsDeg(1));
            testCase.verifyLessThanOrEqual(result.thetaDeg, cfg.thetaLimitsDeg(2));
            testCase.verifyGreaterThanOrEqual(result.rangeM, cfg.rangeLimitsM(1));
            testCase.verifyLessThanOrEqual(result.rangeM, cfg.rangeLimitsM(2));
        end

        function estimatorContainsNoPaExecution(testCase)
            file = fullfile(testCase.MatlabRoot, "+r42", "estimate.m");
            source = lower(string(fileread(file)));
            testCase.verifyFalse(contains(source, "estimatepa("));
            testCase.verifyFalse(contains(source, "r34.estimate"));
            testCase.verifyFalse(contains(source, "gfrompa"));
        end
    end
end

function [cfg, context, thetaDeg, rangeM] = smallFixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 24;
cfg.numSubcarriers = 33;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
scan = fsjad.prepareScan(cfg);
thetaDeg = 12.4;
rangeM = 28.7;
stream = RandStream("mt19937ar", Seed=42001);
q = fsjad.exactSpectralResponse(cfg, deg2rad(thetaDeg), rangeM, scan);
observation = q+0.02/sqrt(2)*(randn(stream, cfg.numSubcarriers, 1) ...
    +1i*randn(stream, cfg.numSubcarriers, 1));
carrierIndex = (0:cfg.numSubcarriers-2).';
snapshots = jad.simulateSnapshots( ...
    cfg, thetaDeg, rangeM, 20, carrierIndex, stream);
context = r42.prepareContext(cfg, scan, observation, snapshots, carrierIndex);
end
