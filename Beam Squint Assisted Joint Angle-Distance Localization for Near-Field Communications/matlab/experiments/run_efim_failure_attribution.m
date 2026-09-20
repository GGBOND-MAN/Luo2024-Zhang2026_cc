function run_efim_failure_attribution
%RUN_EFIM_FAILURE_ATTRIBUTION Separate theory, optimization, and FIM errors.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
snrDbValues = [-10, 0, 10, 20];
numTrialsPerSnr = 100;
confidence = 0.95;
threshold = -2 * log(1 - confidence);
parameterScale = diag([deg2rad(1), 1]);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 601);

numRows = numel(snrDbValues) * numTrialsPerSnr;
snrDb = repelem(snrDbValues(:), numTrialsPerSnr);
truthThetaDeg = zeros(numRows, 1);
truthRangeM = zeros(numRows, 1);
globalThetaDeg = zeros(numRows, 1);
globalRangeM = zeros(numRows, 1);
oracleThetaDeg = zeros(numRows, 1);
oracleRangeM = zeros(numRows, 1);
globalEstimatedQf = zeros(numRows, 1);
globalTruthQf = zeros(numRows, 1);
oracleEstimatedQf = zeros(numRows, 1);
oracleTruthQf = zeros(numRows, 1);
linearizedQf = zeros(numRows, 1);
globalCaptured = false(numRows, 1);
oracleCaptured = false(numRows, 1);
globalConverged = false(numRows, 1);
oracleConverged = false(numRows, 1);
globalScore = zeros(numRows, 1);
oracleScore = zeros(numRows, 1);
scoreLossFromOracle = zeros(numRows, 1);
globalIterations = zeros(numRows, 1);
oracleIterations = zeros(numRows, 1);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round4");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

for snrIndex = 1:numel(snrDbValues)
    rows = (snrIndex - 1) * numTrialsPerSnr + (1:numTrialsPerSnr);
    currentThetaDeg = -57.3 + 114.6 * rand(stream, numTrialsPerSnr, 1);
    currentRangeM = 17.2 + 30.6 * rand(stream, numTrialsPerSnr, 1);
    for trialIndex = 1:numTrialsPerSnr
        row = rows(trialIndex);
        [truthResponse, truthDerivative] = fsjad.exactSpectralResponse( ...
            cfg, deg2rad(currentThetaDeg(trialIndex)), ...
            currentRangeM(trialIndex), scan);
        signalPower = mean(abs(truthResponse).^2);
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        betaTrue = exp(1i * 2 * pi * rand(stream));
        noise = sqrt(noiseVariance / 2) * ( ...
            randn(stream, cfg.numSubcarriers, 1) ...
            + 1i * randn(stream, cfg.numSubcarriers, 1));
        observation = betaTrue * truthResponse + noise;

        globalEstimate = fsjad.peakInitializedProfileEstimate( ...
            cfg, observation, scan);
        oracleEstimate = fsjad.refineProfileEstimate(cfg, observation, ...
            currentThetaDeg(trialIndex), currentRangeM(trialIndex), scan, 20);

        truthInformation = fsjad.projectedEfim(truthResponse, ...
            truthDerivative, betaTrue, noiseVariance);
        scaledTruthInformation = parameterScale.' * truthInformation ...
            * parameterScale;
        globalInformation = informationAtEstimate(cfg, scan, ...
            globalEstimate, noiseVariance, parameterScale);
        oracleInformation = informationAtEstimate(cfg, scan, ...
            oracleEstimate, noiseVariance, parameterScale);

        globalOffset = [currentThetaDeg(trialIndex) ...
            - globalEstimate.thetaDeg; currentRangeM(trialIndex) ...
            - globalEstimate.rangeM];
        oracleOffset = [currentThetaDeg(trialIndex) ...
            - oracleEstimate.thetaDeg; currentRangeM(trialIndex) ...
            - oracleEstimate.rangeM];
        scaledDerivative = betaTrue * truthDerivative * parameterScale;
        projectedDerivative = scaledDerivative - truthResponse ...
            * (truthResponse' * scaledDerivative ...
            / real(truthResponse' * truthResponse));
        normalMatrix = real(projectedDerivative' * projectedDerivative);
        linearizedStep = normalMatrix ...
            \ real(projectedDerivative' * noise);

        truthThetaDeg(row) = currentThetaDeg(trialIndex);
        truthRangeM(row) = currentRangeM(trialIndex);
        globalThetaDeg(row) = globalEstimate.thetaDeg;
        globalRangeM(row) = globalEstimate.rangeM;
        oracleThetaDeg(row) = oracleEstimate.thetaDeg;
        oracleRangeM(row) = oracleEstimate.rangeM;
        globalEstimatedQf(row) = quadraticForm(globalOffset, ...
            globalInformation);
        globalTruthQf(row) = quadraticForm(globalOffset, ...
            scaledTruthInformation);
        oracleEstimatedQf(row) = quadraticForm(oracleOffset, ...
            oracleInformation);
        oracleTruthQf(row) = quadraticForm(oracleOffset, ...
            scaledTruthInformation);
        linearizedQf(row) = quadraticForm(linearizedStep, ...
            scaledTruthInformation);
        globalCaptured(row) = isCaptured(globalOffset);
        oracleCaptured(row) = isCaptured(oracleOffset);
        globalConverged(row) = globalEstimate.converged;
        oracleConverged(row) = oracleEstimate.converged;
        globalScore(row) = globalEstimate.score;
        oracleScore(row) = oracleEstimate.score;
        scoreLossFromOracle(row) = oracleEstimate.score ...
            - globalEstimate.score;
        globalIterations(row) = globalEstimate.iterations;
        oracleIterations(row) = oracleEstimate.iterations;
    end

    completedSnrCount = snrIndex;
    save(fullfile(outputFolder, "efim_failure_checkpoint.mat"), ...
        "snrDbValues", "numTrialsPerSnr", "completedSnrCount", ...
        "snrDb", "truthThetaDeg", "truthRangeM", ...
        "globalThetaDeg", "globalRangeM", "oracleThetaDeg", ...
        "oracleRangeM", "globalEstimatedQf", "globalTruthQf", ...
        "oracleEstimatedQf", "oracleTruthQf", "linearizedQf", ...
        "globalCaptured", "oracleCaptured", "globalConverged", ...
        "oracleConverged", "globalScore", "oracleScore", ...
        "scoreLossFromOracle", "globalIterations", "oracleIterations");
    fprintf("Completed EFIM attribution at %g dB.\n", ...
        snrDbValues(snrIndex));
end

trials = table(snrDb, truthThetaDeg, truthRangeM, globalThetaDeg, ...
    globalRangeM, oracleThetaDeg, oracleRangeM, globalEstimatedQf, ...
    globalTruthQf, oracleEstimatedQf, oracleTruthQf, linearizedQf, ...
    globalCaptured, oracleCaptured, globalConverged, oracleConverged, ...
    globalScore, oracleScore, scoreLossFromOracle, ...
    globalIterations, oracleIterations);

numSnr = numel(snrDbValues);
summarySnrDb = snrDbValues(:);
linearizedCoverage = zeros(numSnr, 1);
globalEstimatedCoverage = zeros(numSnr, 1);
globalTruthCoverage = zeros(numSnr, 1);
oracleEstimatedCoverage = zeros(numSnr, 1);
oracleTruthCoverage = zeros(numSnr, 1);
globalConditionalCoverage = zeros(numSnr, 1);
globalCaptureRate = zeros(numSnr, 1);
oracleCaptureRate = zeros(numSnr, 1);
wrongModeRate = zeros(numSnr, 1);
globalConvergenceRate = zeros(numSnr, 1);
oracleConvergenceRate = zeros(numSnr, 1);
globalQf95 = zeros(numSnr, 1);
oracleQf95 = zeros(numSnr, 1);
linearizedQf95 = zeros(numSnr, 1);
meanScoreLossFromOracle = zeros(numSnr, 1);
for snrIndex = 1:numSnr
    rows = (snrIndex - 1) * numTrialsPerSnr + (1:numTrialsPerSnr);
    capturedRows = rows(globalCaptured(rows));
    linearizedCoverage(snrIndex) = mean(linearizedQf(rows) <= threshold);
    globalEstimatedCoverage(snrIndex) = mean( ...
        globalEstimatedQf(rows) <= threshold);
    globalTruthCoverage(snrIndex) = mean(globalTruthQf(rows) <= threshold);
    oracleEstimatedCoverage(snrIndex) = mean( ...
        oracleEstimatedQf(rows) <= threshold);
    oracleTruthCoverage(snrIndex) = mean(oracleTruthQf(rows) <= threshold);
    globalConditionalCoverage(snrIndex) = mean( ...
        globalEstimatedQf(capturedRows) <= threshold);
    globalCaptureRate(snrIndex) = mean(globalCaptured(rows));
    oracleCaptureRate(snrIndex) = mean(oracleCaptured(rows));
    wrongModeRate(snrIndex) = mean(~globalCaptured(rows) ...
        & oracleCaptured(rows));
    globalConvergenceRate(snrIndex) = mean(globalConverged(rows));
    oracleConvergenceRate(snrIndex) = mean(oracleConverged(rows));
    globalQf95(snrIndex) = quantile(globalEstimatedQf(rows), confidence);
    oracleQf95(snrIndex) = quantile(oracleEstimatedQf(rows), confidence);
    linearizedQf95(snrIndex) = quantile(linearizedQf(rows), confidence);
    meanScoreLossFromOracle(snrIndex) = mean(scoreLossFromOracle(rows));
end

summary = table(summarySnrDb, linearizedCoverage, ...
    globalEstimatedCoverage, globalTruthCoverage, ...
    oracleEstimatedCoverage, oracleTruthCoverage, ...
    globalConditionalCoverage, globalCaptureRate, oracleCaptureRate, ...
    wrongModeRate, globalConvergenceRate, oracleConvergenceRate, ...
    linearizedQf95, globalQf95, oracleQf95, meanScoreLossFromOracle);

writetable(trials, fullfile(outputFolder, ...
    "efim_failure_attribution_trials.csv"));
writetable(summary, fullfile(outputFolder, ...
    "efim_failure_attribution_summary.csv"));
save(fullfile(outputFolder, "efim_failure_attribution.mat"), ...
    "cfg", "snrDbValues", "numTrialsPerSnr", "confidence", ...
    "trials", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
plot(summarySnrDb, linearizedCoverage, "-o", ...
    summarySnrDb, globalEstimatedCoverage, "-s", ...
    summarySnrDb, oracleEstimatedCoverage, "-^", ...
    LineWidth=1.5, MarkerSize=6);
yline(confidence, "--", "Target 95%");
grid on; ylim([0, 1.02]);
xlabel("Output SNR (dB)"); ylabel("Coverage");
legend("Truth-linearized", "Global nonlinear", "Truth-init nonlinear", ...
    Location="southeast");
title("EFIM failure attribution");
nexttile;
plot(summarySnrDb, globalCaptureRate, "-o", ...
    summarySnrDb, oracleCaptureRate, "-s", ...
    summarySnrDb, wrongModeRate, "-^", ...
    LineWidth=1.5, MarkerSize=6);
grid on; ylim([0, 1.02]);
xlabel("Output SNR (dB)"); ylabel("Probability");
legend("Global capture", "Truth-init capture", "Wrong global mode", ...
    Location="best");
title("Optimization and mode selection");
title(layout, "Low-SNR EFIM under matched data and models");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "efim_failure_attribution.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "efim_failure_attribution.fig"));
close(figureHandle);

disp(summary);
end

function information = informationAtEstimate(cfg, scan, estimate, ...
    noiseVariance, parameterScale)
[response, derivative] = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(estimate.thetaDeg), estimate.rangeM, scan);
informationRadM = fsjad.projectedEfim(response, derivative, ...
    estimate.beta, noiseVariance);
information = parameterScale.' * informationRadM * parameterScale;
end

function value = quadraticForm(offset, information)
value = offset.' * information * offset;
end

function captured = isCaptured(offset)
captured = abs(offset(1)) <= 1 && abs(offset(2)) <= 1;
end
