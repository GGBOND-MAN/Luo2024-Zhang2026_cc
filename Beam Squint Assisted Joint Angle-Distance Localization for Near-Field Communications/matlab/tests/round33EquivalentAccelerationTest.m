classdef round33EquivalentAccelerationTest < matlab.unittest.TestCase
    %ROUND33EQUIVALENTACCELERATIONTEST Test the two frozen fast kernels.

    methods (Test)
        function qAndDerivativesMatchReference(testCase)
            [cfg, scan, context] = responseFixture();
            [referenceQ, referenceDerivative] = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(12.3), 27.4, scan);
            [fastQ, fastDerivative] = r33.exactSpectralResponse( ...
                cfg, deg2rad(12.3), 27.4, context);
            tolerance = r33.config().validation;
            testCase.verifyEqual(fastQ, referenceQ, ...
                AbsTol=tolerance.qAbsoluteTolerance);
            testCase.verifyEqual(fastDerivative, referenceDerivative, ...
                AbsTol=tolerance.derivativeAbsoluteTolerance);
        end

        function qOnlyProfileScoreMatchesReference(testCase)
            [cfg, ~, context] = responseFixture();
            q = r33.exactSpectralResponse(cfg, deg2rad(-18.7), 31.2, context);
            reference = fsjad.profileScore(q, context.observation);
            fast = r33.profileScore(q, context);
            testCase.verifyEqual(fast, reference, AbsTol=1e-14);
        end

        function gramVectorMatchesDirectProjector(testCase)
            stream = RandStream("mt19937ar", Seed=7701);
            aligned = randn(stream, 160, 97) ...
                + 1i*randn(stream, 160, 97);
            [direct, directInfo] = r33.principalVector( ...
                aligned, r33.config().gram, UseGram=false);
            [gram, gramInfo] = r33.principalVector( ...
                aligned, r33.config().gram, UseGram=true);
            projectionDifference = abs(1-abs(direct'*gram)^2);
            eigenvalueDifference = abs(directInfo.maximumEigenvalue ...
                - gramInfo.maximumEigenvalue)/directInfo.maximumEigenvalue;
            testCase.verifyLessThanOrEqual(projectionDifference, 1e-10);
            testCase.verifyLessThanOrEqual(eigenvalueDifference, 1e-10);
            testCase.verifyLessThanOrEqual(gramInfo.relativeResidual, 1e-10);
            testCase.verifyFalse(gramInfo.fallback);
        end

        function nearZeroGramFallsBack(testCase)
            aligned = complex(zeros(4, 3));
            [~, diagnostics] = r33.principalVector( ...
                aligned, r33.config().gram, UseGram=true);
            testCase.verifyTrue(diagnostics.fallback);
            testCase.verifyEqual(diagnostics.method, ...
                "gram-fallback-full-covariance-eig");
            testCase.verifyEqual(diagnostics.fallbackReason, ...
                "near-degenerate-leading-eigenvalues");
        end

        function nearDegenerateGramFallsBack(testCase)
            aligned = [diag([1, 1-1e-12, 0]); zeros(1, 3)];
            [~, diagnostics] = r33.principalVector( ...
                aligned, r33.config().gram, UseGram=true);
            testCase.verifyTrue(diagnostics.fallback);
            testCase.verifyEqual(diagnostics.fallbackReason, ...
                "near-degenerate-leading-eigenvalues");
        end

        function gramIsNotUsedWhenItIsLarger(testCase)
            stream = RandStream("mt19937ar", Seed=7702);
            aligned = randn(stream, 4, 5)+1i*randn(stream, 4, 5);
            [~, diagnostics] = r33.principalVector( ...
                aligned, r33.config().gram, UseGram=true);
            testCase.verifyEqual(diagnostics.method, "direct-smaller-side");
            testCase.verifyFalse(diagnostics.fallback);
            testCase.verifyEqual(diagnostics.matrixOrder, 4);
        end

        function precomputedDirectStateMatchesLegacy(testCase)
            [cfg, snapshots, carrierIndex] = stateFixture();
            [legacy, ~] = r30.prepareMusicState(cfg, snapshots, ...
                carrierIndex, 7.5, 24.0, 5);
            [fast, ~] = r33.prepareMusicState(cfg, snapshots, ...
                carrierIndex, 7.5, 24.0, 5, r33.config().gram, ...
                UseGram=false);
            projection = sum(conj(legacy.signalVectors) ...
                .*fast.signalVectors, 1);
            testCase.verifyLessThanOrEqual( ...
                max(abs(1-abs(projection).^2)), 1e-10);
        end

        function precomputedGramStateMatchesLegacy(testCase)
            [cfg, snapshots, carrierIndex] = stateFixture();
            [legacy, ~] = r30.prepareMusicState(cfg, snapshots, ...
                carrierIndex, 7.5, 24.0, 5);
            [fast, ~, cost] = r33.prepareMusicState(cfg, snapshots, ...
                carrierIndex, 7.5, 24.0, 5, r33.config().gram, ...
                UseGram=true);
            projection = sum(conj(legacy.signalVectors) ...
                .*fast.signalVectors, 1);
            testCase.verifyLessThanOrEqual( ...
                max(abs(1-abs(projection).^2)), 1e-10);
            testCase.verifyEqual(cost.gramSuccessCount, numel(carrierIndex));
            testCase.verifyEqual(cost.fallbackCount, 0);
        end

        function searchReductionIsSeparatedFromRuntime(testCase)
            gridC = sum(r32.config().enhancedC.gridSizes.^2);
            gridA = sum(r32.config().music.gridSizes);
            reduction = 1-gridA/gridC;
            testCase.verifyEqual(gridC, 3083);
            testCase.verifyEqual(gridA, 93);
            testCase.verifyEqual(reduction, 0.969834576710996, ...
                AbsTol=1e-15);
        end
    end
end

function [cfg, scan, context] = responseFixture()
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
stream = RandStream("mt19937ar", Seed=7700);
observation = randn(stream, cfg.numSubcarriers, 1) ...
    + 1i*randn(stream, cfg.numSubcarriers, 1);
context = r33.prepareResponseContext(cfg, scan, observation);
end

function [cfg, snapshots, carrierIndex] = stateFixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 8;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
carrierIndex = (0:3).';
stream = RandStream("mt19937ar", Seed=7703);
snapshots = randn(stream, cfg.numAntennas, numel(carrierIndex)) ...
    + 1i*randn(stream, cfg.numAntennas, numel(carrierIndex));
end
