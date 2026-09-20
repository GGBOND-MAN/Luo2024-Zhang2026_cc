function run_capture_probability
%RUN_CAPTURE_PROBABILITY Compare fixed and EFIM-driven search regions.

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
parameterScale = diag([deg2rad(1), 1]);

responseBank = complex(zeros(cfg.numSubcarriers, numCandidates));
scaledBaseInformation = zeros(2, 2, numCandidates);
for candidateIndex = 1:numCandidates
    [responseBank(:, candidateIndex), derivative] = ...
        fsjad.exactSpectralResponse(cfg, ...
        deg2rad(candidateThetaDeg(candidateIndex)), ...
        candidateRangeM(candidateIndex), scan);
    baseInformation = fsjad.projectedEfim(responseBank(:, candidateIndex), ...
        derivative, 1, 1);
    scaledBaseInformation(:, :, candidateIndex) = ...
        parameterScale.' * baseInformation * parameterScale;
end
responseEnergy = real(sum(abs(responseBank).^2, 1)).';

location = ["Weak EFIM"; "Strong EFIM"; "Known counterexample"; ...
    "Left boundary"; "Right boundary"; "Interior"];
truthThetaDeg = [0; -55; 15; -60; 60; 30];
truthRangeM = [15; 22.5; 30; 15; 50; 40];
snrDbValues = [-10, 0, 10, 20];
numTrials = 100;
methodNames = ["Peak + fixed"; "Complex top-1 + fixed"; ...
    "Complex top-1 + EFIM"; "Complex top-3 + EFIM"];
numMethods = numel(methodNames);
numRows = numMethods * numel(location) * numel(snrDbValues);
chiSquare95 = -2 * log(0.05);
fixedArea = 4;

method = strings(numRows, 1);
locationColumn = strings(numRows, 1);
thetaDeg = zeros(numRows, 1);
rangeM = zeros(numRows, 1);
snrDb = zeros(numRows, 1);
captureRate = zeros(numRows, 1);
meanSearchAreaDegM = zeros(numRows, 1);
medianSearchAreaDegM = zeros(numRows, 1);
rowIndex = 0;

stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 61);
for locationIndex = 1:numel(location)
    truthIndex = find(candidateThetaDeg == truthThetaDeg(locationIndex) ...
        & candidateRangeM == truthRangeM(locationIndex), 1);
    truthResponse = responseBank(:, truthIndex);
    signalPower = mean(abs(truthResponse).^2);

    for snrIndex = 1:numel(snrDbValues)
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        commonPhase = 2 * pi * rand(stream, 1, numTrials);
        noise = sqrt(noiseVariance / 2) * ( ...
            randn(stream, cfg.numSubcarriers, numTrials) ...
            + 1i * randn(stream, cfg.numSubcarriers, numTrials));
        observation = truthResponse .* exp(1i * commonPhase) + noise;

        [~, peakIndex] = max(abs(observation).^2, [], 1);
        peakAngleErrorDeg = scan.focusThetaDeg(peakIndex) ...
            - truthThetaDeg(locationIndex);
        peakRangeErrorM = scan.focusRangeM(peakIndex) ...
            - truthRangeM(locationIndex);
        peakFixedCaptured = abs(peakAngleErrorDeg) <= 1 ...
            & abs(peakRangeErrorM) <= 1;

        correlation = responseBank' * observation;
        complexScore = abs(correlation).^2 ./ responseEnergy;
        [~, sortedIndex] = sort(complexScore, 1, "descend");
        topIndex = sortedIndex(1:3, :);
        topThetaDeg = reshape(candidateThetaDeg(topIndex), 3, numTrials);
        topRangeM = reshape(candidateRangeM(topIndex), 3, numTrials);
        topFixedCaptured = abs(topThetaDeg(1, :) ...
            - truthThetaDeg(locationIndex)) <= 1 ...
            & abs(topRangeM(1, :) - truthRangeM(locationIndex)) <= 1;

        ellipseCaptured = false(3, numTrials);
        ellipseArea = zeros(3, numTrials);
        for rankIndex = 1:3
            for trialIndex = 1:numTrials
                candidateIndex = topIndex(rankIndex, trialIndex);
                betaMagnitudeSquared = abs(correlation(candidateIndex, trialIndex) ...
                    / responseEnergy(candidateIndex))^2;
                information = betaMagnitudeSquared / noiseVariance ...
                    * scaledBaseInformation(:, :, candidateIndex);
                offset = [truthThetaDeg(locationIndex) ...
                    - candidateThetaDeg(candidateIndex); ...
                    truthRangeM(locationIndex) - candidateRangeM(candidateIndex)];
                ellipseCaptured(rankIndex, trialIndex) = ...
                    offset.' * information * offset <= chiSquare95;
                ellipseArea(rankIndex, trialIndex) = pi * chiSquare95 ...
                    / sqrt(det(information));
            end
        end
        topOneEllipseCaptured = ellipseCaptured(1, :);
        topThreeEllipseCaptured = any(ellipseCaptured, 1);
        topOneEllipseArea = ellipseArea(1, :);
        topThreeEllipseArea = sum(ellipseArea, 1);

        captured = [peakFixedCaptured(:).'; topFixedCaptured(:).'; ...
            topOneEllipseCaptured(:).'; topThreeEllipseCaptured(:).'];
        searchArea = [fixedArea * ones(2, numTrials); ...
            topOneEllipseArea; topThreeEllipseArea];
        rows = rowIndex + (1:numMethods);
        method(rows) = methodNames;
        locationColumn(rows) = location(locationIndex);
        thetaDeg(rows) = truthThetaDeg(locationIndex);
        rangeM(rows) = truthRangeM(locationIndex);
        snrDb(rows) = snrDbValues(snrIndex);
        captureRate(rows) = mean(captured, 2);
        meanSearchAreaDegM(rows) = mean(searchArea, 2);
        medianSearchAreaDegM(rows) = median(searchArea, 2);
        rowIndex = rowIndex + numMethods;
    end
end

details = table(method, locationColumn, thetaDeg, rangeM, snrDb, ...
    captureRate, meanSearchAreaDegM, medianSearchAreaDegM);
summary = groupsummary(details, ["method", "snrDb"], "mean", ...
    ["captureRate", "meanSearchAreaDegM", "medianSearchAreaDegM"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, "capture_probability_points.csv"));
writetable(summary, fullfile(outputFolder, "capture_probability_summary.csv"));
save(fullfile(outputFolder, "capture_probability.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "numTrials", "chiSquare95", "details", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 410]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotSummary(summary, methodNames, "mean_captureRate", ...
    "Capture probability", "Probability", false);
plotSummary(summary, methodNames, "mean_meanSearchAreaDegM", ...
    "Continuous search area", "degree m", true);
title(layout, sprintf("Fixed windows versus 95%% EFIM regions, %d trials", ...
    numTrials));
exportgraphics(figureHandle, ...
    fullfile(outputFolder, "capture_probability.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "capture_probability.fig"));
close(figureHandle);

disp(summary);
end

function plotSummary(summary, methodNames, variableName, plotTitle, yLabel, useLog)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^", "-d"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    if useLog
        semilogy(summary.snrDb(rows), summary.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=6);
    else
        plot(summary.snrDb(rows), summary.(variableName)(rows), ...
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
