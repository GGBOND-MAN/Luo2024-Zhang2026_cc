function run_music_failure_attribution
%RUN_MUSIC_FAILURE_ATTRIBUTION Diagnose local MUSIC degradation sources.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
location = ["Known counterexample"; "Off-grid interior"; "Weak EFIM"];
truthThetaDeg = [15; 12.3; 0];
truthRangeM = [30; 34.2; 15];
snrDbValues = [-10, 0, 10, 20];
numTrials = 50;
centerCarrier = round(cfg.numSubcarriers / 2);
carrierIndex = centeredCarrierIndex(centerCarrier, cfg.numFusionCarriers);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 801);

numControlRows = numel(location);
controlLocation = location;
fresnelAngleErrorDeg = zeros(numControlRows, 1);
fresnelRangeErrorM = zeros(numControlRows, 1);
exactAngleErrorDeg = zeros(numControlRows, 1);
exactRangeErrorM = zeros(numControlRows, 1);
exactFresnelSubspaceCoherence = zeros(numControlRows, 1);

numRows = numel(location) * numel(snrDbValues) * numTrials;
trialLocation = strings(numRows, 1);
trialSnrDb = zeros(numRows, 1);
angleErrorDeg = zeros(numRows, 1);
rangeErrorM = zeros(numRows, 1);
captured = false(numRows, 1);
firstGridBoundaryPeak = false(numRows, 1);
finalOutsideInitialWindow = false(numRows, 1);
meanSignalSubspaceCoherence = zeros(numRows, 1);
initialPeakToMedianRatio = zeros(numRows, 1);
rowIndex = 0;

for locationIndex = 1:numel(location)
    fresnelSnapshots = noiselessFresnelSnapshots(cfg, ...
        truthThetaDeg(locationIndex), truthRangeM(locationIndex), carrierIndex);
    exactSnapshots = noiselessExactSnapshots(cfg, ...
        truthThetaDeg(locationIndex), truthRangeM(locationIndex), carrierIndex);
    fresnelControl = jad.localMusicEstimate(cfg, fresnelSnapshots, ...
        carrierIndex, truthThetaDeg(locationIndex), truthRangeM(locationIndex));
    exactControl = jad.localMusicEstimate(cfg, exactSnapshots, carrierIndex, ...
        truthThetaDeg(locationIndex), truthRangeM(locationIndex));
    fresnelAngleErrorDeg(locationIndex) = fresnelControl.thetaDeg ...
        - truthThetaDeg(locationIndex);
    fresnelRangeErrorM(locationIndex) = fresnelControl.rangeM ...
        - truthRangeM(locationIndex);
    exactAngleErrorDeg(locationIndex) = exactControl.thetaDeg ...
        - truthThetaDeg(locationIndex);
    exactRangeErrorM(locationIndex) = exactControl.rangeM ...
        - truthRangeM(locationIndex);
    exactFresnelSubspaceCoherence(locationIndex) = mean(abs(sum( ...
        conj(fresnelControl.signalVectors) .* exactControl.signalVectors, 1)).^2);

    for snrIndex = 1:numel(snrDbValues)
        noiseStd = 10^(-snrDbValues(snrIndex) / 20);
        for trialIndex = 1:numTrials
            noise = noiseStd / sqrt(2) * ( ...
                randn(stream, size(fresnelSnapshots)) ...
                + 1i * randn(stream, size(fresnelSnapshots)));
            result = jad.localMusicEstimate(cfg, fresnelSnapshots + noise, ...
                carrierIndex, truthThetaDeg(locationIndex), ...
                truthRangeM(locationIndex));
            [boundaryPeak, peakToMedian] = initialSpectrumMetrics( ...
                result.initialSpectrum);
            rowIndex = rowIndex + 1;
            trialLocation(rowIndex) = location(locationIndex);
            trialSnrDb(rowIndex) = snrDbValues(snrIndex);
            angleErrorDeg(rowIndex) = result.thetaDeg ...
                - truthThetaDeg(locationIndex);
            rangeErrorM(rowIndex) = result.rangeM ...
                - truthRangeM(locationIndex);
            captured(rowIndex) = abs(angleErrorDeg(rowIndex)) <= 1 ...
                && abs(rangeErrorM(rowIndex)) <= 1;
            firstGridBoundaryPeak(rowIndex) = boundaryPeak;
            finalOutsideInitialWindow(rowIndex) = ...
                abs(angleErrorDeg(rowIndex)) > cfg.localHalfWidthDeg ...
                || abs(rangeErrorM(rowIndex)) > cfg.localHalfWidthM;
            meanSignalSubspaceCoherence(rowIndex) = mean(abs(sum( ...
                conj(fresnelControl.signalVectors) ...
                .* result.signalVectors, 1)).^2);
            initialPeakToMedianRatio(rowIndex) = peakToMedian;
        end
    end
    fprintf("Completed MUSIC diagnostics at %s.\n", location(locationIndex));
end

controls = table(controlLocation, fresnelAngleErrorDeg, ...
    fresnelRangeErrorM, exactAngleErrorDeg, exactRangeErrorM, ...
    exactFresnelSubspaceCoherence);
trials = table(trialLocation, trialSnrDb, angleErrorDeg, rangeErrorM, ...
    captured, firstGridBoundaryPeak, finalOutsideInitialWindow, ...
    meanSignalSubspaceCoherence, initialPeakToMedianRatio);
summary = groupsummary(trials, "trialSnrDb", "mean", ...
    ["angleErrorDeg", "rangeErrorM", "captured", ...
    "firstGridBoundaryPeak", "finalOutsideInitialWindow", ...
    "meanSignalSubspaceCoherence", "initialPeakToMedianRatio"]);

fusionCounts = [1; 3; 5; 9; 17];
fusionSnrDbValues = [-10, 0, 10];
numFusionTrials = 20;
numFusionRows = numel(location) * numel(fusionSnrDbValues) ...
    * numel(fusionCounts);
fusionLocation = strings(numFusionRows, 1);
fusionSnrDb = zeros(numFusionRows, 1);
numFusionCarriers = zeros(numFusionRows, 1);
fusionAngleRmseDeg = zeros(numFusionRows, 1);
fusionRangeRmseM = zeros(numFusionRows, 1);
fusionCaptureRate = zeros(numFusionRows, 1);
fusionRow = 0;
maxCarrierIndex = centeredCarrierIndex(centerCarrier, max(fusionCounts));

for locationIndex = 1:numel(location)
    maxSnapshots = noiselessFresnelSnapshots(cfg, ...
        truthThetaDeg(locationIndex), truthRangeM(locationIndex), ...
        maxCarrierIndex);
    for snrIndex = 1:numel(fusionSnrDbValues)
        noiseStd = 10^(-fusionSnrDbValues(snrIndex) / 20);
        estimateThetaDeg = zeros(numel(fusionCounts), numFusionTrials);
        estimateRangeM = zeros(numel(fusionCounts), numFusionTrials);
        for trialIndex = 1:numFusionTrials
            noise = noiseStd / sqrt(2) * ( ...
                randn(stream, size(maxSnapshots)) ...
                + 1i * randn(stream, size(maxSnapshots)));
            noisyMaxSnapshots = maxSnapshots + noise;
            for countIndex = 1:numel(fusionCounts)
                selectedColumns = centeredColumns( ...
                    numel(maxCarrierIndex), fusionCounts(countIndex));
                result = jad.localMusicEstimate(cfg, ...
                    noisyMaxSnapshots(:, selectedColumns), ...
                    maxCarrierIndex(selectedColumns), ...
                    truthThetaDeg(locationIndex), truthRangeM(locationIndex));
                estimateThetaDeg(countIndex, trialIndex) = result.thetaDeg;
                estimateRangeM(countIndex, trialIndex) = result.rangeM;
            end
        end
        angleError = estimateThetaDeg - truthThetaDeg(locationIndex);
        rangeError = estimateRangeM - truthRangeM(locationIndex);
        for countIndex = 1:numel(fusionCounts)
            fusionRow = fusionRow + 1;
            fusionLocation(fusionRow) = location(locationIndex);
            fusionSnrDb(fusionRow) = fusionSnrDbValues(snrIndex);
            numFusionCarriers(fusionRow) = fusionCounts(countIndex);
            fusionAngleRmseDeg(fusionRow) = sqrt(mean( ...
                angleError(countIndex, :).^2));
            fusionRangeRmseM(fusionRow) = sqrt(mean( ...
                rangeError(countIndex, :).^2));
            fusionCaptureRate(fusionRow) = mean( ...
                abs(angleError(countIndex, :)) <= 1 ...
                & abs(rangeError(countIndex, :)) <= 1);
        end
    end
end

fusionDetails = table(fusionLocation, fusionSnrDb, numFusionCarriers, ...
    fusionAngleRmseDeg, fusionRangeRmseM, fusionCaptureRate);
fusionSummary = groupsummary(fusionDetails, ...
    ["fusionSnrDb", "numFusionCarriers"], "mean", ...
    ["fusionAngleRmseDeg", "fusionRangeRmseM", "fusionCaptureRate"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round4");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(controls, fullfile(outputFolder, ...
    "music_failure_controls.csv"));
writetable(trials, fullfile(outputFolder, ...
    "music_failure_trials.csv"));
writetable(summary, fullfile(outputFolder, ...
    "music_failure_summary.csv"));
writetable(fusionDetails, fullfile(outputFolder, ...
    "music_fusion_sweep_points.csv"));
writetable(fusionSummary, fullfile(outputFolder, ...
    "music_fusion_sweep_summary.csv"));
save(fullfile(outputFolder, "music_failure_attribution.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "numTrials", "carrierIndex", "controls", ...
    "trials", "summary", "fusionCounts", "fusionSnrDbValues", ...
    "numFusionTrials", "fusionDetails", "fusionSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
plot(summary.trialSnrDb, summary.mean_captured, "-o", ...
    summary.trialSnrDb, summary.mean_firstGridBoundaryPeak, "-s", ...
    summary.trialSnrDb, summary.mean_finalOutsideInitialWindow, "-^", ...
    LineWidth=1.5, MarkerSize=6);
grid on; ylim([0, 1.02]);
xlabel("SNR (dB)"); ylabel("Probability");
legend("Capture", "First-grid boundary", "Escaped initial window", ...
    Location="best");
title("Local spectrum failure mode");
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^"];
for snrIndex = 1:numel(fusionSnrDbValues)
    rows = fusionSummary.fusionSnrDb == fusionSnrDbValues(snrIndex);
    plot(fusionSummary.numFusionCarriers(rows), ...
        fusionSummary.mean_fusionCaptureRate(rows), ...
        lineStyle(snrIndex), LineWidth=1.5, MarkerSize=6);
end
hold off; grid on; ylim([0, 1.02]);
xlabel("Number of fused carriers"); ylabel("Capture rate");
legend(string(fusionSnrDbValues) + " dB", Location="best");
title("Unspecified fusion-count sensitivity");
title(layout, "Local MUSIC failure attribution");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "music_failure_attribution.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "music_failure_attribution.fig"));
close(figureHandle);

disp(controls);
disp(summary);
disp(fusionSummary);
end

function index = centeredCarrierIndex(centerCarrier, count)
halfCount = floor(count / 2);
index = (centerCarrier-halfCount:centerCarrier+halfCount).';
end

function columns = centeredColumns(totalCount, selectedCount)
centerColumn = (totalCount + 1) / 2;
halfCount = floor(selectedCount / 2);
columns = (centerColumn-halfCount:centerColumn+halfCount).';
end

function snapshots = noiselessFresnelSnapshots(cfg, thetaDeg, rangeM, ...
    carrierIndex)
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
snapshots = complex(zeros(cfg.numAntennas, numel(carrierIndex)));
for carrierOffset = 1:numel(carrierIndex)
    snapshots(:, carrierOffset) = sqrt(cfg.numAntennas) ...
        * jad.steeringVector(cfg, thetaDeg, rangeM, ...
        frequencyHz(carrierOffset));
end
end

function snapshots = noiselessExactSnapshots(cfg, thetaDeg, rangeM, ...
    carrierIndex)
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
x = cfg.elementIndex * cfg.elementSpacing;
distance = sqrt(rangeM^2 + x.^2 - 2 * rangeM * x * sind(thetaDeg));
snapshots = exp(-1i * distance * (2 * pi * frequencyHz.' / cfg.c));
end

function [boundaryPeak, peakToMedian] = initialSpectrumMetrics(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundaryPeak = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
peakToMedian = max(spectrum, [], "all") / median(spectrum, "all");
end
