classdef testFullSpectrumTheory < matlab.unittest.TestCase
    %TESTFULLSPECTRUMTHEORY Numerical checks of the full-spectrum theory.

    properties (TestParameter)
        locationCase = struct( ...
            "interior", struct("thetaRad", deg2rad(15), "rangeM", 30), ...
            "boundary", struct("thetaRad", deg2rad(-60), "rangeM", 15), ...
            "closeRange", struct("thetaRad", deg2rad(35), "rangeM", 5))
    end

    methods (TestClassSetup)
        function addProjectToPath(testCase)
            projectFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectFolder));
        end
    end

    methods (Test)
        function test01ExactDerivativesMatchFiniteDifferences(testCase, locationCase)
            cfg = reducedConfig();
            thetaStep = 1e-6;
            rangeStep = 1e-7;

            [~, analyticDerivative] = fsjad.exactSpectralResponse( ...
                cfg, locationCase.thetaRad, locationCase.rangeM);
            qThetaPlus = fsjad.exactSpectralResponse( ...
                cfg, locationCase.thetaRad + thetaStep, locationCase.rangeM);
            qThetaMinus = fsjad.exactSpectralResponse( ...
                cfg, locationCase.thetaRad - thetaStep, locationCase.rangeM);
            qRangePlus = fsjad.exactSpectralResponse( ...
                cfg, locationCase.thetaRad, locationCase.rangeM + rangeStep);
            qRangeMinus = fsjad.exactSpectralResponse( ...
                cfg, locationCase.thetaRad, locationCase.rangeM - rangeStep);
            finiteDifference = [(qThetaPlus - qThetaMinus) / (2 * thetaStep), ...
                (qRangePlus - qRangeMinus) / (2 * rangeStep)];

            relativeError = vecnorm(analyticDerivative - finiteDifference) ...
                ./ max(vecnorm(analyticDerivative), eps);
            testCase.verifyLessThan(relativeError, [2e-7, 2e-7]);
        end

        function test02ProfileScoreIsComplexGainInvariant(testCase)
            cfg = reducedConfig();
            q = fsjad.exactSpectralResponse(cfg, deg2rad(12), 27);
            observation = q + 0.03 * exp(1i * (0:cfg.numSubcarriers - 1).' / 7);
            complexGain = 3.7 * exp(1i * 0.9);

            referenceScore = fsjad.profileScore(q, observation);
            scaledScore = fsjad.profileScore(q, complexGain * observation);

            testCase.verifyEqual(scaledScore, referenceScore, AbsTol=1e-13);
        end

        function test03ProjectedEfimMatchesSchurComplement(testCase)
            cfg = reducedConfig();
            [q, derivative] = fsjad.exactSpectralResponse(cfg, deg2rad(12), 27);
            beta = 0.8 * exp(1i * 0.4);
            noiseVariance = 0.2;
            meanDerivative = [beta * derivative, q, 1i * q];
            fullInformation = 2 / noiseVariance * real(meanDerivative' * meanDerivative);
            schurInformation = fullInformation(1:2, 1:2) ...
                - fullInformation(1:2, 3:4) ...
                / fullInformation(3:4, 3:4) * fullInformation(3:4, 1:2);

            projectedInformation = fsjad.projectedEfim( ...
                q, derivative, beta, noiseVariance);

            testCase.verifyEqual(projectedInformation, schurInformation, ...
                AbsTol=1e-9, RelTol=2e-10);
        end

        function test04IndependentCarrierGainsRemoveAllInformation(testCase)
            numObservations = 12;
            phase = (0:numObservations - 1).' / 5;
            q = exp(1i * phase);
            derivative = [sin(phase) + 1i * cos(2 * phase), ...
                cos(phase / 2) - 1i * sin(3 * phase)];
            beta = (1 + (0:numObservations - 1).' / numObservations) ...
                .* exp(-1i * phase / 3);
            nuisanceBasis = diag(q);

            information = fsjad.projectedEfim( ...
                q, derivative, beta, 0.4, nuisanceBasis);

            testCase.verifyEqual(information, zeros(2), AbsTol=1e-12);
        end

        function test05EfimEllipseContainmentAndArea(testCase)
            information = diag([4, 9]);
            confidence = 0.95;
            threshold = -2 * log(1 - confidence);
            boundaryPoint = [sqrt(threshold / 4); 0];
            outsidePoint = 1.01 * boundaryPoint;

            metrics = fsjad.efimEllipseMetrics(information, [0; 0], ...
                [[0; 0], boundaryPoint, outsidePoint], confidence);

            testCase.verifyEqual(metrics.contains, [true, true, false]);
            testCase.verifyEqual(metrics.quadraticForm(2), threshold, ...
                AbsTol=1e-12);
            testCase.verifyEqual(metrics.area, pi * threshold / 6, ...
                AbsTol=1e-12);
        end

        function test06OffGridProfileEstimateRecoversNoiselessTruth(testCase)
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            truth = [12.3, 34.2];
            observation = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(truth(1)), truth(2), scan);

            estimate = fsjad.peakInitializedProfileEstimate( ...
                cfg, observation, scan);

            testCase.verifyEqual(estimate.thetaDeg, truth(1), AbsTol=1e-6);
            testCase.verifyEqual(estimate.rangeM, truth(2), AbsTol=1e-5);
            testCase.verifyEqual(estimate.score, 1, AbsTol=1e-10);
            testCase.verifyEqual(estimate.seedResponseEvaluations, 15);
            testCase.verifyEqual(estimate.totalResponseEvaluations, ...
                estimate.seedResponseEvaluations ...
                + estimate.distanceResponseEvaluations ...
                + estimate.responseEvaluations);
        end

        function test07RelativePhaseNoiseHasRequestedRms(testCase)
            stream = RandStream("mt19937ar", Seed=17);
            rmsDeg = 5;

            phaseRad = fsjad.relativePhaseNoise(64, 3, rmsDeg, stream);

            testCase.verifyEqual(mean(phaseRad, 1), zeros(1, 3), ...
                AbsTol=1e-14);
            testCase.verifyEqual(rad2deg(sqrt(mean(phaseRad.^2, 1))), ...
                rmsDeg * ones(1, 3), AbsTol=1e-12);
        end

        function test08ZeroRelativePhaseNoiseIsZero(testCase)
            phaseRad = fsjad.relativePhaseNoise(8, 2, 0);

            testCase.verifyEqual(phaseRad, zeros(8, 2), AbsTol=0);
        end

        function test09FresnelDerivativesMatchFiniteDifferences(testCase)
            cfg = reducedConfig();
            scan = fsjad.prepareScan(cfg);
            thetaRad = deg2rad(23);
            rangeM = 18;
            thetaStep = 1e-6;
            rangeStep = 1e-7;

            [~, analyticDerivative] = fsjad.fresnelSpectralResponse( ...
                cfg, thetaRad, rangeM, scan);
            qThetaPlus = fsjad.fresnelSpectralResponse( ...
                cfg, thetaRad + thetaStep, rangeM, scan);
            qThetaMinus = fsjad.fresnelSpectralResponse( ...
                cfg, thetaRad - thetaStep, rangeM, scan);
            qRangePlus = fsjad.fresnelSpectralResponse( ...
                cfg, thetaRad, rangeM + rangeStep, scan);
            qRangeMinus = fsjad.fresnelSpectralResponse( ...
                cfg, thetaRad, rangeM - rangeStep, scan);
            finiteDifference = [(qThetaPlus - qThetaMinus) / (2 * thetaStep), ...
                (qRangePlus - qRangeMinus) / (2 * rangeStep)];

            relativeError = vecnorm(analyticDerivative - finiteDifference) ...
                ./ max(vecnorm(analyticDerivative), eps);
            testCase.verifyLessThan(relativeError, [2e-7, 2e-7]);
        end

        function test10StructuredProfileScoreFitsGainSubspace(testCase)
            phase = (0:15).' / 4;
            q = exp(1i * phase);
            gainBasis = [ones(16, 1), linspace(-1, 1, 16).'];
            coefficient = [0.8 * exp(1i * 0.2); 0.3 * exp(-1i * 0.7)];
            observation = (q .* gainBasis) * coefficient;

            score = fsjad.structuredProfileScore(q, observation, gainBasis);

            testCase.verifyEqual(score, 1, AbsTol=1e-12);
        end

        function test11LowDimensionalGainEfimMatchesSchurComplement(testCase)
            numObservations = 20;
            phase = (0:numObservations - 1).' / 6;
            q = exp(1i * phase);
            derivative = [sin(phase) + 1i * cos(2 * phase), ...
                cos(phase / 2) - 1i * sin(3 * phase)];
            gainBasis = [ones(numObservations, 1), ...
                linspace(-1, 1, numObservations).'];
            coefficient = [0.9 * exp(1i * 0.3); 0.2 * exp(-1i * 0.5)];
            beta = gainBasis * coefficient;
            nuisanceBasis = q .* gainBasis;
            noiseVariance = 0.3;
            signalDerivative = beta .* derivative;
            meanDerivative = [signalDerivative, nuisanceBasis, 1i * nuisanceBasis];
            fullInformation = 2 / noiseVariance * real(meanDerivative' * meanDerivative);
            schurInformation = fullInformation(1:2, 1:2) ...
                - fullInformation(1:2, 3:6) ...
                / fullInformation(3:6, 3:6) * fullInformation(3:6, 1:2);

            projectedInformation = fsjad.projectedEfim( ...
                q, derivative, beta, noiseVariance, nuisanceBasis);

            testCase.verifyEqual(projectedInformation, schurInformation, ...
                AbsTol=1e-10, RelTol=2e-10);
        end

        function test12ZeroWienerInnovationReturnsInput(testCase)
            spectrum = exp(1i * (0:31).' / 7);

            distorted = fsjad.applyWienerPhaseNoise(spectrum, 0);

            testCase.verifyEqual(distorted, spectrum, AbsTol=2e-15);
        end

        function test13WienerPhaseNoisePreservesEnergy(testCase)
            stream = RandStream("mt19937ar", Seed=29);
            spectrum = randn(stream, 64, 3) + 1i * randn(stream, 64, 3);

            [~, diagnostics] = fsjad.applyWienerPhaseNoise( ...
                spectrum, 0.04, stream);

            testCase.verifyEqual(diagnostics.outputEnergy, ...
                diagnostics.inputEnergy, AbsTol=2e-12, RelTol=2e-14);
        end

        function test14ConstantPhaseProducesOnlyCpe(testCase)
            spectrum = exp(1i * (0:31).' / 5);
            constantPhase = 0.73;

            [distorted, diagnostics] = fsjad.applyWienerPhaseNoise( ...
                spectrum, 0, RandStream.getGlobalStream, constantPhase);

            testCase.verifyEqual(distorted, spectrum * exp(1i * constantPhase), ...
                AbsTol=2e-15);
            testCase.verifyEqual(diagnostics.iciToUsefulRatio, 0, ...
                AbsTol=1e-29);
        end

        function test15WienerInnovationCreatesIci(testCase)
            stream = RandStream("mt19937ar", Seed=31);
            singleCarrier = zeros(64, 1);
            singleCarrier(9) = 1;

            [distorted, diagnostics] = fsjad.applyWienerPhaseNoise( ...
                singleCarrier, 0.08, stream);
            offCarrierEnergy = sum(abs(distorted([1:8, 10:64])).^2);

            testCase.verifyGreaterThan(offCarrierEnergy, 1e-6);
            testCase.verifyGreaterThan(diagnostics.iciToUsefulRatio, 1e-6);
        end

        function test16SingleRfNoiselessReconstruction(testCase)
            stream = RandStream("mt19937ar", Seed=37);
            signal = randn(stream, 16, 3) + 1i * randn(stream, 16, 3);

            reconstructed = fsjad.singleRfArrayAcquisition( ...
                signal, 0, 1, stream);

            testCase.verifyEqual(reconstructed, signal, AbsTol=2e-15);
        end

        function test17SingleRfFixedTotalEnergyPenalty(testCase)
            numAntennas = 64;
            signal = exp(1i * (0:numAntennas - 1).' / 9);
            energyScale = 1 / sqrt(numAntennas);

            [reconstructed, ~, diagnostics] = ...
                fsjad.singleRfArrayAcquisition(signal, 0, energyScale);

            testCase.verifyEqual(reconstructed, energyScale * signal, ...
                AbsTol=2e-15);
            testCase.verifyEqual(diagnostics.effectiveSnrPenaltyDb, ...
                -10 * log10(numAntennas), AbsTol=1e-14);
            testCase.verifyEqual(diagnostics.numTrainingSymbols, numAntennas);
        end

        function test18SingleRfDftCombiningPreservesScaledEnergy(testCase)
            stream = RandStream("mt19937ar", Seed=41);
            signal = randn(stream, 32, 2) + 1i * randn(stream, 32, 2);
            energyScale = 0.4;

            [~, ~, diagnostics] = fsjad.singleRfArrayAcquisition( ...
                signal, 0, energyScale, stream);

            testCase.verifyEqual( ...
                diagnostics.signalEnergyAfterCombining, ...
                energyScale^2 * diagnostics.signalEnergyBeforeCombining, ...
                AbsTol=2e-14, RelTol=2e-14);
        end

        function test19BankInitializationRecoversNoiselessOffGridTruth(testCase)
            cfg = reducedConfig();
            scan = fsjad.prepareScan(cfg);
            bank = fsjad.prepareCandidateBank(cfg, (-20:2:20).', ...
                (20:35).', scan);
            truth = [12.3, 27.4];
            observation = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(truth(1)), truth(2), scan);

            estimate = fsjad.bankInitializedProfileEstimate( ...
                cfg, observation, bank, scan, 3, 2, 1);

            testCase.verifyEqual(estimate.thetaDeg, truth(1), AbsTol=1e-6);
            testCase.verifyEqual(estimate.rangeM, truth(2), AbsTol=1e-5);
            testCase.verifyEqual(estimate.score, 1, AbsTol=1e-10);
        end

        function test20MultipleBankStartsDoNotReduceBestScore(testCase)
            cfg = reducedConfig();
            scan = fsjad.prepareScan(cfg);
            bank = fsjad.prepareCandidateBank(cfg, (-20:2:20).', ...
                (20:35).', scan);
            truthResponse = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(11.7), 27.6, scan);
            observation = truthResponse + 0.03 ...
                * exp(1i * (0:cfg.numSubcarriers - 1).' / 9);

            singleStart = fsjad.bankInitializedProfileEstimate( ...
                cfg, observation, bank, scan, 1, 2, 1);
            multipleStarts = fsjad.bankInitializedProfileEstimate( ...
                cfg, observation, bank, scan, 3, 2, 1);

            testCase.verifyGreaterThanOrEqual( ...
                multipleStarts.score, singleStart.score - 1e-14);
        end

        function test21AngleMultistartRecoversNoiselessOffGridTruth(testCase)
            cfg = reducedConfig();
            scan = fsjad.prepareScan(cfg);
            truth = [12.3, 27.4];
            observation = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(truth(1)), truth(2), scan);

            estimate = fsjad.angleMultistartProfileEstimate( ...
                cfg, observation, scan, [-0.1; 0; 0.1]);

            testCase.verifyEqual(estimate.thetaDeg, truth(1), AbsTol=1e-6);
            testCase.verifyEqual(estimate.rangeM, truth(2), AbsTol=1e-5);
            testCase.verifyEqual(estimate.score, 1, AbsTol=1e-10);
        end

        function test22MultipleAngleStartsDoNotReduceBestScore(testCase)
            cfg = reducedConfig();
            scan = fsjad.prepareScan(cfg);
            truthResponse = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(11.7), 27.6, scan);
            observation = truthResponse + 0.03 ...
                * exp(1i * (0:cfg.numSubcarriers - 1).' / 9);

            singleStart = fsjad.angleMultistartProfileEstimate( ...
                cfg, observation, scan, 0);
            multipleStarts = fsjad.angleMultistartProfileEstimate( ...
                cfg, observation, scan, [-0.1; 0; 0.1]);

            testCase.verifyGreaterThanOrEqual( ...
                multipleStarts.score, singleStart.score - 1e-14);
        end

        function test23AdaptiveSummaryPreservesTrialRowMapping(testCase)
            trials = table([-10; 0], [1; 2], [10; 20], [3; 4], ...
                [30; 40], [true; false], VariableNames=[ ...
                "snrDb", "frontAngleErrorDeg", "frontRangeErrorM", ...
                "musicAngleErrorDeg", "musicRangeErrorM", ...
                "musicBoundaryPeak"]);

            [details, summary] = fsjad.summarizeAdaptiveMethods(trials, -10);

            expectedMethods = repmat(["Full-spectrum front"; ...
                "Fixed narrow MUSIC"; ...
                "Adaptive angle-MUSIC/range-gate"], 2, 1);
            testCase.verifyEqual(details.method, expectedMethods);
            testCase.verifyEqual(details.snrDb, repelem([-10; 0], 3));
            testCase.verifyEqual(details.angleErrorDeg, [1; 3; 3; 2; 4; 4]);
            testCase.verifyEqual(details.rangeErrorM, [10; 30; 30; 20; 40; 20]);
            testCase.verifyEqual(details.boundaryPeak, ...
                [false; true; true; false; false; false]);
            testCase.verifyEqual(summary.GroupCount, ones(6, 1));
        end

        function test24MusicConfidenceFeaturesMatchSyntheticSpectrum(testCase)
            initialSpectrum = 0.1 * ones(5);
            initialSpectrum(1, 1) = 0.4;
            initialSpectrum(3, 4) = 1;
            initialSpectrum(2, 4) = 0.8;
            initialSpectrum(4, 4) = 0.7;
            initialSpectrum(3, 3) = 0.9;
            initialSpectrum(3, 5) = 0.6;
            front = struct(score=0.95, scoreGap=0.1, converged=true, ...
                thetaDeg=10, rangeM=30);
            music = struct(thetaDeg=10.2, rangeM=30.01, ...
                initialSpectrum=initialSpectrum, spectrum=initialSpectrum);

            features = fsjad.musicConfidenceFeatures(front, music);

            testCase.verifyEqual(features.rangeDeltaM, 0.01, AbsTol=1e-14);
            testCase.verifyEqual(features.absAngleDeltaDeg, 0.2, AbsTol=1e-14);
            testCase.verifyEqual(features.initialBoundaryPeak, 0);
            testCase.verifyEqual(features.initialCompetitorGap, 0.6, ...
                AbsTol=1e-14);
            testCase.verifyEqual(features.initialRangeNeighborDrop, 0.2, ...
                AbsTol=1e-14);
            testCase.verifyEqual(features.initialAngleNeighborDrop, 0.1, ...
                AbsTol=1e-14);
            testCase.verifyEqual(features.initialRangeBoundaryDistance, 0.5);
            testCase.verifyEqual(features.initialAngleBoundaryDistance, 0.25);
            testCase.verifyEqual(features.refinedCompetitorGap, ...
                features.initialCompetitorGap);
        end

        function test25OracleShrinkageMinimizesConvexDisplacement(testCase)
            frontErrorM = [1; 1; -1; -1; 2];
            rangeDeltaM = [-2; -0.5; 2; 0.5; 0];

            alpha = fsjad.oracleRangeShrinkage(frontErrorM, rangeDeltaM);
            fusedErrorM = frontErrorM + alpha .* rangeDeltaM;

            testCase.verifyEqual(alpha, [0.5; 1; 0.5; 1; 0], ...
                AbsTol=1e-14);
            testCase.verifyLessThanOrEqual(fusedErrorM.^2, ...
                min(frontErrorM.^2, ...
                (frontErrorM + rangeDeltaM).^2) + 1e-14);
        end

        function test26CovarianceShrinkageIsTruthTranslationInvariant(testCase)
            frontReplicate = [-1; 0; 1; -2; 2];
            musicReplicate = -frontReplicate;

            reference = fsjad.covarianceRangeShrinkage( ...
                frontReplicate, musicReplicate, 0);
            translated = fsjad.covarianceRangeShrinkage( ...
                frontReplicate + 30, musicReplicate + 30, 0);

            testCase.verifyEqual(reference.rawAlpha, 0.5, AbsTol=1e-14);
            testCase.verifyEqual(translated.rawAlpha, ...
                reference.rawAlpha, AbsTol=1e-14);
            testCase.verifyEqual(reference.conservativeAlpha, ...
                reference.rawAlpha, AbsTol=1e-14);
        end

        function test27SubsetProfileRecoversNoiselessLocalTruth(testCase)
            cfg = reducedConfig();
            scan = fsjad.prepareScan(cfg);
            truthThetaDeg = 12.3;
            truthRangeM = 27.4;
            observation = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(truthThetaDeg), truthRangeM, scan);
            sampleIndex = (1:4:cfg.numSubcarriers).';

            estimate = fsjad.subsetProfileEstimate(cfg, observation, ...
                sampleIndex, truthThetaDeg + 0.01, truthRangeM + 0.01, scan);

            testCase.verifyEqual(estimate.thetaDeg, truthThetaDeg, ...
                AbsTol=1e-6);
            testCase.verifyEqual(estimate.rangeM, truthRangeM, AbsTol=1e-5);
            testCase.verifyEqual(estimate.score, 1, AbsTol=1e-10);
        end

        function test28ParametricBootstrapShrinkageIsFinite(testCase)
            cfg = reducedConfig();
            cfg.subarraySize = 16;
            cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
            cfg.localHalfWidthDeg = 0.05;
            cfg.localHalfWidthM = 0.05;
            cfg.gridSizes = [21, 15];
            scan = fsjad.prepareScan(cfg);
            truthThetaDeg = 12.3;
            truthRangeM = 27.4;
            stream = RandStream("mt19937ar", Seed=411);
            response = fsjad.exactSpectralResponse(cfg, ...
                deg2rad(truthThetaDeg), truthRangeM, scan);
            observation = response + 0.1 / sqrt(2) * (randn(stream, ...
                cfg.numSubcarriers, 1) + 1i * randn(stream, ...
                cfg.numSubcarriers, 1));
            carrierIndex = (0:3:cfg.numSubcarriers - 1).';
            snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, ...
                truthRangeM, 10, carrierIndex, stream);
            front.thetaDeg = truthThetaDeg + 0.005;
            front.rangeM = truthRangeM + 0.005;
            music = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
                front.thetaDeg, front.rangeM);

            result = fsjad.parametricBootstrapShrinkage(cfg, observation, ...
                snapshots, carrierIndex, front, music, scan, 4, 9, stream);
            snrDiagnostics = fsjad.fittedSnrDiagnostics(cfg, observation, ...
                snapshots, carrierIndex, front, music, scan);

            testCase.verifySize(result.frontRangeReplicateM, [4, 1]);
            testCase.verifySize(result.musicRangeReplicateM, [4, 1]);
            testCase.verifyGreaterThanOrEqual(result.rawAlpha, 0);
            testCase.verifyLessThanOrEqual(result.rawAlpha, 1);
            testCase.verifyGreaterThanOrEqual(result.independentAlpha, 0);
            testCase.verifyLessThanOrEqual(result.independentAlpha, 1);
            testCase.verifyGreaterThanOrEqual(result.scaledRawAlpha, 0);
            testCase.verifyLessThanOrEqual(result.scaledRawAlpha, 1);
            testCase.verifyEqual(result.bootstrapCarrierCount, 9);
            testCase.verifyGreaterThanOrEqual(result.frontNoiseVariance, 0);
            testCase.verifyGreaterThanOrEqual(result.snapshotNoiseVariance, 0);
            testCase.verifyTrue(isfinite(result.frontSnrDb));
            testCase.verifyTrue(isfinite(result.snapshotSnrDb));
            testCase.verifyEqual(result.frontSnrDb, ...
                snrDiagnostics.frontSnrDb, AbsTol=1e-12);
            testCase.verifyEqual(result.snapshotSnrDb, ...
                snrDiagnostics.snapshotSnrDb, AbsTol=1e-12);
        end
    end
end

function cfg = reducedConfig()
cfg = jad.defaultConfig();
cfg.numAntennas = 32;
cfg.numSubcarriers = 64;
cfg.elementIndex = (0:cfg.numAntennas - 1).' - (cfg.numAntennas - 1) / 2;
end
