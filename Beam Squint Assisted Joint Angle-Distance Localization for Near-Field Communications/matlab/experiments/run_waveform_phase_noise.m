function run_waveform_phase_noise
%RUN_WAVEFORM_PHASE_NOISE Test OFDM Wiener phase noise, CPE, and ICI.

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
innovationStdDegValues = [0, 0.05, 0.1, 0.2, 0.5, 1, 2, 4];
numTrials = 100;
methodNames = ["Peak index"; "Full power spectrum"; ...
    "Full complex spectrum"];
numMethods = numel(methodNames);
numRows = numMethods * numel(location) * numel(snrDbValues) ...
    * numel(innovationStdDegValues);

method = strings(numRows, 1);
locationColumn = strings(numRows, 1);
snrDb = zeros(numRows, 1);
innovationStdDeg = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
captureRate = zeros(numRows, 1);
phaseRmsDeg = zeros(numRows, 1);
cpeMagnitude = zeros(numRows, 1);
iciToUsefulDb = zeros(numRows, 1);
truthCoherence = zeros(numRows, 1);
rowIndex = 0;
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 211);

for locationIndex = 1:numel(location)
    truthIndex = find(bank.thetaDeg == truthThetaDeg(locationIndex) ...
        & bank.rangeM == truthRangeM(locationIndex), 1);
    truthResponse = bank.response(:, truthIndex);
    signalPower = mean(abs(truthResponse).^2);

    for snrIndex = 1:numel(snrDbValues)
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        for phaseIndex = 1:numel(innovationStdDegValues)
            repeatedTruth = repmat(truthResponse, 1, numTrials);
            [distortedSignal, phaseDiagnostics] = ...
                fsjad.applyWienerPhaseNoise(repeatedTruth, ...
                deg2rad(innovationStdDegValues(phaseIndex)), stream);
            commonPhase = 2 * pi * rand(stream, 1, numTrials);
            noise = sqrt(noiseVariance / 2) * ( ...
                randn(stream, cfg.numSubcarriers, numTrials) ...
                + 1i * randn(stream, cfg.numSubcarriers, numTrials));
            observation = distortedSignal .* exp(1i * commonPhase) + noise;

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
            innovationStdDeg(rows) = innovationStdDegValues(phaseIndex);
            angleRmseDeg(rows) = sqrt(mean(angleError.^2, 2));
            rangeRmseM(rows) = sqrt(mean(rangeError.^2, 2));
            captureRate(rows) = mean(captured, 2);
            phaseRmsDeg(rows) = mean(rad2deg( ...
                phaseDiagnostics.centeredPhaseRmsRad));
            cpeMagnitude(rows) = mean(phaseDiagnostics.cpeMagnitude);
            iciToUsefulDb(rows) = 10 * log10(max(mean( ...
                phaseDiagnostics.iciToUsefulRatio), realmin));
            truthCoherence(rows) = mean(normalizedTruthCoherence);
            rowIndex = rowIndex + numMethods;
        end
    end
end

details = table(method, locationColumn, snrDb, innovationStdDeg, ...
    angleRmseDeg, rangeRmseM, captureRate, phaseRmsDeg, cpeMagnitude, ...
    iciToUsefulDb, truthCoherence);
summary = groupsummary(details, ["method", "snrDb", "innovationStdDeg"], ...
    "mean", ["angleRmseDeg", "rangeRmseM", "captureRate", ...
    "phaseRmsDeg", "cpeMagnitude", "iciToUsefulDb", "truthCoherence"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round3");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, "waveform_phase_noise_points.csv"));
writetable(summary, fullfile(outputFolder, "waveform_phase_noise_summary.csv"));
save(fullfile(outputFolder, "waveform_phase_noise.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", "snrDbValues", ...
    "innovationStdDegValues", "numTrials", "details", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1120, 760]);
layout = tiledlayout(2, 2, TileSpacing="compact", Padding="compact");
plotMetric(summary, methodNames, 10, "mean_rangeRmseM", ...
    "10 dB range RMSE", "m", true);
plotMetric(summary, methodNames, 20, "mean_rangeRmseM", ...
    "20 dB range RMSE", "m", true);
plotMetric(summary, methodNames, 10, "mean_captureRate", ...
    "10 dB capture rate", "Probability", false);
plotMetric(summary, methodNames, 20, "mean_captureRate", ...
    "20 dB capture rate", "Probability", false);
title(layout, sprintf("Waveform-level Wiener phase noise, %d trials", ...
    numTrials));
exportgraphics(figureHandle, ...
    fullfile(outputFolder, "waveform_phase_noise.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "waveform_phase_noise.fig"));
close(figureHandle);

disp(summary);
end

function plotMetric(summary, methodNames, snrDb, variableName, ...
    plotTitle, yLabel, useLog)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex) ...
        & summary.snrDb == snrDb;
    if useLog
        semilogy(summary.innovationStdDeg(rows), ...
            summary.(variableName)(rows), lineStyle(methodIndex), ...
            LineWidth=1.5, MarkerSize=5);
    else
        plot(summary.innovationStdDeg(rows), ...
            summary.(variableName)(rows), lineStyle(methodIndex), ...
            LineWidth=1.5, MarkerSize=5);
    end
end
hold off;
grid on;
xlabel("Wiener innovation standard deviation (deg/sample)");
ylabel(yLabel);
title(plotTitle);
legend(methodNames, Location="best");
end
