function run_full_spectrum_music
%RUN_FULL_SPECTRUM_MUSIC Connect both coarse estimators to identical MUSIC data.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
location = ["Known counterexample"; "Off-grid interior"; "Trajectory endpoint"];
truthThetaDeg = [15; 12.3; -60];
truthRangeM = [30; 34.2; 15];
snrDbValues = [-10, 0, 10, 20];
numTrials = 20;
methodNames = ["Peak to MUSIC"; "Complex to MUSIC"];
numMethods = numel(methodNames);
numRows = numMethods * numel(location) * numel(snrDbValues);

centerCarrier = round(cfg.numSubcarriers / 2);
halfCarrierCount = floor(cfg.numFusionCarriers / 2);
carrierIndex = (centerCarrier-halfCarrierCount: ...
    centerCarrier+halfCarrierCount).';

method = strings(numRows, 1);
locationColumn = strings(numRows, 1);
thetaDeg = zeros(numRows, 1);
rangeM = zeros(numRows, 1);
snrDb = zeros(numRows, 1);
coarseAngleRmseDeg = zeros(numRows, 1);
coarseRangeRmseM = zeros(numRows, 1);
coarseCaptureRate = zeros(numRows, 1);
finalAngleRmseDeg = zeros(numRows, 1);
finalRangeRmseM = zeros(numRows, 1);
finalCaptureRate = zeros(numRows, 1);
scalarComplexSamples = cfg.numSubcarriers * ones(numRows, 1);
arrayComplexSamples = cfg.numAntennas * numel(carrierIndex) * ones(numRows, 1);
rowIndex = 0;

stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 73);
for locationIndex = 1:numel(location)
    truthResponse = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(truthThetaDeg(locationIndex)), truthRangeM(locationIndex), scan);
    signalPower = mean(abs(truthResponse).^2);

    for snrIndex = 1:numel(snrDbValues)
        coarseTheta = zeros(numMethods, numTrials);
        coarseRange = zeros(numMethods, numTrials);
        finalTheta = zeros(numMethods, numTrials);
        finalRange = zeros(numMethods, numTrials);
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);

        for trialIndex = 1:numTrials
            commonPhase = 2 * pi * rand(stream);
            scalarNoise = sqrt(noiseVariance / 2) * ( ...
                randn(stream, cfg.numSubcarriers, 1) ...
                + 1i * randn(stream, cfg.numSubcarriers, 1));
            scalarObservation = truthResponse * exp(1i * commonPhase) ...
                + scalarNoise;
            snapshots = jad.simulateSnapshots(cfg, ...
                truthThetaDeg(locationIndex), truthRangeM(locationIndex), ...
                snrDbValues(snrIndex), carrierIndex, stream);

            [~, peakIndex] = max(abs(scalarObservation).^2);
            peakTheta = scan.focusThetaDeg(peakIndex);
            peakRange = scan.focusRangeM(peakIndex);
            peakMusic = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
                peakTheta, peakRange);

            fullMusic = fsjad.fullSpectrumMusicEstimate(cfg, ...
                scalarObservation, snapshots, carrierIndex, scan);
            coarseTheta(:, trialIndex) = [peakTheta; ...
                fullMusic.refinedCoarse.thetaDeg];
            coarseRange(:, trialIndex) = [peakRange; ...
                fullMusic.refinedCoarse.rangeM];
            finalTheta(:, trialIndex) = [peakMusic.thetaDeg; fullMusic.thetaDeg];
            finalRange(:, trialIndex) = [peakMusic.rangeM; fullMusic.rangeM];
        end

        coarseAngleError = coarseTheta - truthThetaDeg(locationIndex);
        coarseRangeError = coarseRange - truthRangeM(locationIndex);
        finalAngleError = finalTheta - truthThetaDeg(locationIndex);
        finalRangeError = finalRange - truthRangeM(locationIndex);
        rows = rowIndex + (1:numMethods);
        method(rows) = methodNames;
        locationColumn(rows) = location(locationIndex);
        thetaDeg(rows) = truthThetaDeg(locationIndex);
        rangeM(rows) = truthRangeM(locationIndex);
        snrDb(rows) = snrDbValues(snrIndex);
        coarseAngleRmseDeg(rows) = sqrt(mean(coarseAngleError.^2, 2));
        coarseRangeRmseM(rows) = sqrt(mean(coarseRangeError.^2, 2));
        coarseCaptureRate(rows) = mean(abs(coarseAngleError) <= 1 ...
            & abs(coarseRangeError) <= 1, 2);
        finalAngleRmseDeg(rows) = sqrt(mean(finalAngleError.^2, 2));
        finalRangeRmseM(rows) = sqrt(mean(finalRangeError.^2, 2));
        finalCaptureRate(rows) = mean(abs(finalAngleError) <= 1 ...
            & abs(finalRangeError) <= 1, 2);
        rowIndex = rowIndex + numMethods;
    end
end

details = table(method, locationColumn, thetaDeg, rangeM, snrDb, ...
    coarseAngleRmseDeg, coarseRangeRmseM, coarseCaptureRate, ...
    finalAngleRmseDeg, finalRangeRmseM, finalCaptureRate, ...
    scalarComplexSamples, arrayComplexSamples);
summary = groupsummary(details, ["method", "snrDb"], "mean", ...
    ["coarseAngleRmseDeg", "coarseRangeRmseM", "coarseCaptureRate", ...
    "finalAngleRmseDeg", "finalRangeRmseM", "finalCaptureRate"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, "full_spectrum_music_points.csv"));
writetable(summary, fullfile(outputFolder, "full_spectrum_music_summary.csv"));
save(fullfile(outputFolder, "full_spectrum_music.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "numTrials", "carrierIndex", "details", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 410]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotPipeline(summary, methodNames, "mean_finalAngleRmseDeg", ...
    "Final angle RMSE", "degrees");
plotPipeline(summary, methodNames, "mean_finalRangeRmseM", ...
    "Final range RMSE", "m");
title(layout, sprintf("Identical local MUSIC observations, %d trials", numTrials));
exportgraphics(figureHandle, ...
    fullfile(outputFolder, "full_spectrum_music.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "full_spectrum_music.fig"));
close(figureHandle);

disp(summary);
end

function plotPipeline(summary, methodNames, variableName, plotTitle, yLabel)
nexttile;
hold on;
lineStyle = ["-o", "-s"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.(variableName)(rows), ...
        lineStyle(methodIndex), LineWidth=1.5, MarkerSize=6);
end
hold off;
grid on;
xlabel("SNR label (dB)");
ylabel(yLabel);
title(plotTitle);
legend(methodNames, Location="best");
end
