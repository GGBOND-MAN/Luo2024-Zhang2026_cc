classdef round38RawArrayVpmlTest < matlab.unittest.TestCase
    %ROUND38RAWARRAYVPMLTEST Likelihood, equivalence and bracket tests.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addR38Paths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r38", "common")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r38", "schemeF")));
        end
    end

    methods (Test)
        function concentratedScoreMatchesExplicitLeastSquares(testCase)
            [cfg, carrierIndex, snapshots, thetaDeg, rangeM] = fixture();
            context = r38PrepareRawArrayVpmlContext( ...
                cfg, snapshots, carrierIndex);
            [actual, diagnostics] = r38RawArrayVpmlScore( ...
                cfg, context, thetaDeg, rangeM);
            steering = steeringMatrix(cfg, carrierIndex, thetaDeg, rangeM);
            alpha = sum(conj(steering).*snapshots, 1);
            residual = snapshots-steering.*alpha;
            expected = 1-sum(abs(residual).^2, "all") ...
                /sum(abs(snapshots).^2, "all");

            testCase.verifyEqual(actual, expected, AbsTol=2e-14);
            testCase.verifyEqual(diagnostics.alphaHat, alpha(:), ...
                AbsTol=2e-13);
        end

        function likelihoodEqualsEnergyWeightedRankOneResidual(testCase)
            [cfg, carrierIndex, snapshots, thetaDeg, rangeM] = fixture();
            context = r38PrepareRawArrayVpmlContext( ...
                cfg, snapshots, carrierIndex);
            score = r38RawArrayVpmlScore(cfg, context, thetaDeg, rangeM);
            steering = steeringMatrix(cfg, carrierIndex, thetaDeg, rangeM);
            energy = sum(abs(snapshots).^2, 1);
            unitSnapshot = snapshots./sqrt(energy);
            musicResidual = 1-abs(sum(conj(unitSnapshot).*steering, 1)).^2;
            weightedResidual = sum(energy.*musicResidual)/sum(energy);

            testCase.verifyEqual(1-score, weightedResidual, AbsTol=2e-14);
        end

        function independentCarrierGainsAreEliminated(testCase)
            [cfg, carrierIndex, ~, thetaDeg, rangeM] = fixture();
            steering = steeringMatrix(cfg, carrierIndex, thetaDeg, rangeM);
            gain = exp(1i*(0:numel(carrierIndex)-1)).*(1: ...
                numel(carrierIndex));
            snapshots = steering.*gain;
            context = r38PrepareRawArrayVpmlContext( ...
                cfg, snapshots, carrierIndex);
            score = r38RawArrayVpmlScore(cfg, context, thetaDeg, rangeM);

            testCase.verifyEqual(score, 1, AbsTol=5e-15);
        end

        function boundedRefinementRetainsGridAndFindsContinuousPeak(testCase)
            grid = [-1, -0.5, 0, 0.5, 1];
            score = @(thetaDeg) -(thetaDeg-0.13).^2;
            result = r38BracketedVpmlRefinement(score, grid, 3);

            testCase.verifyTrue(result.converged);
            testCase.verifyEqual(result.thetaDeg, 0.13, AbsTol=1e-8);
            testCase.verifyGreaterThanOrEqual( ...
                result.scoreAfter, result.scoreBefore);
            testCase.verifyGreaterThanOrEqual( ...
                result.thetaDeg, result.bracketDeg(1));
            testCase.verifyLessThanOrEqual( ...
                result.thetaDeg, result.bracketDeg(2));
        end

        function finalGridEndpointIsRetained(testCase)
            grid = [-1, -0.5, 0, 0.5, 1];
            score = @(thetaDeg) -thetaDeg.^2;
            result = r38BracketedVpmlRefinement(score, grid, 1);

            testCase.verifyEqual(result.thetaDeg, grid(1));
            testCase.verifyFalse(result.converged);
            testCase.verifyEqual(result.functionEvaluations, 1);
            testCase.verifyEqual(result.status, ...
                "final-grid-endpoint-retained");
        end

        function protocolRestrictsDevelopmentIdentity(testCase)
            common = r38CommonProtocol();
            scheme = r38SchemeFConfig();

            testCase.verifyEqual(common.input.users, 60);
            testCase.verifyFalse(common.execution.newUsersAllowed);
            testCase.verifyFalse( ...
                common.execution.calibrationReadOrExecutionAllowed);
            testCase.verifyFalse(common.execution.r34FinalAuthorized);
            testCase.verifyEqual(scheme.gainElimination, ...
                "analytic-variable-projection");
            testCase.verifyFalse(scheme.calibrationAuthorized);
            testCase.verifyFalse(scheme.finalAuthorized);
        end
    end
end

function [cfg, carrierIndex, snapshots, thetaDeg, rangeM] = fixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 8;
cfg.numSubcarriers = 9;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
carrierIndex = (0:cfg.numSubcarriers-2).';
stream = RandStream("mt19937ar", Seed=38001);
snapshots = randn(stream, cfg.numAntennas, numel(carrierIndex)) ...
    +1i*randn(stream, cfg.numAntennas, numel(carrierIndex));
thetaDeg = 14.2;
rangeM = 31.7;
end

function steering = steeringMatrix(cfg, carrierIndex, thetaDeg, rangeM)
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
x = cfg.elementIndex*cfg.elementSpacing;
thetaRad = deg2rad(thetaDeg);
distance = rangeM-x*sin(thetaRad)+x.^2*cos(thetaRad)^2/(2*rangeM);
steering = exp(-1i*distance.*(2*pi*frequencyHz(:).'/cfg.c)) ...
    /sqrt(cfg.numAntennas);
end
