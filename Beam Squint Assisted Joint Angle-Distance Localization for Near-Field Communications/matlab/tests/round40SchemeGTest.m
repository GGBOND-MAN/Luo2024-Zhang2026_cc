classdef round40SchemeGTest < matlab.unittest.TestCase
    %ROUND40SCHEMEGTEST Mathematical and protocol tests for Scheme G.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            folders = [testCase.MatlabRoot; ...
                fullfile(testCase.MatlabRoot, "+r37", "singleProfile"); ...
                fullfile(testCase.MatlabRoot, "+r38", "common"); ...
                fullfile(testCase.MatlabRoot, "+r38", "schemeF"); ...
                fullfile(testCase.MatlabRoot, "+r40", "schemeG")];
            for folder = folders.'
                testCase.applyFixture( ...
                    matlab.unittest.fixtures.PathFixture(folder));
            end
        end
    end

    methods (Test)
        function protocolFreezesEvidenceBoundary(testCase)
            protocol = r40SchemeGProtocol();
            testCase.verifyEqual(protocol.system.N, 256);
            testCase.verifyEqual(protocol.system.K, 2047);
            testCase.verifyEqual(protocol.range.completeProfilePasses, 1);
            testCase.verifyEqual(protocol.range.newCompleteProfilePasses, 0);
            testCase.verifyFalse(protocol.execution.newUsersAllowed);
            testCase.verifyFalse(protocol.execution.r34FinalAuthorized);
            testCase.verifyFalse(protocol.execution.bracketExpansionAllowed);
            testCase.verifyFalse(protocol.execution.alternatingOptimizationAllowed);
        end

        function thetaDerivativeMatchesFiniteDifference(testCase)
            [cfg, context, thetaRad, rangeM] = arrayFixture();
            actual = r40FullArrayFresnelDerivatives( ...
                cfg, context, thetaRad, rangeM);
            step = 1e-5;
            finite = (r40FullArrayFresnelSteering( ...
                cfg, context, thetaRad+step, rangeM) ...
                -r40FullArrayFresnelSteering( ...
                cfg, context, thetaRad-step, rangeM))/(2*step);
            testCase.verifyEqual(actual.aTheta, finite, ...
                AbsTol=5e-7, RelTol=5e-8);
        end

        function rangeDerivativeMatchesFiniteDifference(testCase)
            [cfg, context, thetaRad, rangeM] = arrayFixture();
            actual = r40FullArrayFresnelDerivatives( ...
                cfg, context, thetaRad, rangeM);
            step = 1e-6;
            finite = (r40FullArrayFresnelSteering( ...
                cfg, context, thetaRad, rangeM+step) ...
                -r40FullArrayFresnelSteering( ...
                cfg, context, thetaRad, rangeM-step))/(2*step);
            testCase.verifyEqual(actual.aRange, finite, ...
                AbsTol=2e-5, RelTol=2e-6);
        end

        function concentratedGradientMatchesFiniteDifference(testCase)
            [cfg, context, thetaRad, rangeM] = arrayFixture();
            actual = r40VariableProjectionLinearization( ...
                cfg, context, thetaRad, rangeM);
            thetaStep = 1e-6;
            rangeStep = 1e-3;
            finite = [(r40ConcentratedCost(cfg, context, ...
                thetaRad+thetaStep, rangeM)-r40ConcentratedCost( ...
                cfg, context, thetaRad-thetaStep, rangeM))/(2*thetaStep); ...
                (r40ConcentratedCost(cfg, context, thetaRad, ...
                rangeM+rangeStep)-r40ConcentratedCost(cfg, context, ...
                thetaRad, rangeM-rangeStep))/(2*rangeStep)];
            testCase.verifyEqual(actual.gradient, finite, ...
                AbsTol=2e-7, RelTol=2e-5);
        end

        function gnGradientHasDescentSign(testCase)
            [cfg, context, thetaRad, rangeM] = arrayFixture();
            linear = r40VariableProjectionLinearization( ...
                cfg, context, thetaRad, rangeM);
            direction = -linear.gradient/norm(linear.gradient);
            scale = [1e-7; 1e-4];
            displacement = direction.*scale;
            plus = r40ConcentratedCost(cfg, context, ...
                thetaRad+displacement(1), rangeM+displacement(2));
            minus = r40ConcentratedCost(cfg, context, ...
                thetaRad-displacement(1), rangeM-displacement(2));
            directionalFinite = (plus-minus)/2;
            directionalPredicted = linear.gradient.'*displacement;
            testCase.verifyLessThan(directionalPredicted, 0);
            testCase.verifyEqual(directionalFinite, ...
                directionalPredicted, AbsTol=2e-8, RelTol=2e-4);
        end

        function schurComplementMatchesTwoByTwoSolve(testCase)
            gradient = [1.7; -0.4];
            information = [8.0, 1.3; 1.3, 3.2];
            actual = r40LocalStepScalars(gradient, information);
            joint = -information\gradient;
            testCase.verifyTrue(actual.schurValid);
            testCase.verifyEqual(actual.schurRawStepRad, joint(1), ...
                AbsTol=2e-15);
            testCase.verifyEqual(actual.effectiveInformation, ...
                information(1, 1)-information(1, 2)^2/information(2, 2), ...
                AbsTol=2e-15);
        end

        function fixedEqualsSchurWhenCrossInformationIsZero(testCase)
            actual = r40LocalStepScalars([0.7; 4.2], [6, 0; 0, 2]);
            testCase.verifyTrue(actual.fixedValid);
            testCase.verifyTrue(actual.schurValid);
            testCase.verifyEqual(actual.fixedRawStepRad, ...
                actual.schurRawStepRad, AbsTol=2e-15);
        end

        function concentratedCostMatchesFrozenSchemeF(testCase)
            [cfg, context, thetaRad, rangeM] = arrayFixture();
            actual = r40ConcentratedCost( ...
                cfg, context, thetaRad, rangeM);
            expected = 1-r38RawArrayVpmlScore( ...
                cfg, context, rad2deg(thetaRad), rangeM);
            testCase.verifyEqual(actual, expected, AbsTol=3e-15);
        end

        function qProfileDerivativeAndTransportRemainFrozen(testCase)
            cfg = jad.defaultConfig();
            cfg.numAntennas = 32;
            cfg.numSubcarriers = 63;
            cfg.elementIndex = (0:31).'-15.5;
            scan = fsjad.prepareScan(cfg);
            thetaRad = deg2rad(14.2);
            rangeM = 28.6;
            observation = fsjad.exactSpectralResponse( ...
                cfg, thetaRad+deg2rad(0.002), rangeM+0.01, scan);
            context = r33.prepareResponseContext(cfg, scan, observation);
            derivative = r37ExactProfileLogDerivatives( ...
                cfg, thetaRad, rangeM, context);
            rangeStep = 1e-4;
            score = @(range) r33.fixedAngleProfileLogScore( ...
                cfg, rad2deg(thetaRad), range, context);
            finiteRangeGradient = (score(rangeM+rangeStep) ...
                -score(rangeM-rangeStep))/(2*rangeStep);
            testCase.verifyEqual(derivative.gradient(2), ...
                finiteRangeGradient, AbsTol=2e-5, RelTol=2e-5);
            transport = r37ImplicitProfileTransport(cfg, scan, ...
                observation, rad2deg(thetaRad), rangeM, ...
                rad2deg(thetaRad)+1e-4, rangeM);
            testCase.verifyEqual(transport.completeProfilePassCount, 1);
            testCase.verifyEqual(transport.newCompleteProfilePassCount, 0);
        end

        function implementationContainsNoForbiddenSearch(testCase)
            folder = fullfile(testCase.MatlabRoot, "+r40", "schemeG");
            files = dir(fullfile(folder, "*.m"));
            source = "";
            for index = 1:numel(files)
                source = source+newline+string(fileread( ...
                    fullfile(files(index).folder, files(index).name)));
            end
            testCase.verifyFalse(contains(lower(source), "fminbnd("));
            testCase.verifyFalse(contains(lower(source), "profileatangle("));
            testCase.verifyFalse(contains(lower(source), ...
                "i_explicitly_authorize_r34_final_1400"));
            testCase.verifyFalse(contains(lower(source), "usegram=true"));
        end

        function completedResultsPreserveBaselineAndProfileIdentity(testCase)
            root = fullfile(testCase.MatlabRoot, "results", ...
                "full_spectrum", ...
                "round40_schemeG_full_aperture_profiled_v1");
            files = [fullfile(root, "result.mat"), ...
                fullfile(root, "calibration600", "result.mat")];
            expectedRows = [60, 600];
            for index = 1:numel(files)
                testCase.assertTrue(isfile(files(index)), ...
                    "A required completed Scheme G result is missing.");
                loaded = load(files(index), "identity", ...
                    "design", "results");
                testCase.verifyEqual(height(loaded.design), ...
                    expectedRows(index));
                testCase.verifyEqual( ...
                    loaded.identity.finalTrialsReadOrExecuted, 0);
                testCase.verifyEqual(loaded.identity.newUsersGenerated, 0);
                testCase.verifyTrue(all(cellfun( ...
                    @(x) x.success && x.baselineIdentity.pass, ...
                    loaded.results)));
                testCase.verifyEqual(cellfun( ...
                    @(x) x.G_fixed.completeProfilePassCount, ...
                    loaded.results), ones(expectedRows(index), 1));
                testCase.verifyEqual(cellfun( ...
                    @(x) x.G_schur.completeProfilePassCount, ...
                    loaded.results), ones(expectedRows(index), 1));
                maximumDifference = max(cellfun(@(x) max([ ...
                    x.baselineIdentity.thetaDifferencePA, ...
                    x.baselineIdentity.rangeDifferencePA, ...
                    x.baselineIdentity.thetaDifferenceC, ...
                    x.baselineIdentity.rangeDifferenceC, ...
                    x.baselineIdentity.finalGridMaximumDifferenceDeg]), ...
                    loaded.results));
                testCase.verifyLessThanOrEqual(maximumDifference, ...
                    r40SchemeGProtocol().numerical.rangeIdentityToleranceM);
            end
        end
    end
end

function [cfg, context, thetaRad, rangeM] = arrayFixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 24;
cfg.numSubcarriers = 17;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
carrierIndex = (0:cfg.numSubcarriers-2).';
stream = RandStream("mt19937ar", Seed=4001);
snapshots = randn(stream, cfg.numAntennas, numel(carrierIndex)) ...
    +1i*randn(stream, cfg.numAntennas, numel(carrierIndex));
context = r38PrepareRawArrayVpmlContext( ...
    cfg, snapshots, carrierIndex);
thetaRad = deg2rad(11.2);
rangeM = 31.4;
end
