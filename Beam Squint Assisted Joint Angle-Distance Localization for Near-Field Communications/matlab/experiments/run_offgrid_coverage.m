function run_offgrid_coverage
%RUN_OFFGRID_COVERAGE Calibrate fixed and EFIM regions at continuous truths.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
snrDbValues = [-10, 0, 10, 20];
numTrialsPerSnr = 200;
confidence = 0.95;
parameterScale = diag([deg2rad(1), 1]);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 101);

truthThetaDeg = -57.3 + 114.6 * rand(stream, numTrialsPerSnr, 1);
truthRangeM = 17.2 + 30.6 * rand(stream, numTrialsPerSnr, 1);
numRows = numel(snrDbValues);
snrDb = snrDbValues(:);
peakFixedCoverage = zeros(numRows, 1);
complexFixedCoverage = zeros(numRows, 1);
efimCoverage = zeros(numRows, 1);
meanEllipseAreaDegM = zeros(numRows, 1);
medianEllipseAreaDegM = zeros(numRows, 1);
meanAngleErrorDeg = zeros(numRows, 1);
meanRangeErrorM = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
meanScore = zeros(numRows, 1);

trialSnrDb = repelem(snrDbValues(:), numTrialsPerSnr);
trialThetaDeg = repmat(truthThetaDeg, numel(snrDbValues), 1);
trialRangeM = repmat(truthRangeM, numel(snrDbValues), 1);
estimatedThetaDeg = zeros(size(trialSnrDb));
estimatedRangeM = zeros(size(trialSnrDb));
peakCaptured = false(size(trialSnrDb));
complexFixedCaptured = false(size(trialSnrDb));
ellipseCaptured = false(size(trialSnrDb));
ellipseAreaDegM = zeros(size(trialSnrDb));
profileScore = zeros(size(trialSnrDb));

for snrIndex = 1:numel(snrDbValues)
    rows = (snrIndex - 1) * numTrialsPerSnr + (1:numTrialsPerSnr);
    for trialIndex = 1:numTrialsPerSnr
        row = rows(trialIndex);
        truthResponse = fsjad.exactSpectralResponse(cfg, ...
            deg2rad(truthThetaDeg(trialIndex)), truthRangeM(trialIndex), scan);
        signalPower = mean(abs(truthResponse).^2);
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        commonPhase = 2 * pi * rand(stream);
        noise = sqrt(noiseVariance / 2) * ( ...
            randn(stream, cfg.numSubcarriers, 1) ...
            + 1i * randn(stream, cfg.numSubcarriers, 1));
        observation = truthResponse * exp(1i * commonPhase) + noise;

        [~, peakIndex] = max(abs(observation).^2);
        peakThetaDeg = scan.focusThetaDeg(peakIndex);
        peakRangeM = scan.focusRangeM(peakIndex);
        estimate = fsjad.peakInitializedProfileEstimate( ...
            cfg, observation, scan);

        [estimatedResponse, derivative] = fsjad.exactSpectralResponse(cfg, ...
            deg2rad(estimate.thetaDeg), estimate.rangeM, scan);
        betaEstimate = estimatedResponse' * observation ...
            / real(estimatedResponse' * estimatedResponse);
        information = fsjad.projectedEfim(estimatedResponse, derivative, ...
            betaEstimate, noiseVariance);
        scaledInformation = parameterScale.' * information * parameterScale;
        ellipse = fsjad.efimEllipseMetrics(scaledInformation, ...
            [estimate.thetaDeg; estimate.rangeM], ...
            [truthThetaDeg(trialIndex); truthRangeM(trialIndex)], confidence);

        estimatedThetaDeg(row) = estimate.thetaDeg;
        estimatedRangeM(row) = estimate.rangeM;
        peakCaptured(row) = abs(peakThetaDeg - truthThetaDeg(trialIndex)) <= 1 ...
            && abs(peakRangeM - truthRangeM(trialIndex)) <= 1;
        complexFixedCaptured(row) = ...
            abs(estimate.thetaDeg - truthThetaDeg(trialIndex)) <= 1 ...
            && abs(estimate.rangeM - truthRangeM(trialIndex)) <= 1;
        ellipseCaptured(row) = ellipse.contains;
        ellipseAreaDegM(row) = ellipse.area;
        profileScore(row) = estimate.score;
    end

    angleError = estimatedThetaDeg(rows) - truthThetaDeg;
    rangeError = estimatedRangeM(rows) - truthRangeM;
    peakFixedCoverage(snrIndex) = mean(peakCaptured(rows));
    complexFixedCoverage(snrIndex) = mean(complexFixedCaptured(rows));
    efimCoverage(snrIndex) = mean(ellipseCaptured(rows));
    meanEllipseAreaDegM(snrIndex) = mean(ellipseAreaDegM(rows));
    medianEllipseAreaDegM(snrIndex) = median(ellipseAreaDegM(rows));
    meanAngleErrorDeg(snrIndex) = mean(angleError);
    meanRangeErrorM(snrIndex) = mean(rangeError);
    angleRmseDeg(snrIndex) = sqrt(mean(angleError.^2));
    rangeRmseM(snrIndex) = sqrt(mean(rangeError.^2));
    meanScore(snrIndex) = mean(profileScore(rows));
end

summary = table(snrDb, peakFixedCoverage, complexFixedCoverage, ...
    efimCoverage, meanEllipseAreaDegM, medianEllipseAreaDegM, ...
    meanAngleErrorDeg, meanRangeErrorM, angleRmseDeg, rangeRmseM, meanScore);
trials = table(trialSnrDb, trialThetaDeg, trialRangeM, ...
    estimatedThetaDeg, estimatedRangeM, peakCaptured, ...
    complexFixedCaptured, ellipseCaptured, ellipseAreaDegM, profileScore);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round2");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(summary, fullfile(outputFolder, "offgrid_coverage_summary.csv"));
writetable(trials, fullfile(outputFolder, "offgrid_coverage_trials.csv"));
save(fullfile(outputFolder, "offgrid_coverage.mat"), ...
    "cfg", "snrDbValues", "numTrialsPerSnr", "confidence", ...
    "truthThetaDeg", "truthRangeM", "summary", "trials");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 410]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
plot(snrDb, peakFixedCoverage, "-o", snrDb, complexFixedCoverage, "-s", ...
    snrDb, efimCoverage, "-^", LineWidth=1.5, MarkerSize=6);
yline(confidence, "--", "Nominal 95%");
ylim([0, 1.02]); grid on;
xlabel("Output SNR (dB)"); ylabel("Coverage probability");
title("Off-grid actual coverage");
legend("Peak + fixed", "Complex + fixed", "Complex + EFIM", ...
    Location="southeast");
nexttile;
semilogy(snrDb, meanEllipseAreaDegM, "-o", LineWidth=1.5, MarkerSize=6);
yline(4, "--", "Fixed area"); grid on;
xlabel("Output SNR (dB)"); ylabel("degree m");
title("Mean 95% EFIM ellipse area");
title(layout, sprintf("Continuous off-grid truths, %d trials per SNR", ...
    numTrialsPerSnr));
exportgraphics(figureHandle, fullfile(outputFolder, "offgrid_coverage.png"), ...
    Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "offgrid_coverage.fig"));
close(figureHandle);

disp(summary);
end
