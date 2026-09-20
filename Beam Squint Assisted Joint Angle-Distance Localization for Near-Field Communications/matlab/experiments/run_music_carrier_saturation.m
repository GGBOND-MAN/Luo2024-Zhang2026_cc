function run_music_carrier_saturation
%RUN_MUSIC_CARRIER_SATURATION Test 513, 1025, and full-band fusion.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 1.5;
cfg.localHalfWidthM = 0.25;
cfg.gridSizes = [61, 41, 31];
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round6");
sourceFile = fullfile(outputFolder, "carrier_refinement_dataset.mat");
source = load(sourceFile, "snrDb", "truthThetaDeg", "truthRangeM", ...
    "peakCarrierIndex", "frontThetaDeg", "frontRangeM");

snapshotFile = fullfile(outputFolder, ...
    "carrier_saturation_fullband_snapshots.mat");
if isfile(snapshotFile)
    snapshotData = load(snapshotFile);
    fullSnapshots = snapshotData.fullSnapshots;
else
    fullSnapshots = generateFullBandSnapshots(cfg, source);
    save(snapshotFile, "fullSnapshots", "-v7.3");
end

strategy = ["Band-center"; "Peak-neighborhood"; ...
    "Band-center"; "Peak-neighborhood"; "Full-band"];
fusionCarriers = [513; 513; 1025; 1025; cfg.numSubcarriers];
numConfigurations = numel(strategy);
captureRate = nan(numConfigurations, 1);
angleRmseDeg = nan(numConfigurations, 1);
rangeRmseM = nan(numConfigurations, 1);
rangeImprovementRate = nan(numConfigurations, 1);
rangeMseChangeM2 = nan(numConfigurations, 1);
boundaryRate = nan(numConfigurations, 1);
meanRuntimeMs = nan(numConfigurations, 1);
trialDetails = cell(numConfigurations, 1);

checkpointFile = fullfile(outputFolder, ...
    "carrier_saturation_checkpoint.mat");
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
    details = evaluateConfiguration(cfg, source, fullSnapshots, ...
        strategy(configuration), fusionCarriers(configuration));
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
    fprintf("Carrier saturation %d/%d: %s, %d carriers complete.\n", ...
        configuration, numConfigurations, strategy(configuration), ...
        fusionCarriers(configuration));
end

summary = table(strategy, fusionCarriers, captureRate, angleRmseDeg, ...
    rangeRmseM, rangeImprovementRate, rangeMseChangeM2, boundaryRate, ...
    meanRuntimeMs);
ranking = sortrows(summary, ...
    ["rangeRmseM", "angleRmseDeg", "captureRate"], ...
    ["ascend", "ascend", "descend"]);
allDetails = vertcat(trialDetails{:});
snrSummary = groupsummary(allDetails, ...
    ["strategy", "fusionCarriers", "snrDb"], "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "rangeImproved", "boundaryPeak", "runtimeMs"]);
snrSummary.angleRmseDeg = sqrt(snrSummary.mean_angleErrorSquared);
snrSummary.rangeRmseM = sqrt(snrSummary.mean_rangeErrorSquared);

writetable(summary, fullfile(outputFolder, ...
    "carrier_saturation_summary.csv"));
writetable(ranking, fullfile(outputFolder, ...
    "carrier_saturation_ranking.csv"));
writetable(snrSummary, fullfile(outputFolder, ...
    "carrier_saturation_snr_summary.csv"));
save(fullfile(outputFolder, "carrier_saturation.mat"), ...
    "cfg", "strategy", "fusionCarriers", "summary", "ranking", ...
    "snrSummary");

figureHandle = figure(Color="w", Position=[100, 100, 720, 440]);
scatter(summary.fusionCarriers, summary.rangeRmseM, 70, ...
    summary.boundaryRate, "filled");
set(gca, XScale="log");
grid on;
colorbar;
xlabel("Fused carriers");
ylabel("Calibration range RMSE (m)");
title("MUSIC carrier fusion saturation");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "carrier_saturation.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "carrier_saturation.fig"));
close(figureHandle);

disp(ranking);
disp(snrSummary);
end

function fullSnapshots = generateFullBandSnapshots(cfg, source)
numRows = numel(source.snrDb);
fullSnapshots = cell(numRows, 1);
carrierIndex = (0:cfg.numSubcarriers - 1).';
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 1401);
for row = 1:numRows
    fullSnapshots{row} = jad.simulateSnapshots(cfg, ...
        source.truthThetaDeg(row), source.truthRangeM(row), ...
        source.snrDb(row), carrierIndex, stream);
    fprintf("Full-band snapshot %d/%d complete.\n", row, numRows);
end
end

function details = evaluateConfiguration(cfg, source, fullSnapshots, ...
    strategyName, count)
numRows = numel(source.snrDb);
strategy = repmat(strategyName, numRows, 1);
fusionCarriers = count * ones(numRows, 1);
snrDb = source.snrDb;
angleErrorDeg = zeros(numRows, 1);
rangeErrorM = zeros(numRows, 1);
frontRangeErrorM = source.frontRangeM - source.truthRangeM;
captured = false(numRows, 1);
rangeImproved = false(numRows, 1);
boundaryPeak = false(numRows, 1);
runtimeMs = zeros(numRows, 1);
for row = 1:numRows
    carrierIndex = selectedCarrierIndex(cfg, source, row, ...
        strategyName, count);
    columns = carrierIndex + 1;
    timer = tic;
    result = jad.localMusicEstimate(cfg, ...
        fullSnapshots{row}(:, columns), carrierIndex, ...
        source.frontThetaDeg(row), source.frontRangeM(row));
    runtimeMs(row) = 1000 * toc(timer);
    angleErrorDeg(row) = result.thetaDeg - source.truthThetaDeg(row);
    rangeErrorM(row) = result.rangeM - source.truthRangeM(row);
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

function carrierIndex = selectedCarrierIndex(cfg, source, row, ...
    strategyName, count)
if strategyName == "Peak-neighborhood"
    centerIndex = source.peakCarrierIndex(row);
elseif strategyName == "Band-center"
    centerIndex = floor(cfg.numSubcarriers / 2);
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
