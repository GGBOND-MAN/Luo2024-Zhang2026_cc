function run_single_rf_equal_budget
%RUN_SINGLE_RF_EQUAL_BUDGET Compare feasible MUSIC acquisition budgets.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
location = ["Interior positive"; "Interior negative"; "Near boundary"];
truthThetaDeg = [15; -30; 55];
truthRangeM = [30; 35; 47.5];
snrDbValues = [-10, 0, 10, 20, 30];
numTrials = 30;
centerCarrier = round(cfg.numSubcarriers / 2);
halfCarrierCount = floor(cfg.numFusionCarriers / 2);
carrierIndex = (centerCarrier-halfCarrierCount: ...
    centerCarrier+halfCarrierCount).';
methodNames = ["Fully digital, one symbol"; ...
    "One RF, fixed symbol energy"; "One RF, fixed total energy"];
numMethods = numel(methodNames);
numRows = numMethods * numel(location) * numel(snrDbValues);

method = strings(numRows, 1);
locationColumn = strings(numRows, 1);
snrDb = zeros(numRows, 1);
effectiveArraySnrDb = zeros(numRows, 1);
rfChains = zeros(numRows, 1);
trainingSymbols = zeros(numRows, 1);
relativeTransmitEnergy = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
captureRate = zeros(numRows, 1);
rowIndex = 0;
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 701);
fixedTotalScale = 1 / sqrt(cfg.numAntennas);
snrPenaltyDb = 20 * log10(fixedTotalScale);

for locationIndex = 1:numel(location)
    noiselessSnapshots = noiselessArraySnapshots(cfg, ...
        truthThetaDeg(locationIndex), truthRangeM(locationIndex), carrierIndex);
    for snrIndex = 1:numel(snrDbValues)
        noiseStd = 10^(-snrDbValues(snrIndex) / 20);
        estimatedThetaDeg = zeros(numMethods, numTrials);
        estimatedRangeM = zeros(numMethods, numTrials);
        for trialIndex = 1:numTrials
            digitalNoise = noiseStd / sqrt(2) * ( ...
                randn(stream, size(noiselessSnapshots)) ...
                + 1i * randn(stream, size(noiselessSnapshots)));
            digitalSnapshots = noiselessSnapshots + digitalNoise;
            fixedSymbolSnapshots = fsjad.singleRfArrayAcquisition( ...
                noiselessSnapshots, noiseStd, 1, stream);
            fixedTotalSnapshots = fsjad.singleRfArrayAcquisition( ...
                noiselessSnapshots, noiseStd, fixedTotalScale, stream);

            digitalEstimate = jad.localMusicEstimate(cfg, digitalSnapshots, ...
                carrierIndex, truthThetaDeg(locationIndex), ...
                truthRangeM(locationIndex));
            fixedSymbolEstimate = jad.localMusicEstimate(cfg, ...
                fixedSymbolSnapshots, carrierIndex, ...
                truthThetaDeg(locationIndex), truthRangeM(locationIndex));
            fixedTotalEstimate = jad.localMusicEstimate(cfg, ...
                fixedTotalSnapshots, carrierIndex, ...
                truthThetaDeg(locationIndex), truthRangeM(locationIndex));
            estimatedThetaDeg(:, trialIndex) = [digitalEstimate.thetaDeg; ...
                fixedSymbolEstimate.thetaDeg; fixedTotalEstimate.thetaDeg];
            estimatedRangeM(:, trialIndex) = [digitalEstimate.rangeM; ...
                fixedSymbolEstimate.rangeM; fixedTotalEstimate.rangeM];
        end

        angleError = estimatedThetaDeg - truthThetaDeg(locationIndex);
        rangeError = estimatedRangeM - truthRangeM(locationIndex);
        captured = abs(angleError) <= 1 & abs(rangeError) <= 1;
        rows = rowIndex + (1:numMethods);
        method(rows) = methodNames;
        locationColumn(rows) = location(locationIndex);
        snrDb(rows) = snrDbValues(snrIndex);
        effectiveArraySnrDb(rows) = [snrDbValues(snrIndex); ...
            snrDbValues(snrIndex); snrDbValues(snrIndex) + snrPenaltyDb];
        rfChains(rows) = [cfg.numAntennas; 1; 1];
        trainingSymbols(rows) = [1; cfg.numAntennas; cfg.numAntennas];
        relativeTransmitEnergy(rows) = [1; cfg.numAntennas; 1];
        angleRmseDeg(rows) = sqrt(mean(angleError.^2, 2));
        rangeRmseM(rows) = sqrt(mean(rangeError.^2, 2));
        captureRate(rows) = mean(captured, 2);
        rowIndex = rowIndex + numMethods;
    end
    fprintf("Completed equal-budget acquisition at %s.\n", ...
        location(locationIndex));
end

details = table(method, locationColumn, snrDb, effectiveArraySnrDb, ...
    rfChains, trainingSymbols, relativeTransmitEnergy, ...
    angleRmseDeg, rangeRmseM, captureRate);
summary = groupsummary(details, ["method", "snrDb"], "mean", ...
    ["effectiveArraySnrDb", "angleRmseDeg", "rangeRmseM", ...
    "captureRate"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round4");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, ...
    "single_rf_equal_budget_points.csv"));
writetable(summary, fullfile(outputFolder, ...
    "single_rf_equal_budget_summary.csv"));
save(fullfile(outputFolder, "single_rf_equal_budget.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "numTrials", "carrierIndex", "snrPenaltyDb", ...
    "details", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotBudgetMetric(summary, methodNames, "mean_captureRate", ...
    "Capture rate", false);
plotBudgetMetric(summary, methodNames, "mean_rangeRmseM", ...
    "Range RMSE (m)", true);
title(layout, "Local MUSIC under feasible RF-chain and energy budgets");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "single_rf_equal_budget.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "single_rf_equal_budget.fig"));
close(figureHandle);

disp(summary);
end

function snapshots = noiselessArraySnapshots(cfg, thetaDeg, rangeM, ...
    carrierIndex)
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
snapshots = complex(zeros(cfg.numAntennas, numel(carrierIndex)));
for carrierOffset = 1:numel(carrierIndex)
    snapshots(:, carrierOffset) = sqrt(cfg.numAntennas) ...
        * jad.steeringVector(cfg, thetaDeg, rangeM, ...
        frequencyHz(carrierOffset));
end
end

function plotBudgetMetric(summary, methodNames, variableName, yLabel, useLog)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    if useLog
        semilogy(summary.snrDb(rows), summary.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=5);
    else
        plot(summary.snrDb(rows), summary.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=5);
    end
end
hold off; grid on;
xlabel("Nominal per-symbol SNR (dB)"); ylabel(yLabel);
legend(methodNames, Location="best");
end
