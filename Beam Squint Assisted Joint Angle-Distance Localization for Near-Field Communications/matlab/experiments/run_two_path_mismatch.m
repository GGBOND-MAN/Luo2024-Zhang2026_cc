function run_two_path_mismatch
%RUN_TWO_PATH_MISMATCH Test pseudo-peaks from an unmodelled second path.

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

location = ["Center"; "Positive angle"; "Negative angle"; "Long range"];
mainThetaDeg = [0; 15; -30; 35];
mainRangeM = [25; 30; 35; 40];
separation = ["Range 2.5 m"; "Range 10 m"; "Angle 5 deg"; ...
    "Angle 15 deg"; "Joint 5 deg, 2.5 m"];
secondaryThetaOffsetDeg = [0; 0; 5; 15; 5];
secondaryRangeOffsetM = [2.5; 10; 0; 0; 2.5];
relativePowerDbValues = [-20, -10, -6, -3];
snrDbValues = [10, 20];
numTrials = 100;
methodNames = ["Peak index"; "Full power spectrum"; ...
    "Full complex spectrum"];
numMethods = numel(methodNames);
numRows = numMethods * numel(location) * numel(separation) ...
    * numel(relativePowerDbValues) * numel(snrDbValues);

method = strings(numRows, 1);
locationColumn = strings(numRows, 1);
separationColumn = strings(numRows, 1);
snrDb = zeros(numRows, 1);
relativePowerDb = zeros(numRows, 1);
mainCaptureRate = zeros(numRows, 1);
secondarySelectionRate = zeros(numRows, 1);
pseudoPeakRate = zeros(numRows, 1);
angleBiasDeg = zeros(numRows, 1);
rangeBiasM = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
complexMainMinusSecondaryScore = zeros(numRows, 1);
complexTopTwoGap = zeros(numRows, 1);
rowIndex = 0;
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 401);

for locationIndex = 1:numel(location)
    mainIndex = find(bank.thetaDeg == mainThetaDeg(locationIndex) ...
        & bank.rangeM == mainRangeM(locationIndex), 1);
    mainResponse = bank.response(:, mainIndex);
    mainSignalPower = mean(abs(mainResponse).^2);

    for separationIndex = 1:numel(separation)
        secondaryThetaDeg = mainThetaDeg(locationIndex) ...
            + secondaryThetaOffsetDeg(separationIndex);
        secondaryRangeM = mainRangeM(locationIndex) ...
            + secondaryRangeOffsetM(separationIndex);
        secondaryIndex = find(bank.thetaDeg == secondaryThetaDeg ...
            & bank.rangeM == secondaryRangeM, 1);
        secondaryResponse = bank.response(:, secondaryIndex);

        for snrIndex = 1:numel(snrDbValues)
            noiseVariance = mainSignalPower ...
                / 10^(snrDbValues(snrIndex) / 10);
            for powerIndex = 1:numel(relativePowerDbValues)
                relativeAmplitude = 10^(relativePowerDbValues(powerIndex) / 20);
                commonPhase = 2 * pi * rand(stream, 1, numTrials);
                relativePhase = 2 * pi * rand(stream, 1, numTrials);
                noise = sqrt(noiseVariance / 2) * ( ...
                    randn(stream, cfg.numSubcarriers, numTrials) ...
                    + 1i * randn(stream, cfg.numSubcarriers, numTrials));
                signal = mainResponse + relativeAmplitude ...
                    * secondaryResponse .* exp(1i * relativePhase);
                observation = signal .* exp(1i * commonPhase) + noise;

                [~, peakIndex] = max(abs(observation).^2, [], 1);
                peakThetaDeg = scan.focusThetaDeg(peakIndex);
                peakRangeM = scan.focusRangeM(peakIndex);

                centeredPower = abs(observation).^2 - noiseVariance;
                powerCorrelation = real(powerBank' * centeredPower);
                powerScore = max(powerCorrelation, 0).^2 ./ powerEnergy;
                [~, estimatedPowerIndex] = max(powerScore, [], 1);
                powerThetaDeg = bank.thetaDeg(estimatedPowerIndex);
                powerRangeM = bank.rangeM(estimatedPowerIndex);

                observationEnergy = sum(abs(observation).^2, 1);
                complexScore = abs(bank.response' * observation).^2 ...
                    ./ bank.energy ./ observationEnergy;
                [topScore, estimatedComplexIndex] = max(complexScore, [], 1);
                complexThetaDeg = bank.thetaDeg(estimatedComplexIndex);
                complexRangeM = bank.rangeM(estimatedComplexIndex);
                topTwoScore = maxk(complexScore, 2, 1);

                estimateThetaDeg = [peakThetaDeg(:).'; powerThetaDeg(:).'; ...
                    complexThetaDeg(:).'];
                estimateRangeM = [peakRangeM(:).'; powerRangeM(:).'; ...
                    complexRangeM(:).'];
                angleError = estimateThetaDeg - mainThetaDeg(locationIndex);
                rangeError = estimateRangeM - mainRangeM(locationIndex);
                mainCaptured = abs(angleError) <= 1 & abs(rangeError) <= 1;
                secondarySelected = abs(estimateThetaDeg - secondaryThetaDeg) ...
                    <= 1 & abs(estimateRangeM - secondaryRangeM) <= 1;
                pseudoSelected = ~(mainCaptured | secondarySelected);

                rows = rowIndex + (1:numMethods);
                method(rows) = methodNames;
                locationColumn(rows) = location(locationIndex);
                separationColumn(rows) = separation(separationIndex);
                snrDb(rows) = snrDbValues(snrIndex);
                relativePowerDb(rows) = relativePowerDbValues(powerIndex);
                mainCaptureRate(rows) = mean(mainCaptured, 2);
                secondarySelectionRate(rows) = mean(secondarySelected, 2);
                pseudoPeakRate(rows) = mean(pseudoSelected, 2);
                angleBiasDeg(rows) = mean(angleError, 2);
                rangeBiasM(rows) = mean(rangeError, 2);
                angleRmseDeg(rows) = sqrt(mean(angleError.^2, 2));
                rangeRmseM(rows) = sqrt(mean(rangeError.^2, 2));
                complexMainMinusSecondaryScore(rows) = mean( ...
                    complexScore(mainIndex, :) ...
                    - complexScore(secondaryIndex, :));
                complexTopTwoGap(rows) = mean(topScore - topTwoScore(2, :));
                rowIndex = rowIndex + numMethods;
            end
        end
    end
end

details = table(method, locationColumn, separationColumn, snrDb, ...
    relativePowerDb, mainCaptureRate, secondarySelectionRate, ...
    pseudoPeakRate, angleBiasDeg, rangeBiasM, angleRmseDeg, rangeRmseM, ...
    complexMainMinusSecondaryScore, complexTopTwoGap);
summary = groupsummary(details, ...
    ["method", "separationColumn", "snrDb", "relativePowerDb"], ...
    "mean", ["mainCaptureRate", "secondarySelectionRate", ...
    "pseudoPeakRate", "angleBiasDeg", "rangeBiasM", ...
    "angleRmseDeg", "rangeRmseM", ...
    "complexMainMinusSecondaryScore", "complexTopTwoGap"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round3");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, "two_path_mismatch_points.csv"));
writetable(summary, fullfile(outputFolder, "two_path_mismatch_summary.csv"));
save(fullfile(outputFolder, "two_path_mismatch.mat"), ...
    "cfg", "location", "mainThetaDeg", "mainRangeM", "separation", ...
    "secondaryThetaOffsetDeg", "secondaryRangeOffsetM", ...
    "relativePowerDbValues", "snrDbValues", "numTrials", ...
    "details", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1140, 760]);
layout = tiledlayout(2, 2, TileSpacing="compact", Padding="compact");
plotSelection(summary, methodNames, separation(1), 20);
plotSelection(summary, methodNames, separation(2), 20);
plotSelection(summary, methodNames, separation(3), 20);
plotSelection(summary, methodNames, separation(5), 20);
title(layout, sprintf("Two-path main-component capture, %d trials", ...
    numTrials));
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "two_path_mismatch.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "two_path_mismatch.fig"));
close(figureHandle);

disp(summary);
end

function plotSelection(summary, methodNames, separationName, snrDb)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex) ...
        & summary.separationColumn == separationName ...
        & summary.snrDb == snrDb;
    plot(summary.relativePowerDb(rows), ...
        summary.mean_mainCaptureRate(rows), lineStyle(methodIndex), ...
        LineWidth=1.5, MarkerSize=5);
end
hold off;
grid on; ylim([0, 1.02]);
xlabel("Relative second-path power (dB)");
ylabel("Main-path capture rate");
title(separationName);
legend(methodNames, Location="best");
end
