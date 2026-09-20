function run_phase_noise
%RUN_PHASE_NOISE Compare scan statistics under residual carrier phase noise.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
thetaGridDeg = (-60:5:60).';
rangeGridM = (15:2.5:50).';
bank = fsjad.prepareCandidateBank(cfg, thetaGridDeg, rangeGridM, scan);
powerBank = abs(bank.response).^2;
powerEnergy = sum(powerBank.^2, 1).';

location = ["Weak EFIM"; "Strong EFIM"; "Known counterexample"; ...
    "Left boundary"; "Right boundary"; "Interior"];
truthThetaDeg = [0; -55; 15; -60; 60; 30];
truthRangeM = [15; 22.5; 30; 15; 50; 40];
snrDbValues = [10, 20];
phaseRmsDegValues = [0, 1, 3, 5, 10, 20, 40, 60, 90];
numTrials = 100;
methodNames = ["Peak index"; "Full power spectrum"; "Full complex spectrum"];
numMethods = numel(methodNames);
numRows = numMethods * numel(location) * numel(snrDbValues) ...
    * numel(phaseRmsDegValues);

method = strings(numRows, 1);
locationColumn = strings(numRows, 1);
snrDb = zeros(numRows, 1);
phaseRmsDeg = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
captureRate = zeros(numRows, 1);
truthCoherence = zeros(numRows, 1);
rowIndex = 0;
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 131);

for locationIndex = 1:numel(location)
    truthIndex = find(bank.thetaDeg == truthThetaDeg(locationIndex) ...
        & bank.rangeM == truthRangeM(locationIndex), 1);
    truthResponse = bank.response(:, truthIndex);
    signalPower = mean(abs(truthResponse).^2);

    for snrIndex = 1:numel(snrDbValues)
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        for phaseIndex = 1:numel(phaseRmsDegValues)
            relativePhase = fsjad.relativePhaseNoise(cfg.numSubcarriers, ...
                numTrials, phaseRmsDegValues(phaseIndex), stream);
            commonPhase = 2 * pi * rand(stream, 1, numTrials);
            noise = sqrt(noiseVariance / 2) * ( ...
                randn(stream, cfg.numSubcarriers, numTrials) ...
                + 1i * randn(stream, cfg.numSubcarriers, numTrials));
            observation = truthResponse .* exp(1i * (relativePhase + commonPhase)) ...
                + noise;

            [~, peakIndex] = max(abs(observation).^2, [], 1);
            peakThetaDeg = scan.focusThetaDeg(peakIndex);
            peakRangeM = scan.focusRangeM(peakIndex);

            centeredPower = abs(observation).^2 - noiseVariance;
            powerCorrelation = real(powerBank' * centeredPower);
            powerScore = max(powerCorrelation, 0).^2 ./ powerEnergy;
            [~, powerIndex] = max(powerScore, [], 1);
            powerThetaDeg = bank.thetaDeg(powerIndex);
            powerRangeM = bank.rangeM(powerIndex);

            complexCorrelation = bank.response' * observation;
            complexScore = abs(complexCorrelation).^2 ./ bank.energy;
            [~, complexIndex] = max(complexScore, [], 1);
            complexThetaDeg = bank.thetaDeg(complexIndex);
            complexRangeM = bank.rangeM(complexIndex);

            estimateThetaDeg = [peakThetaDeg(:).'; powerThetaDeg(:).'; ...
                complexThetaDeg(:).'];
            estimateRangeM = [peakRangeM(:).'; powerRangeM(:).'; ...
                complexRangeM(:).'];
            angleError = estimateThetaDeg - truthThetaDeg(locationIndex);
            rangeError = estimateRangeM - truthRangeM(locationIndex);
            captured = abs(angleError) <= 1 & abs(rangeError) <= 1;
            normalizedTruthCoherence = abs(truthResponse' * observation).^2 ...
                ./ (real(truthResponse' * truthResponse) ...
                * sum(abs(observation).^2, 1));

            rows = rowIndex + (1:numMethods);
            method(rows) = methodNames;
            locationColumn(rows) = location(locationIndex);
            snrDb(rows) = snrDbValues(snrIndex);
            phaseRmsDeg(rows) = phaseRmsDegValues(phaseIndex);
            angleRmseDeg(rows) = sqrt(mean(angleError.^2, 2));
            rangeRmseM(rows) = sqrt(mean(rangeError.^2, 2));
            captureRate(rows) = mean(captured, 2);
            truthCoherence(rows) = mean(normalizedTruthCoherence);
            rowIndex = rowIndex + numMethods;
        end
    end
end

details = table(method, locationColumn, snrDb, phaseRmsDeg, ...
    angleRmseDeg, rangeRmseM, captureRate, truthCoherence);
summary = groupsummary(details, ["method", "snrDb", "phaseRmsDeg"], ...
    "mean", ["angleRmseDeg", "rangeRmseM", "captureRate", ...
    "truthCoherence"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round2");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, "phase_noise_points.csv"));
writetable(summary, fullfile(outputFolder, "phase_noise_summary.csv"));
save(fullfile(outputFolder, "phase_noise.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "phaseRmsDegValues", "numTrials", "details", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1100, 760]);
layout = tiledlayout(2, 2, TileSpacing="compact", Padding="compact");
plotPhaseMetric(summary, methodNames, 10, "mean_rangeRmseM", ...
    "10 dB range RMSE", "m", true);
plotPhaseMetric(summary, methodNames, 20, "mean_rangeRmseM", ...
    "20 dB range RMSE", "m", true);
plotPhaseMetric(summary, methodNames, 10, "mean_captureRate", ...
    "10 dB capture rate", "Probability", false);
plotPhaseMetric(summary, methodNames, 20, "mean_captureRate", ...
    "20 dB capture rate", "Probability", false);
title(layout, sprintf("Residual cross-carrier phase noise, %d trials", ...
    numTrials));
exportgraphics(figureHandle, fullfile(outputFolder, "phase_noise.png"), ...
    Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "phase_noise.fig"));
close(figureHandle);

disp(summary);
end

function plotPhaseMetric(summary, methodNames, snrDb, variableName, ...
    plotTitle, yLabel, useLog)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex) ...
        & summary.snrDb == snrDb;
    if useLog
        semilogy(summary.phaseRmsDeg(rows), summary.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=5);
    else
        plot(summary.phaseRmsDeg(rows), summary.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=5);
    end
end
hold off;
grid on;
xlabel("Residual phase RMS (degrees)");
ylabel(yLabel);
title(plotTitle);
legend(methodNames, Location="best");
end
