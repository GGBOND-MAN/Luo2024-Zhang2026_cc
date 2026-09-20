function run_music_carrier_boundary_refinement
%RUN_MUSIC_CARRIER_BOUNDARY_REFINEMENT Expand and correct carrier tuning.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 1.5;
cfg.localHalfWidthM = 0.25;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
snrDbValues = [-10, 0, 10];
numCalibrationPerSnr = 10;
carrierCountCandidates = [5, 17, 33, 65, 129, 257, 513];
strategyNames = ["Peak-neighborhood"; "Band-center"];
maxCarrierCount = max(carrierCountCandidates);
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round6");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
datasetFile = fullfile(outputFolder, "carrier_refinement_dataset.mat");
if isfile(datasetFile)
    dataset = load(datasetFile);
else
    dataset = generateDataset(cfg, scan, snrDbValues, ...
        numCalibrationPerSnr, maxCarrierCount, frontOffsetsDeg);
    save(datasetFile, "-struct", "dataset", "-v7.3");
end

numConfigurations = numel(strategyNames) * numel(carrierCountCandidates);
strategy = strings(numConfigurations, 1);
fusionCarriers = zeros(numConfigurations, 1);
captureRate = nan(numConfigurations, 1);
angleRmseDeg = nan(numConfigurations, 1);
rangeRmseM = nan(numConfigurations, 1);
rangeImprovementRate = nan(numConfigurations, 1);
rangeMseChangeM2 = nan(numConfigurations, 1);
boundaryRate = nan(numConfigurations, 1);
meanRuntimeMs = nan(numConfigurations, 1);
trialDetails = cell(numConfigurations, 1);
configuration = 0;
for strategyIndex = 1:numel(strategyNames)
    for countIndex = 1:numel(carrierCountCandidates)
        configuration = configuration + 1;
        strategy(configuration) = strategyNames(strategyIndex);
        fusionCarriers(configuration) = carrierCountCandidates(countIndex);
    end
end

checkpointFile = fullfile(outputFolder, ...
    "carrier_refinement_checkpoint.mat");
completedConfigurations = 0;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    captureRate = checkpoint.captureRate;
    angleRmseDeg = checkpoint.angleRmseDeg;
    rangeRmseM = checkpoint.rangeRmseM;
    rangeImprovementRate = checkpoint.rangeImprovementRate;
    rangeMseChangeM2 = checkpoint.rangeMseChangeM2;
    boundaryRate = checkpoint.boundaryRate;
    meanRuntimeMs = checkpoint.meanRuntimeMs;
    trialDetails = checkpoint.trialDetails;
    completedConfigurations = checkpoint.completedConfigurations;
end

for configuration = completedConfigurations + 1:numConfigurations
    details = evaluateConfiguration(cfg, dataset, strategy(configuration), ...
        fusionCarriers(configuration));
    trialDetails{configuration} = details;
    captureRate(configuration) = mean(details.captured);
    angleRmseDeg(configuration) = sqrt(mean(details.angleErrorDeg.^2));
    rangeRmseM(configuration) = sqrt(mean(details.rangeErrorM.^2));
    rangeImprovementRate(configuration) = mean(details.rangeImproved);
    rangeMseChangeM2(configuration) = mean(details.rangeErrorM.^2 ...
        - details.frontRangeErrorM.^2);
    boundaryRate(configuration) = mean(details.boundaryPeak);
    meanRuntimeMs(configuration) = mean(details.runtimeMs);
    completedConfigurations = configuration;
    save(checkpointFile, "captureRate", "angleRmseDeg", ...
        "rangeRmseM", "rangeImprovementRate", "rangeMseChangeM2", ...
        "boundaryRate", "meanRuntimeMs", "trialDetails", ...
        "completedConfigurations");
    fprintf("Carrier refinement %d/%d: %s, %d carriers complete.\n", ...
        configuration, numConfigurations, strategy(configuration), ...
        fusionCarriers(configuration));
end

summary = table(strategy, fusionCarriers, captureRate, angleRmseDeg, ...
    rangeRmseM, rangeImprovementRate, rangeMseChangeM2, boundaryRate, ...
    meanRuntimeMs);
accuracyRanking = sortrows(summary, ...
    ["rangeRmseM", "angleRmseDeg", "captureRate"], ...
    ["ascend", "ascend", "descend"]);
bestStrategy = accuracyRanking.strategy(1);
bestFusionCarriers = accuracyRanking.fusionCarriers(1);
oracleDetails = evaluateOracleCenter(cfg, dataset, bestStrategy, ...
    bestFusionCarriers);
oracleSummary = groupsummary(oracleDetails, "snrDb", "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "boundaryPeak"]);
oracleSummary.angleRmseDeg = sqrt(oracleSummary.mean_angleErrorSquared);
oracleSummary.rangeRmseM = sqrt(oracleSummary.mean_rangeErrorSquared);

allDetails = vertcat(trialDetails{:});
snrSummary = groupsummary(allDetails, ...
    ["strategy", "fusionCarriers", "snrDb"], "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "rangeImproved", "boundaryPeak", "runtimeMs"]);
snrSummary.angleRmseDeg = sqrt(snrSummary.mean_angleErrorSquared);
snrSummary.rangeRmseM = sqrt(snrSummary.mean_rangeErrorSquared);
selectedParameter = ["strategy"; "fusionCarriers"];
selectedValue = [bestStrategy; string(bestFusionCarriers)];
selected = table(selectedParameter, selectedValue);

writetable(summary, fullfile(outputFolder, ...
    "carrier_refinement_summary.csv"));
writetable(accuracyRanking, fullfile(outputFolder, ...
    "carrier_refinement_ranking.csv"));
writetable(snrSummary, fullfile(outputFolder, ...
    "carrier_refinement_snr_summary.csv"));
writetable(selected, fullfile(outputFolder, ...
    "carrier_refinement_selected.csv"));
writetable(oracleDetails, fullfile(outputFolder, ...
    "carrier_refinement_oracle_trials.csv"));
writetable(oracleSummary, fullfile(outputFolder, ...
    "carrier_refinement_oracle_summary.csv"));
save(fullfile(outputFolder, "carrier_boundary_refinement.mat"), ...
    "cfg", "snrDbValues", "numCalibrationPerSnr", ...
    "carrierCountCandidates", "strategyNames", "summary", ...
    "accuracyRanking", "snrSummary", "selected", ...
    "oracleDetails", "oracleSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
hold on;
for strategyIndex = 1:numel(strategyNames)
    rows = summary.strategy == strategyNames(strategyIndex);
    semilogx(summary.fusionCarriers(rows), summary.rangeRmseM(rows), ...
        "-o", LineWidth=1.5, MarkerSize=6);
end
hold off;
grid on;
xlabel("Fused carriers");
ylabel("Calibration range RMSE (m)");
legend(strategyNames, Location="best");
title("Carrier count and selection rule");
nexttile;
hold on;
for strategyIndex = 1:numel(strategyNames)
    rows = summary.strategy == strategyNames(strategyIndex);
    semilogx(summary.fusionCarriers(rows), summary.boundaryRate(rows), ...
        "-o", LineWidth=1.5, MarkerSize=6);
end
hold off;
grid on;
xlabel("Fused carriers");
ylabel("First-grid boundary rate");
legend(strategyNames, Location="best");
title("Residual boundary sensitivity");
title(layout, "Corrected MUSIC carrier-set refinement");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "carrier_boundary_refinement.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "carrier_boundary_refinement.fig"));
close(figureHandle);

disp(accuracyRanking);
disp(snrSummary);
disp(selected);
disp(oracleSummary);
end

function dataset = generateDataset(cfg, scan, snrValues, numPerSnr, ...
    maxCarrierCount, frontOffsetsDeg)
numRows = numel(snrValues) * numPerSnr;
snrDb = repelem(snrValues(:), numPerSnr);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 1301);
truthThetaDeg = -57.3 + 114.6 * rand(stream, numRows, 1);
truthRangeM = 17.2 + 30.6 * rand(stream, numRows, 1);
peakCarrierIndex = zeros(numRows, 1);
frontThetaDeg = zeros(numRows, 1);
frontRangeM = zeros(numRows, 1);
unionCarrierIndex = cell(numRows, 1);
snapshots = cell(numRows, 1);
bandCenter = floor(cfg.numSubcarriers / 2);
centerMaxIndex = fixedCountWindow(bandCenter, maxCarrierCount, ...
    cfg.numSubcarriers);
for row = 1:numRows
    truthResponse = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(truthThetaDeg(row)), truthRangeM(row), scan);
    signalPower = mean(abs(truthResponse).^2);
    noiseVariance = signalPower / 10^(snrDb(row) / 10);
    beta = exp(1i * 2 * pi * rand(stream));
    noise = sqrt(noiseVariance / 2) * (randn(stream, ...
        cfg.numSubcarriers, 1) + 1i * randn(stream, ...
        cfg.numSubcarriers, 1));
    observation = beta * truthResponse + noise;
    [~, peakPosition] = max(abs(observation).^2);
    peakCarrierIndex(row) = peakPosition - 1;
    front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
        frontOffsetsDeg);
    frontThetaDeg(row) = front.thetaDeg;
    frontRangeM(row) = front.rangeM;
    peakMaxIndex = fixedCountWindow(peakCarrierIndex(row), ...
        maxCarrierCount, cfg.numSubcarriers);
    unionCarrierIndex{row} = union(centerMaxIndex, peakMaxIndex);
    snapshots{row} = jad.simulateSnapshots(cfg, truthThetaDeg(row), ...
        truthRangeM(row), snrDb(row), unionCarrierIndex{row}, stream);
    fprintf("Carrier refinement dataset %d/%d complete.\n", row, numRows);
end
dataset.snrDb = snrDb;
dataset.truthThetaDeg = truthThetaDeg;
dataset.truthRangeM = truthRangeM;
dataset.peakCarrierIndex = peakCarrierIndex;
dataset.frontThetaDeg = frontThetaDeg;
dataset.frontRangeM = frontRangeM;
dataset.unionCarrierIndex = unionCarrierIndex;
dataset.snapshots = snapshots;
end

function details = evaluateConfiguration(cfg, dataset, strategyName, count)
numRows = numel(dataset.snrDb);
strategy = repmat(strategyName, numRows, 1);
fusionCarriers = count * ones(numRows, 1);
snrDb = dataset.snrDb;
angleErrorDeg = zeros(numRows, 1);
rangeErrorM = zeros(numRows, 1);
frontRangeErrorM = dataset.frontRangeM - dataset.truthRangeM;
captured = false(numRows, 1);
rangeImproved = false(numRows, 1);
boundaryPeak = false(numRows, 1);
runtimeMs = zeros(numRows, 1);
for row = 1:numRows
    carrierIndex = selectedCarrierIndex(cfg, dataset, row, ...
        strategyName, count);
    [available, columns] = ismember(carrierIndex, ...
        dataset.unionCarrierIndex{row});
    assert(all(available), "Selected carrier is missing from dataset.");
    timer = tic;
    result = jad.localMusicEstimate(cfg, ...
        dataset.snapshots{row}(:, columns), carrierIndex, ...
        dataset.frontThetaDeg(row), dataset.frontRangeM(row));
    runtimeMs(row) = 1000 * toc(timer);
    angleErrorDeg(row) = result.thetaDeg - dataset.truthThetaDeg(row);
    rangeErrorM(row) = result.rangeM - dataset.truthRangeM(row);
    captured(row) = abs(angleErrorDeg(row)) <= 1 ...
        && abs(rangeErrorM(row)) <= 1;
    rangeImproved(row) = abs(rangeErrorM(row)) ...
        < abs(frontRangeErrorM(row));
    boundaryPeak(row) = isBoundaryPeak(result.initialSpectrum);
end
angleErrorSquared = angleErrorDeg.^2;
rangeErrorSquared = rangeErrorM.^2;
details = table(strategy, fusionCarriers, snrDb, angleErrorDeg, ...
    rangeErrorM, frontRangeErrorM, angleErrorSquared, ...
    rangeErrorSquared, captured, rangeImproved, boundaryPeak, runtimeMs);
end

function details = evaluateOracleCenter(cfg, dataset, strategyName, count)
numRows = numel(dataset.snrDb);
snrDb = dataset.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
boundaryPeak = false(numRows, 1);
for row = 1:numRows
    carrierIndex = selectedCarrierIndex(cfg, dataset, row, ...
        strategyName, count);
    [available, columns] = ismember(carrierIndex, ...
        dataset.unionCarrierIndex{row});
    assert(all(available), "Selected carrier is missing from dataset.");
    result = jad.localMusicEstimate(cfg, ...
        dataset.snapshots{row}(:, columns), carrierIndex, ...
        dataset.truthThetaDeg(row), dataset.truthRangeM(row));
    angleError = result.thetaDeg - dataset.truthThetaDeg(row);
    rangeError = result.rangeM - dataset.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    boundaryPeak(row) = isBoundaryPeak(result.initialSpectrum);
end
details = table(snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, boundaryPeak);
end

function carrierIndex = selectedCarrierIndex(cfg, dataset, row, ...
    strategyName, count)
if strategyName == "Peak-neighborhood"
    centerIndex = dataset.peakCarrierIndex(row);
else
    centerIndex = floor(cfg.numSubcarriers / 2);
end
carrierIndex = fixedCountWindow(centerIndex, count, cfg.numSubcarriers);
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function boundary = isBoundaryPeak(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundary = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
end
