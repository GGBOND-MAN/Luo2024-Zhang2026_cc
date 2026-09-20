function run_low_snr_ellipse_calibration
%RUN_LOW_SNR_ELLIPSE_CALIBRATION Calibrate EFIM regions on held-out data.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
snrDbValues = [-10, 0, 10, 20];
numCalibration = 200;
numTest = 100;
numBootstrapTest = 40;
numBootstrapReplicates = 30;
confidence = 0.95;
nominalThreshold = -2 * log(1 - confidence);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 307);

numSnr = numel(snrDbValues);
empiricalThreshold = zeros(numSnr, 1);
nominalCoverage = zeros(numSnr, 1);
empiricalCoverage = zeros(numSnr, 1);
nominalMeanAreaDegM = zeros(numSnr, 1);
empiricalMeanAreaDegM = zeros(numSnr, 1);
empiricalInflation = zeros(numSnr, 1);
bootstrapCoverage = nan(numSnr, 1);
bootstrapMeanAreaDegM = nan(numSnr, 1);
bootstrapMedianInflation = nan(numSnr, 1);

calibrationSnrDb = repelem(snrDbValues(:), numCalibration);
calibrationQuadraticForm = zeros(size(calibrationSnrDb));
testSnrDb = repelem(snrDbValues(:), numTest);
testTruthThetaDeg = zeros(size(testSnrDb));
testTruthRangeM = zeros(size(testSnrDb));
testEstimateThetaDeg = zeros(size(testSnrDb));
testEstimateRangeM = zeros(size(testSnrDb));
testQuadraticForm = zeros(size(testSnrDb));
testNominalAreaDegM = zeros(size(testSnrDb));

bootstrapSnrDb = repelem(snrDbValues(1:2).', numBootstrapTest);
bootstrapTestIndex = repmat((1:numBootstrapTest).', 2, 1);
bootstrapThreshold = zeros(size(bootstrapSnrDb));
bootstrapContains = false(size(bootstrapSnrDb));
bootstrapAreaDegM = zeros(size(bootstrapSnrDb));
bootstrapRow = 0;

for snrIndex = 1:numSnr
    calibrationRows = (snrIndex - 1) * numCalibration + (1:numCalibration);
    calibrationThetaDeg = -57.3 + 114.6 * rand(stream, numCalibration, 1);
    calibrationRangeM = 17.2 + 30.6 * rand(stream, numCalibration, 1);
    for trialIndex = 1:numCalibration
        trial = simulateTrial(cfg, scan, calibrationThetaDeg(trialIndex), ...
            calibrationRangeM(trialIndex), snrDbValues(snrIndex), stream);
        calibrationQuadraticForm(calibrationRows(trialIndex)) = ...
            trial.quadraticForm;
    end
    empiricalThreshold(snrIndex) = quantile( ...
        calibrationQuadraticForm(calibrationRows), confidence);

    testRows = (snrIndex - 1) * numTest + (1:numTest);
    truthThetaDeg = -57.3 + 114.6 * rand(stream, numTest, 1);
    truthRangeM = 17.2 + 30.6 * rand(stream, numTest, 1);
    trialInformation = zeros(2, 2, numTest);
    for trialIndex = 1:numTest
        trial = simulateTrial(cfg, scan, truthThetaDeg(trialIndex), ...
            truthRangeM(trialIndex), snrDbValues(snrIndex), stream);
        row = testRows(trialIndex);
        testTruthThetaDeg(row) = truthThetaDeg(trialIndex);
        testTruthRangeM(row) = truthRangeM(trialIndex);
        testEstimateThetaDeg(row) = trial.estimateThetaDeg;
        testEstimateRangeM(row) = trial.estimateRangeM;
        testQuadraticForm(row) = trial.quadraticForm;
        testNominalAreaDegM(row) = trial.nominalAreaDegM;
        trialInformation(:, :, trialIndex) = trial.scaledInformation;
    end

    nominalCoverage(snrIndex) = mean( ...
        testQuadraticForm(testRows) <= nominalThreshold);
    empiricalCoverage(snrIndex) = mean( ...
        testQuadraticForm(testRows) <= empiricalThreshold(snrIndex));
    nominalMeanAreaDegM(snrIndex) = mean(testNominalAreaDegM(testRows));
    empiricalInflation(snrIndex) = ...
        empiricalThreshold(snrIndex) / nominalThreshold;
    empiricalMeanAreaDegM(snrIndex) = nominalMeanAreaDegM(snrIndex) ...
        * empiricalInflation(snrIndex);

    if snrIndex <= 2
        for trialIndex = 1:numBootstrapTest
            bootstrapQuadraticForm = zeros(numBootstrapReplicates, 1);
            fittedThetaDeg = testEstimateThetaDeg(testRows(trialIndex));
            fittedRangeM = testEstimateRangeM(testRows(trialIndex));
            for replicateIndex = 1:numBootstrapReplicates
                bootstrapTrial = simulateTrial(cfg, scan, fittedThetaDeg, ...
                    fittedRangeM, snrDbValues(snrIndex), stream);
                bootstrapQuadraticForm(replicateIndex) = ...
                    bootstrapTrial.quadraticForm;
            end
            bootstrapRow = bootstrapRow + 1;
            bootstrapThreshold(bootstrapRow) = quantile( ...
                bootstrapQuadraticForm, confidence);
            originalQuadraticForm = ...
                testQuadraticForm(testRows(trialIndex));
            bootstrapContains(bootstrapRow) = originalQuadraticForm ...
                <= bootstrapThreshold(bootstrapRow);
            bootstrapAreaDegM(bootstrapRow) = pi ...
                * bootstrapThreshold(bootstrapRow) ...
                / sqrt(det(trialInformation(:, :, trialIndex)));
        end
        bootstrapRows = bootstrapRow - numBootstrapTest + 1:bootstrapRow;
        bootstrapCoverage(snrIndex) = mean( ...
            bootstrapContains(bootstrapRows));
        bootstrapMeanAreaDegM(snrIndex) = mean( ...
            bootstrapAreaDegM(bootstrapRows));
        bootstrapMedianInflation(snrIndex) = median( ...
            bootstrapThreshold(bootstrapRows) / nominalThreshold);
    end
    fprintf("Completed ellipse calibration at %g dB.\n", ...
        snrDbValues(snrIndex));
end

snrDb = snrDbValues(:);
summary = table(snrDb, nominalCoverage, empiricalCoverage, ...
    bootstrapCoverage, empiricalThreshold, empiricalInflation, ...
    bootstrapMedianInflation, nominalMeanAreaDegM, ...
    empiricalMeanAreaDegM, bootstrapMeanAreaDegM);
calibration = table(calibrationSnrDb, calibrationQuadraticForm);
test = table(testSnrDb, testTruthThetaDeg, testTruthRangeM, ...
    testEstimateThetaDeg, testEstimateRangeM, testQuadraticForm, ...
    testNominalAreaDegM);
bootstrap = table(bootstrapSnrDb, bootstrapTestIndex, bootstrapThreshold, ...
    bootstrapContains, bootstrapAreaDegM);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round3");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(summary, fullfile(outputFolder, ...
    "low_snr_ellipse_calibration_summary.csv"));
writetable(calibration, fullfile(outputFolder, ...
    "low_snr_ellipse_calibration_samples.csv"));
writetable(test, fullfile(outputFolder, ...
    "low_snr_ellipse_test_samples.csv"));
writetable(bootstrap, fullfile(outputFolder, ...
    "low_snr_ellipse_bootstrap_samples.csv"));
save(fullfile(outputFolder, "low_snr_ellipse_calibration.mat"), ...
    "cfg", "snrDbValues", "numCalibration", "numTest", ...
    "numBootstrapTest", "numBootstrapReplicates", "confidence", ...
    "summary", "calibration", "test", "bootstrap");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
plot(snrDb, nominalCoverage, "-o", snrDb, empiricalCoverage, "-s", ...
    snrDb(1:2), bootstrapCoverage(1:2), "-^", ...
    LineWidth=1.5, MarkerSize=6);
yline(confidence, "--", "Target 95%");
ylim([0, 1.02]); grid on;
xlabel("Output SNR (dB)"); ylabel("Held-out coverage");
legend("Nominal EFIM", "Empirical inflation", ...
    "Conditional bootstrap", Location="southeast");
title("Actual region coverage");
nexttile;
semilogy(snrDb, empiricalInflation, "-s", snrDb(1:2), ...
    bootstrapMedianInflation(1:2), "-^", LineWidth=1.5, MarkerSize=6);
yline(1, "--", "No inflation"); grid on;
xlabel("Output SNR (dB)"); ylabel("Threshold / nominal threshold");
legend("Empirical", "Median bootstrap", Location="best");
title("Required ellipse inflation");
title(layout, "Low-SNR EFIM calibration on independent test positions");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "low_snr_ellipse_calibration.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "low_snr_ellipse_calibration.fig"));
close(figureHandle);

disp(summary);
end

function trial = simulateTrial(cfg, scan, truthThetaDeg, truthRangeM, ...
    snrDb, stream)
truthResponse = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
noiseVariance = signalPower / 10^(snrDb / 10);
commonPhase = 2 * pi * rand(stream);
noise = sqrt(noiseVariance / 2) * ( ...
    randn(stream, cfg.numSubcarriers, 1) ...
    + 1i * randn(stream, cfg.numSubcarriers, 1));
observation = truthResponse * exp(1i * commonPhase) + noise;
estimate = fsjad.peakInitializedProfileEstimate(cfg, observation, scan);

[estimatedResponse, derivative] = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(estimate.thetaDeg), estimate.rangeM, scan);
information = fsjad.projectedEfim(estimatedResponse, derivative, ...
    estimate.beta, noiseVariance);
parameterScale = diag([deg2rad(1), 1]);
scaledInformation = parameterScale.' * information * parameterScale;
offset = [truthThetaDeg - estimate.thetaDeg; ...
    truthRangeM - estimate.rangeM];

trial.estimateThetaDeg = estimate.thetaDeg;
trial.estimateRangeM = estimate.rangeM;
trial.quadraticForm = offset.' * scaledInformation * offset;
trial.scaledInformation = scaledInformation;
trial.nominalAreaDegM = pi * (-2 * log(0.05)) ...
    / sqrt(det(scaledInformation));
end
