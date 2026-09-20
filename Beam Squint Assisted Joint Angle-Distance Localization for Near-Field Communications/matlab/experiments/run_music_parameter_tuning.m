function run_music_parameter_tuning
%RUN_MUSIC_PARAMETER_TUNING Tune unpublished MUSIC parameters on held-out data.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
sourceFile = fullfile(projectFolder, "results", "full_spectrum", ...
    "round4", "efim_failure_attribution_trials.csv");
sourceTrials = readtable(sourceFile);
tuningSnrDb = [-10, 0, 10];
numCalibrationPerSnr = 20;
numValidationPerSnr = 40;
[calibration, validation] = splitTrials(sourceTrials, tuningSnrDb, ...
    numCalibrationPerSnr, numValidationPerSnr);

centerCarrier = round(cfg.numSubcarriers / 2);
maxFusionCarriers = 33;
maxCarrierIndex = centeredCarrierIndex(centerCarrier, maxFusionCarriers);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 901);
calibrationSnapshots = buildSnapshots(cfg, calibration, ...
    maxCarrierIndex, stream);
validationSnapshots = buildSnapshots(cfg, validation, ...
    maxCarrierIndex, stream);

fusionCandidates = [1, 3, 5, 9, 17, 33];
subarrayCandidates = [64, 96, 128, 160, 192];
numStageA = numel(fusionCandidates) * numel(subarrayCandidates);
fusionCarriers = zeros(numStageA, 1);
subarraySize = zeros(numStageA, 1);
captureRate = zeros(numStageA, 1);
angleRmseDeg = zeros(numStageA, 1);
rangeRmseM = zeros(numStageA, 1);
boundaryRate = zeros(numStageA, 1);
meanRuntimeMs = zeros(numStageA, 1);
row = 0;
for subarrayIndex = 1:numel(subarrayCandidates)
    for fusionIndex = 1:numel(fusionCandidates)
        row = row + 1;
        candidateCfg = setSubarraySize(cfg, ...
            subarrayCandidates(subarrayIndex));
        metrics = evaluateConfiguration(candidateCfg, calibration, ...
            calibrationSnapshots, maxCarrierIndex, ...
            fusionCandidates(fusionIndex));
        fusionCarriers(row) = fusionCandidates(fusionIndex);
        subarraySize(row) = subarrayCandidates(subarrayIndex);
        captureRate(row) = metrics.captureRate;
        angleRmseDeg(row) = metrics.angleRmseDeg;
        rangeRmseM(row) = metrics.rangeRmseM;
        boundaryRate(row) = metrics.boundaryRate;
        meanRuntimeMs(row) = metrics.meanRuntimeMs;
    end
end
stageA = table(fusionCarriers, subarraySize, captureRate, ...
    angleRmseDeg, rangeRmseM, boundaryRate, meanRuntimeMs);
stageA = sortCandidateTable(stageA);
bestFusionCarriers = stageA.fusionCarriers(1);
bestSubarraySize = stageA.subarraySize(1);

angleHalfWidthCandidates = [0.25, 0.5, 1, 1.5];
rangeHalfWidthCandidates = [0.25, 0.5, 1, 1.5, 2];
numStageB = numel(angleHalfWidthCandidates) ...
    * numel(rangeHalfWidthCandidates);
angleHalfWidthDeg = zeros(numStageB, 1);
rangeHalfWidthM = zeros(numStageB, 1);
captureRate = zeros(numStageB, 1);
angleRmseDeg = zeros(numStageB, 1);
rangeRmseM = zeros(numStageB, 1);
boundaryRate = zeros(numStageB, 1);
meanRuntimeMs = zeros(numStageB, 1);
row = 0;
for angleIndex = 1:numel(angleHalfWidthCandidates)
    for rangeIndex = 1:numel(rangeHalfWidthCandidates)
        row = row + 1;
        candidateCfg = setSubarraySize(cfg, bestSubarraySize);
        candidateCfg.localHalfWidthDeg = ...
            angleHalfWidthCandidates(angleIndex);
        candidateCfg.localHalfWidthM = ...
            rangeHalfWidthCandidates(rangeIndex);
        metrics = evaluateConfiguration(candidateCfg, calibration, ...
            calibrationSnapshots, maxCarrierIndex, bestFusionCarriers);
        angleHalfWidthDeg(row) = angleHalfWidthCandidates(angleIndex);
        rangeHalfWidthM(row) = rangeHalfWidthCandidates(rangeIndex);
        captureRate(row) = metrics.captureRate;
        angleRmseDeg(row) = metrics.angleRmseDeg;
        rangeRmseM(row) = metrics.rangeRmseM;
        boundaryRate(row) = metrics.boundaryRate;
        meanRuntimeMs(row) = metrics.meanRuntimeMs;
    end
end
stageB = table(angleHalfWidthDeg, rangeHalfWidthM, captureRate, ...
    angleRmseDeg, rangeRmseM, boundaryRate, meanRuntimeMs);
stageB = sortCandidateTable(stageB);
bestAngleHalfWidthDeg = stageB.angleHalfWidthDeg(1);
bestRangeHalfWidthM = stageB.rangeHalfWidthM(1);

gridCandidates = [21, 15, 11; 31, 21, 15; 41, 31, 21; 61, 41, 31];
numStageC = size(gridCandidates, 1);
gridLevel1 = gridCandidates(:, 1);
gridLevel2 = gridCandidates(:, 2);
gridLevel3 = gridCandidates(:, 3);
captureRate = zeros(numStageC, 1);
angleRmseDeg = zeros(numStageC, 1);
rangeRmseM = zeros(numStageC, 1);
boundaryRate = zeros(numStageC, 1);
meanRuntimeMs = zeros(numStageC, 1);
for gridIndex = 1:numStageC
    candidateCfg = setSubarraySize(cfg, bestSubarraySize);
    candidateCfg.localHalfWidthDeg = bestAngleHalfWidthDeg;
    candidateCfg.localHalfWidthM = bestRangeHalfWidthM;
    candidateCfg.gridSizes = gridCandidates(gridIndex, :);
    metrics = evaluateConfiguration(candidateCfg, calibration, ...
        calibrationSnapshots, maxCarrierIndex, bestFusionCarriers);
    captureRate(gridIndex) = metrics.captureRate;
    angleRmseDeg(gridIndex) = metrics.angleRmseDeg;
    rangeRmseM(gridIndex) = metrics.rangeRmseM;
    boundaryRate(gridIndex) = metrics.boundaryRate;
    meanRuntimeMs(gridIndex) = metrics.meanRuntimeMs;
end
stageC = table(gridLevel1, gridLevel2, gridLevel3, captureRate, ...
    angleRmseDeg, rangeRmseM, boundaryRate, meanRuntimeMs);
stageC = sortCandidateTable(stageC);
bestGridSizes = [stageC.gridLevel1(1), stageC.gridLevel2(1), ...
    stageC.gridLevel3(1)];

defaultCfg = cfg;
tunedCfg = setSubarraySize(cfg, bestSubarraySize);
tunedCfg.localHalfWidthDeg = bestAngleHalfWidthDeg;
tunedCfg.localHalfWidthM = bestRangeHalfWidthM;
tunedCfg.gridSizes = bestGridSizes;
defaultDetails = evaluateValidation(defaultCfg, validation, ...
    validationSnapshots, maxCarrierIndex, cfg.numFusionCarriers, ...
    "Paper-unknown defaults");
tunedDetails = evaluateValidation(tunedCfg, validation, ...
    validationSnapshots, maxCarrierIndex, bestFusionCarriers, ...
    "Calibration-selected");
validationDetails = [defaultDetails; tunedDetails];
validationSummary = groupsummary(validationDetails, ...
    ["method", "snrDb"], "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "boundaryPeak", "runtimeMs"]);
validationSummary.angleRmseDeg = sqrt( ...
    validationSummary.mean_angleErrorSquared);
validationSummary.rangeRmseM = sqrt( ...
    validationSummary.mean_rangeErrorSquared);

selectedParameter = ["fusionCarriers"; "subarraySize"; ...
    "angleHalfWidthDeg"; "rangeHalfWidthM"; ...
    "gridLevel1"; "gridLevel2"; "gridLevel3"];
selectedValue = [bestFusionCarriers; bestSubarraySize; ...
    bestAngleHalfWidthDeg; bestRangeHalfWidthM; bestGridSizes(:)];
selected = table(selectedParameter, selectedValue);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round5");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(stageA, fullfile(outputFolder, ...
    "music_tuning_fusion_subarray.csv"));
writetable(stageB, fullfile(outputFolder, ...
    "music_tuning_window.csv"));
writetable(stageC, fullfile(outputFolder, ...
    "music_tuning_grid.csv"));
writetable(selected, fullfile(outputFolder, ...
    "music_tuning_selected.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "music_tuning_validation_trials.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "music_tuning_validation_summary.csv"));
save(fullfile(outputFolder, "music_parameter_tuning.mat"), ...
    "cfg", "tuningSnrDb", "numCalibrationPerSnr", ...
    "numValidationPerSnr", "calibration", "validation", ...
    "stageA", "stageB", "stageC", "selected", ...
    "validationDetails", "validationSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
hold on;
methods = ["Paper-unknown defaults", "Calibration-selected"];
lineStyle = ["-o", "-s"];
for methodIndex = 1:numel(methods)
    rows = validationSummary.method == methods(methodIndex);
    plot(validationSummary.snrDb(rows), ...
        validationSummary.mean_captured(rows), lineStyle(methodIndex), ...
        LineWidth=1.5, MarkerSize=6);
end
hold off; grid on; ylim([0, 1.02]);
xlabel("SNR (dB)"); ylabel("Held-out capture rate");
legend(methods, Location="southeast");
title("Independent validation");
nexttile;
scatter(stageA.meanRuntimeMs, stageA.captureRate, 50, ...
    stageA.fusionCarriers, "filled");
grid on; colorbar;
xlabel("Mean runtime (ms)"); ylabel("Calibration capture rate");
title("Fusion/subarray accuracy-cost frontier");
title(layout, "Tuning unpublished local MUSIC parameters");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "music_parameter_tuning.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "music_parameter_tuning.fig"));
close(figureHandle);

disp(selected);
disp(stageA(1:min(10, height(stageA)), :));
disp(stageB(1:min(10, height(stageB)), :));
disp(stageC);
disp(validationSummary);
end

function [calibration, validation] = splitTrials(source, snrValues, ...
    numCalibration, numValidation)
calibration = source([], :);
validation = source([], :);
for snrIndex = 1:numel(snrValues)
    rows = find(source.snrDb == snrValues(snrIndex));
    calibration = [calibration; source(rows(1:numCalibration), :)]; %#ok<AGROW>
    validation = [validation; ...
        source(rows(end-numValidation+1:end), :)]; %#ok<AGROW>
end
end

function snapshots = buildSnapshots(cfg, data, carrierIndex, stream)
numRows = height(data);
snapshots = complex(zeros(cfg.numAntennas, numel(carrierIndex), numRows));
for row = 1:numRows
    signal = noiselessSnapshots(cfg, data.truthThetaDeg(row), ...
        data.truthRangeM(row), carrierIndex);
    noiseStd = 10^(-data.snrDb(row) / 20);
    noise = noiseStd / sqrt(2) * (randn(stream, size(signal)) ...
        + 1i * randn(stream, size(signal)));
    snapshots(:, :, row) = signal + noise;
end
end

function metrics = evaluateConfiguration(cfg, data, snapshots, ...
    maxCarrierIndex, fusionCount)
selectedColumns = centeredColumns(numel(maxCarrierIndex), fusionCount);
carrierIndex = maxCarrierIndex(selectedColumns);
numRows = height(data);
angleError = zeros(numRows, 1);
rangeError = zeros(numRows, 1);
captured = false(numRows, 1);
boundaryPeak = false(numRows, 1);
timer = tic;
for row = 1:numRows
    result = jad.localMusicEstimate(cfg, snapshots(:, selectedColumns, row), ...
        carrierIndex, data.globalThetaDeg(row), data.globalRangeM(row));
    angleError(row) = result.thetaDeg - data.truthThetaDeg(row);
    rangeError(row) = result.rangeM - data.truthRangeM(row);
    captured(row) = abs(angleError(row)) <= 1 ...
        && abs(rangeError(row)) <= 1;
    boundaryPeak(row) = isBoundaryPeak(result.initialSpectrum);
end
metrics.captureRate = mean(captured);
metrics.angleRmseDeg = sqrt(mean(angleError.^2));
metrics.rangeRmseM = sqrt(mean(rangeError.^2));
metrics.boundaryRate = mean(boundaryPeak);
metrics.meanRuntimeMs = 1000 * toc(timer) / numRows;
end

function details = evaluateValidation(cfg, data, snapshots, ...
    maxCarrierIndex, fusionCount, methodName)
selectedColumns = centeredColumns(numel(maxCarrierIndex), fusionCount);
carrierIndex = maxCarrierIndex(selectedColumns);
numRows = height(data);
method = repmat(string(methodName), numRows, 1);
snrDb = data.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
boundaryPeak = false(numRows, 1);
runtimeMs = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    result = jad.localMusicEstimate(cfg, snapshots(:, selectedColumns, row), ...
        carrierIndex, data.globalThetaDeg(row), data.globalRangeM(row));
    runtimeMs(row) = 1000 * toc(timer);
    angleError = result.thetaDeg - data.truthThetaDeg(row);
    rangeError = result.rangeM - data.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    boundaryPeak(row) = isBoundaryPeak(result.initialSpectrum);
end
details = table(method, snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, boundaryPeak, runtimeMs);
end

function cfg = setSubarraySize(cfg, subarraySize)
cfg.subarraySize = subarraySize;
cfg.numSubarrays = cfg.numAntennas - subarraySize + 1;
end

function sorted = sortCandidateTable(candidate)
sorted = sortrows(candidate, ...
    ["captureRate", "rangeRmseM", "meanRuntimeMs"], ...
    ["descend", "ascend", "ascend"]);
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

function snapshots = noiselessSnapshots(cfg, thetaDeg, rangeM, carrierIndex)
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
snapshots = complex(zeros(cfg.numAntennas, numel(carrierIndex)));
for carrierOffset = 1:numel(carrierIndex)
    snapshots(:, carrierOffset) = sqrt(cfg.numAntennas) ...
        * jad.steeringVector(cfg, thetaDeg, rangeM, ...
        frequencyHz(carrierOffset));
end
end

function boundary = isBoundaryPeak(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundary = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
end
