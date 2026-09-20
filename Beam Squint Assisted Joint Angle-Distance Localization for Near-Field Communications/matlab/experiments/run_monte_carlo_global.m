function run_monte_carlo_global
%RUN_MONTE_CARLO_GLOBAL Compare three scan statistics on a global grid.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
thetaGridDeg = (-60:5:60).';
rangeGridM = (15:2.5:50).';
[thetaMeshDeg, rangeMeshM] = meshgrid(thetaGridDeg, rangeGridM);
candidateThetaDeg = thetaMeshDeg(:);
candidateRangeM = rangeMeshM(:);
numCandidates = numel(candidateThetaDeg);

responseBank = complex(zeros(cfg.numSubcarriers, numCandidates));
for candidateIndex = 1:numCandidates
    responseBank(:, candidateIndex) = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(candidateThetaDeg(candidateIndex)), ...
        candidateRangeM(candidateIndex), scan);
end
responseEnergy = real(sum(abs(responseBank).^2, 1)).';
powerBank = abs(responseBank).^2;
powerEnergy = sum(powerBank.^2, 1).';

locationLabel = ["Weak EFIM"; "Strong EFIM"; "Known counterexample"; ...
    "Left boundary"; "Right boundary"; "Interior"];
truthThetaDeg = [0; -55; 15; -60; 60; 30];
truthRangeM = [15; 22.5; 30; 15; 50; 40];
snrDbValues = [-10, 0, 10, 20];
numTrials = 100;
methodNames = ["Peak index"; "Full power spectrum"; "Full complex spectrum"];
numMethods = numel(methodNames);
numLocations = numel(truthThetaDeg);
numSnr = numel(snrDbValues);
numRows = numMethods * numLocations * numSnr;

method = strings(numRows, 1);
location = strings(numRows, 1);
thetaDeg = zeros(numRows, 1);
rangeM = zeros(numRows, 1);
snrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
scaledPositionRmse = zeros(numRows, 1);
captureRate = zeros(numRows, 1);
rowIndex = 0;

stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 31);
for locationIndex = 1:numLocations
    truthIndex = find(candidateThetaDeg == truthThetaDeg(locationIndex) ...
        & candidateRangeM == truthRangeM(locationIndex), 1);
    truthResponse = responseBank(:, truthIndex);
    signalPower = mean(abs(truthResponse).^2);

    for snrIndex = 1:numSnr
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        commonPhase = 2 * pi * rand(stream, 1, numTrials);
        noise = sqrt(noiseVariance / 2) * ( ...
            randn(stream, cfg.numSubcarriers, numTrials) ...
            + 1i * randn(stream, cfg.numSubcarriers, numTrials));
        observation = truthResponse .* exp(1i * commonPhase) + noise;

        [~, peakIndex] = max(abs(observation).^2, [], 1);
        peakThetaDeg = scan.focusThetaDeg(peakIndex);
        peakRangeM = scan.focusRangeM(peakIndex);

        centeredPower = abs(observation).^2 - noiseVariance;
        powerCorrelation = real(powerBank' * centeredPower);
        powerScore = max(powerCorrelation, 0).^2 ./ powerEnergy;
        [~, powerIndex] = max(powerScore, [], 1);
        powerThetaDeg = candidateThetaDeg(powerIndex);
        powerRangeM = candidateRangeM(powerIndex);

        complexScore = abs(responseBank' * observation).^2 ./ responseEnergy;
        [~, complexIndex] = max(complexScore, [], 1);
        complexThetaDeg = candidateThetaDeg(complexIndex);
        complexRangeM = candidateRangeM(complexIndex);

        estimateThetaDeg = [peakThetaDeg(:).'; powerThetaDeg(:).'; ...
            complexThetaDeg(:).'];
        estimateRangeM = [peakRangeM(:).'; powerRangeM(:).'; ...
            complexRangeM(:).'];
        angleErrorDeg = estimateThetaDeg - truthThetaDeg(locationIndex);
        rangeErrorM = estimateRangeM - truthRangeM(locationIndex);
        captured = abs(angleErrorDeg) <= 1 & abs(rangeErrorM) <= 1;

        rows = rowIndex + (1:numMethods);
        method(rows) = methodNames;
        location(rows) = locationLabel(locationIndex);
        thetaDeg(rows) = truthThetaDeg(locationIndex);
        rangeM(rows) = truthRangeM(locationIndex);
        snrDb(rows) = snrDbValues(snrIndex);
        angleRmseDeg(rows) = sqrt(mean(angleErrorDeg.^2, 2));
        rangeRmseM(rows) = sqrt(mean(rangeErrorM.^2, 2));
        scaledPositionRmse(rows) = sqrt(mean( ...
            angleErrorDeg.^2 + rangeErrorM.^2, 2));
        captureRate(rows) = mean(captured, 2);
        rowIndex = rowIndex + numMethods;
    end
end

summary = table(method, location, thetaDeg, rangeM, snrDb, ...
    angleRmseDeg, rangeRmseM, scaledPositionRmse, captureRate);
aggregate = groupsummary(summary, ["method", "snrDb"], "mean", ...
    ["angleRmseDeg", "rangeRmseM", "scaledPositionRmse", "captureRate"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(summary, fullfile(outputFolder, "monte_carlo_global_points.csv"));
writetable(aggregate, fullfile(outputFolder, "monte_carlo_global_summary.csv"));
save(fullfile(outputFolder, "monte_carlo_global.mat"), ...
    "cfg", "candidateThetaDeg", "candidateRangeM", "locationLabel", ...
    "truthThetaDeg", "truthRangeM", "snrDbValues", "numTrials", ...
    "summary", "aggregate");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 410]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotAggregate(aggregate, methodNames, "mean_scaledPositionRmse", ...
    "Scaled position RMSE", "RMSE in 1 degree / 1 m units", true);
plotAggregate(aggregate, methodNames, "mean_captureRate", ...
    "Fixed-window capture rate", "Probability", false);
title(layout, sprintf("Global-grid Monte Carlo, %d trials per location/SNR", ...
    numTrials));
exportgraphics(figureHandle, ...
    fullfile(outputFolder, "monte_carlo_global.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "monte_carlo_global.fig"));
close(figureHandle);

disp(aggregate);
end

function plotAggregate(aggregate, methodNames, variableName, plotTitle, yLabel, useLog)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methodNames)
    rows = aggregate.method == methodNames(methodIndex);
    if useLog
        semilogy(aggregate.snrDb(rows), aggregate.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=6);
    else
        plot(aggregate.snrDb(rows), aggregate.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=6);
    end
end
hold off;
grid on;
xlabel("Output SNR (dB)");
ylabel(yLabel);
title(plotTitle);
legend(methodNames, Location="best");
end
