function run_music_boundary_independent_validation
%RUN_MUSIC_BOUNDARY_INDEPENDENT_VALIDATION Validate corrected frozen tuning.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

baseCfg = jad.defaultConfig();
baseCfg.subarraySize = 96;
baseCfg.numSubarrays = baseCfg.numAntennas - baseCfg.subarraySize + 1;
baseCfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(baseCfg);
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
snrDbValues = [-10, 0, 10];
numValidationPerSnr = 10;
maxFusionCarriers = 513;
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round6");

datasetFile = fullfile(outputFolder, ...
    "boundary_independent_validation_dataset.mat");
if isfile(datasetFile)
    dataset = load(datasetFile);
else
    dataset = generateDataset(baseCfg, scan, snrDbValues, ...
        numValidationPerSnr, maxFusionCarriers, frontOffsetsDeg);
    save(datasetFile, "-struct", "dataset", "-v7.3");
end

methodNames = ["Full-spectrum front only"; ...
    "Round-5 center 33, 1.5 deg / 0.25 m"; ...
    "Fine center 513, 0.02 deg / 0.02 m"; ...
    "Fine peak 513, 0.02 deg / 0.02 m"];
numMethods = numel(methodNames);
trialDetails = cell(numMethods, 1);
trialDetails{1} = frontDetails(dataset, methodNames(1));
completedMethods = 1;
checkpointFile = fullfile(outputFolder, ...
    "boundary_independent_validation_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    trialDetails = checkpoint.trialDetails;
    completedMethods = checkpoint.completedMethods;
end

for methodIndex = completedMethods + 1:numMethods
    candidateCfg = baseCfg;
    if methodIndex == 2
        candidateCfg.localHalfWidthDeg = 1.5;
        candidateCfg.localHalfWidthM = 0.25;
        fusionCarriers = 33;
        carrierStrategy = "Band-center";
    elseif methodIndex == 3
        candidateCfg.localHalfWidthDeg = 0.02;
        candidateCfg.localHalfWidthM = 0.02;
        fusionCarriers = 513;
        carrierStrategy = "Band-center";
    else
        candidateCfg.localHalfWidthDeg = 0.02;
        candidateCfg.localHalfWidthM = 0.02;
        fusionCarriers = 513;
        carrierStrategy = "Peak-neighborhood";
    end
    trialDetails{methodIndex} = evaluateMusic(candidateCfg, dataset, ...
        methodNames(methodIndex), carrierStrategy, fusionCarriers);
    completedMethods = methodIndex;
    save(checkpointFile, "trialDetails", "completedMethods");
    fprintf("Independent validation method %d/%d complete.\n", ...
        methodIndex, numMethods);
end

details = vertcat(trialDetails{:});
summary = groupsummary(details, ["method", "snrDb"], "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "rangeImproved", "boundaryPeak"]);
summary.angleRmseDeg = sqrt(summary.mean_angleErrorSquared);
summary.rangeRmseM = sqrt(summary.mean_rangeErrorSquared);
pairedSummary = pairedAgainstFront(details, methodNames, snrDbValues);

writetable(details, fullfile(outputFolder, ...
    "boundary_independent_validation_trials.csv"));
writetable(summary, fullfile(outputFolder, ...
    "boundary_independent_validation_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, ...
    "boundary_independent_validation_paired.csv"));
save(fullfile(outputFolder, "boundary_independent_validation.mat"), ...
    "baseCfg", "snrDbValues", "numValidationPerSnr", ...
    "methodNames", "details", "summary", "pairedSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotMetric(summary, methodNames, "angleRmseDeg", "Angle RMSE (deg)");
plotMetric(summary, methodNames, "rangeRmseM", "Range RMSE (m)");
title(layout, "Independent validation of corrected MUSIC tuning");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "boundary_independent_validation.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "boundary_independent_validation.fig"));
close(figureHandle);

disp(summary);
disp(pairedSummary);
end

function dataset = generateDataset(cfg, scan, snrValues, numPerSnr, ...
    maxFusionCarriers, frontOffsetsDeg)
numRows = numel(snrValues) * numPerSnr;
snrDb = repelem(snrValues(:), numPerSnr);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 1501);
truthThetaDeg = -57.3 + 114.6 * rand(stream, numRows, 1);
truthRangeM = 17.2 + 30.6 * rand(stream, numRows, 1);
peakCarrierIndex = zeros(numRows, 1);
frontThetaDeg = zeros(numRows, 1);
frontRangeM = zeros(numRows, 1);
unionCarrierIndex = cell(numRows, 1);
snapshots = cell(numRows, 1);
bandCenter = floor(cfg.numSubcarriers / 2);
centerIndex = fixedCountWindow(bandCenter, maxFusionCarriers, ...
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
    peakIndex = fixedCountWindow(peakCarrierIndex(row), ...
        maxFusionCarriers, cfg.numSubcarriers);
    unionCarrierIndex{row} = union(centerIndex, peakIndex);
    snapshots{row} = jad.simulateSnapshots(cfg, truthThetaDeg(row), ...
        truthRangeM(row), snrDb(row), unionCarrierIndex{row}, stream);
    fprintf("Independent validation dataset %d/%d complete.\n", row, numRows);
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

function details = frontDetails(dataset, methodName)
numRows = numel(dataset.snrDb);
method = repmat(methodName, numRows, 1);
snrDb = dataset.snrDb;
angleErrorDeg = dataset.frontThetaDeg - dataset.truthThetaDeg;
rangeErrorM = dataset.frontRangeM - dataset.truthRangeM;
angleErrorSquared = angleErrorDeg.^2;
rangeErrorSquared = rangeErrorM.^2;
captured = abs(angleErrorDeg) <= 1 & abs(rangeErrorM) <= 1;
rangeImproved = false(numRows, 1);
boundaryPeak = false(numRows, 1);
details = table(method, snrDb, angleErrorDeg, rangeErrorM, ...
    angleErrorSquared, rangeErrorSquared, captured, rangeImproved, ...
    boundaryPeak);
end

function details = evaluateMusic(cfg, dataset, methodName, strategy, count)
numRows = numel(dataset.snrDb);
method = repmat(methodName, numRows, 1);
snrDb = dataset.snrDb;
angleErrorDeg = zeros(numRows, 1);
rangeErrorM = zeros(numRows, 1);
frontRangeErrorM = dataset.frontRangeM - dataset.truthRangeM;
captured = false(numRows, 1);
rangeImproved = false(numRows, 1);
boundaryPeak = false(numRows, 1);
for row = 1:numRows
    if strategy == "Peak-neighborhood"
        centerIndex = dataset.peakCarrierIndex(row);
    else
        centerIndex = floor(cfg.numSubcarriers / 2);
    end
    carrierIndex = fixedCountWindow(centerIndex, count, ...
        cfg.numSubcarriers);
    [available, columns] = ismember(carrierIndex, ...
        dataset.unionCarrierIndex{row});
    assert(all(available), "Selected carrier is missing from dataset.");
    result = jad.localMusicEstimate(cfg, ...
        dataset.snapshots{row}(:, columns), carrierIndex, ...
        dataset.frontThetaDeg(row), dataset.frontRangeM(row));
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
details = table(method, snrDb, angleErrorDeg, rangeErrorM, ...
    angleErrorSquared, rangeErrorSquared, captured, rangeImproved, ...
    boundaryPeak);
end

function paired = pairedAgainstFront(details, methodNames, snrValues)
numRows = (numel(methodNames) - 1) * numel(snrValues);
method = strings(numRows, 1);
snrDb = zeros(numRows, 1);
rangeImprovementRate = zeros(numRows, 1);
meanRangeMseChangeM2 = zeros(numRows, 1);
row = 0;
for methodIndex = 2:numel(methodNames)
    for snrIndex = 1:numel(snrValues)
        row = row + 1;
        frontRows = details.method == methodNames(1) ...
            & details.snrDb == snrValues(snrIndex);
        methodRows = details.method == methodNames(methodIndex) ...
            & details.snrDb == snrValues(snrIndex);
        frontRangeSquared = details.rangeErrorSquared(frontRows);
        methodRangeSquared = details.rangeErrorSquared(methodRows);
        method(row) = methodNames(methodIndex);
        snrDb(row) = snrValues(snrIndex);
        rangeImprovementRate(row) = mean( ...
            methodRangeSquared < frontRangeSquared);
        meanRangeMseChangeM2(row) = mean( ...
            methodRangeSquared - frontRangeSquared);
    end
end
paired = table(method, snrDb, rangeImprovementRate, ...
    meanRangeMseChangeM2);
end

function plotMetric(summary, methodNames, variableName, yLabel)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^", "-d"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.(variableName)(rows), ...
        lineStyle(methodIndex), LineWidth=1.5, MarkerSize=6);
end
hold off;
grid on;
xlabel("SNR (dB)");
ylabel(yLabel);
legend(methodNames, Location="best");
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
