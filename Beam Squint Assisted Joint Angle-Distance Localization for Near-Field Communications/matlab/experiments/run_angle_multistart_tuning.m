function run_angle_multistart_tuning
%RUN_ANGLE_MULTISTART_TUNING Tune trajectory-informed angular multistart.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
snrDbValues = [-10, 0, 10];
numCalibrationPerSnr = 10;
numValidationPerSnr = 20;
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 1101);
calibration = generateScalarData(cfg, scan, snrDbValues, ...
    numCalibrationPerSnr, stream);
validation = generateScalarData(cfg, scan, snrDbValues, ...
    numValidationPerSnr, stream);

spanCandidatesDeg = [0.05, 0.1, 0.2, 0.5];
startCandidates = [1, 3, 5];
allOffsetSets = cell(numel(spanCandidatesDeg), 1);
for spanIndex = 1:numel(spanCandidatesDeg)
    spanDeg = spanCandidatesDeg(spanIndex);
    allOffsetSets{spanIndex} = ...
        [-spanDeg; -spanDeg / 2; 0; spanDeg / 2; spanDeg];
end
uniqueOffsetsDeg = unique(vertcat(allOffsetSets{:}));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round5");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
checkpointFile = fullfile(outputFolder, ...
    "angle_multistart_calibration_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    calibrationSummary = checkpoint.calibrationSummary;
    selected = checkpoint.selected;
    bestOffsetsDeg = checkpoint.bestOffsetsDeg;
else
    calibrationRuns = evaluateOffsets(cfg, scan, calibration, ...
        uniqueOffsetsDeg);

numConfigurations = numel(spanCandidatesDeg) * numel(startCandidates);
spanDeg = zeros(numConfigurations, 1);
numStarts = zeros(numConfigurations, 1);
captureRate = zeros(numConfigurations, 1);
angleRmseDeg = zeros(numConfigurations, 1);
rangeRmseM = zeros(numConfigurations, 1);
meanProfileScore = zeros(numConfigurations, 1);
meanScoreGap = nan(numConfigurations, 1);
rescueRate = zeros(numConfigurations, 1);
regressionRate = zeros(numConfigurations, 1);
meanResponseEvaluations = zeros(numConfigurations, 1);
configurationRow = 0;
for spanIndex = 1:numel(spanCandidatesDeg)
    fiveOffsets = allOffsetSets{spanIndex};
    for startIndex = 1:numel(startCandidates)
        configurationRow = configurationRow + 1;
        selectedOffsets = selectOffsets(fiveOffsets, ...
            startCandidates(startIndex));
        selectedIndices = offsetIndices(uniqueOffsetsDeg, selectedOffsets);
        metrics = subsetMetrics(calibrationRuns, calibration, ...
            selectedIndices);
        spanDeg(configurationRow) = spanCandidatesDeg(spanIndex);
        numStarts(configurationRow) = startCandidates(startIndex);
        captureRate(configurationRow) = metrics.captureRate;
        angleRmseDeg(configurationRow) = metrics.angleRmseDeg;
        rangeRmseM(configurationRow) = metrics.rangeRmseM;
        meanProfileScore(configurationRow) = metrics.meanProfileScore;
        meanScoreGap(configurationRow) = metrics.meanScoreGap;
        rescueRate(configurationRow) = metrics.rescueRate;
        regressionRate(configurationRow) = metrics.regressionRate;
        meanResponseEvaluations(configurationRow) = ...
            metrics.meanResponseEvaluations;
    end
end
calibrationSummary = table(spanDeg, numStarts, captureRate, ...
    angleRmseDeg, rangeRmseM, meanProfileScore, meanScoreGap, ...
    rescueRate, regressionRate, meanResponseEvaluations);
calibrationSummary = sortrows(calibrationSummary, ...
    ["captureRate", "rangeRmseM", "meanResponseEvaluations"], ...
    ["descend", "ascend", "ascend"]);
bestSpanDeg = calibrationSummary.spanDeg(1);
bestNumStarts = calibrationSummary.numStarts(1);
bestFiveOffsets = allOffsetSets{spanCandidatesDeg == bestSpanDeg};
bestOffsetsDeg = selectOffsets(bestFiveOffsets, bestNumStarts);
selectedParameter = ["spanDeg"; "numStarts"; ...
    compose("offset%dDeg", (1:numel(bestOffsetsDeg)).')];
selectedValue = [bestSpanDeg; bestNumStarts; bestOffsetsDeg];
selected = table(selectedParameter, selectedValue);
writetable(calibrationSummary, fullfile(outputFolder, ...
    "angle_multistart_calibration.csv"));
writetable(selected, fullfile(outputFolder, ...
    "angle_multistart_selected.csv"));
save(checkpointFile, "calibrationSummary", "selected", ...
    "bestSpanDeg", "bestNumStarts", "bestOffsetsDeg");
end

validationMultistart = evaluateSelectedMultistart(cfg, scan, validation, ...
    bestOffsetsDeg, "Calibration-selected angular multistart");
validationPeak = evaluatePeakInitialization(cfg, scan, validation, ...
    "Original peak-angle initialization");
validationOracle = evaluateOracleInitialization(cfg, scan, validation, ...
    "Truth initialization upper bound");
validationDetails = [validationPeak; validationMultistart; validationOracle];
validationSummary = groupsummary(validationDetails, ...
    ["method", "snrDb"], "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "profileScore", "scoreGap", "runtimeMs", "responseEvaluations"]);
validationSummary.angleRmseDeg = sqrt( ...
    validationSummary.mean_angleErrorSquared);
validationSummary.rangeRmseM = sqrt( ...
    validationSummary.mean_rangeErrorSquared);
validationComparison = pairedComparison(validationDetails, snrDbValues);
writetable(validationDetails, fullfile(outputFolder, ...
    "angle_multistart_validation_trials.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "angle_multistart_validation_summary.csv"));
writetable(validationComparison, fullfile(outputFolder, ...
    "angle_multistart_paired_comparison.csv"));
save(fullfile(outputFolder, "angle_multistart_tuning.mat"), ...
    "cfg", "snrDbValues", "numCalibrationPerSnr", ...
    "numValidationPerSnr", "spanCandidatesDeg", "startCandidates", ...
    "uniqueOffsetsDeg", "calibrationSummary", "selected", ...
    "validationDetails", "validationSummary", "validationComparison");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
hold on;
methods = ["Original peak-angle initialization", ...
    "Calibration-selected angular multistart", ...
    "Truth initialization upper bound"];
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methods)
    rows = validationSummary.method == methods(methodIndex);
    plot(validationSummary.snrDb(rows), ...
        validationSummary.mean_captured(rows), lineStyle(methodIndex), ...
        LineWidth=1.5, MarkerSize=6);
end
hold off;
grid on;
ylim([0, 1.02]);
xlabel("SNR (dB)");
ylabel("Held-out capture rate");
legend(methods, Location="southeast");
title("Independent validation");
nexttile;
scatter(calibrationSummary.meanResponseEvaluations, ...
    calibrationSummary.captureRate, 60, calibrationSummary.spanDeg, ...
    "filled");
grid on;
colorbar;
xlabel("Mean response evaluations");
ylabel("Calibration capture rate");
title("Angular span and multistart cost");
title(layout, "Trajectory-informed angular multistart tuning");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "angle_multistart_tuning.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "angle_multistart_tuning.fig"));
close(figureHandle);

disp(calibrationSummary);
disp(selected);
disp(validationSummary);
disp(validationComparison);
end

function data = generateScalarData(cfg, scan, snrValues, numPerSnr, stream)
numRows = numel(snrValues) * numPerSnr;
snrDb = repelem(snrValues(:), numPerSnr);
truthThetaDeg = -57.3 + 114.6 * rand(stream, numRows, 1);
truthRangeM = 17.2 + 30.6 * rand(stream, numRows, 1);
observation = complex(zeros(cfg.numSubcarriers, numRows));
for row = 1:numRows
    truthResponse = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(truthThetaDeg(row)), truthRangeM(row), scan);
    signalPower = mean(abs(truthResponse).^2);
    noiseVariance = signalPower / 10^(snrDb(row) / 10);
    beta = exp(1i * 2 * pi * rand(stream));
    noise = sqrt(noiseVariance / 2) * ( ...
        randn(stream, cfg.numSubcarriers, 1) ...
        + 1i * randn(stream, cfg.numSubcarriers, 1));
    observation(:, row) = beta * truthResponse + noise;
end
data = table(snrDb, truthThetaDeg, truthRangeM);
data.Properties.UserData.observation = observation;
end

function result = evaluateOffsets(cfg, scan, data, offsetsDeg)
numOffsets = numel(offsetsDeg);
numRows = height(data);
result.thetaDeg = zeros(numOffsets, numRows);
result.rangeM = zeros(numOffsets, numRows);
result.score = zeros(numOffsets, numRows);
result.responseEvaluations = zeros(numOffsets, numRows);
result.runtimeMs = zeros(numRows, 1);
result.offsetsDeg = offsetsDeg;
for row = 1:numRows
    timer = tic;
    estimate = fsjad.angleMultistartProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), scan, offsetsDeg);
    result.runtimeMs(row) = 1000 * toc(timer);
    result.thetaDeg(:, row) = estimate.refinedThetaDeg;
    result.rangeM(:, row) = estimate.refinedRangeM;
    result.score(:, row) = estimate.refinedScore;
    result.responseEvaluations(:, row) = ...
        estimate.responseEvaluationsPerStart;
    fprintf("Calibration angular starts %d/%d complete.\n", row, numRows);
end
end

function metrics = subsetMetrics(result, data, selectedIndices)
selectedScore = result.score(selectedIndices, :);
[bestScore, bestStart] = max(selectedScore, [], 1);
selectedTheta = result.thetaDeg(selectedIndices, :);
selectedRange = result.rangeM(selectedIndices, :);
columnIndex = 1:height(data);
linearIndex = sub2ind(size(selectedScore), bestStart, columnIndex);
thetaDeg = selectedTheta(linearIndex).';
rangeM = selectedRange(linearIndex).';
angleError = thetaDeg - data.truthThetaDeg;
rangeError = rangeM - data.truthRangeM;
captured = abs(angleError) <= 1 & abs(rangeError) <= 1;
allCenterIndex = offsetIndices(result.offsetsDeg, 0);
centerAngleError = result.thetaDeg(allCenterIndex, :).' ...
    - data.truthThetaDeg;
centerRangeError = result.rangeM(allCenterIndex, :).' ...
    - data.truthRangeM;
centerCaptured = abs(centerAngleError) <= 1 & abs(centerRangeError) <= 1;
metrics.captureRate = mean(captured);
metrics.angleRmseDeg = sqrt(mean(angleError.^2));
metrics.rangeRmseM = sqrt(mean(rangeError.^2));
metrics.meanProfileScore = mean(bestScore);
if numel(selectedIndices) > 1
    sortedScore = sort(selectedScore, 1, "descend");
    metrics.meanScoreGap = mean(sortedScore(1, :) - sortedScore(2, :));
else
    metrics.meanScoreGap = NaN;
end
metrics.rescueRate = mean(captured & ~centerCaptured);
metrics.regressionRate = mean(~captured & centerCaptured);
metrics.meanResponseEvaluations = mean(sum( ...
    result.responseEvaluations(selectedIndices, :), 1));
end

function selectedOffsets = selectOffsets(fiveOffsets, numStarts)
switch numStarts
    case 1
        selectedOffsets = fiveOffsets(3);
    case 3
        selectedOffsets = fiveOffsets([1, 3, 5]);
    case 5
        selectedOffsets = fiveOffsets;
    otherwise
        error("fsjad:UnsupportedStartCount", ...
            "Supported start counts are 1, 3, and 5.");
end
end

function indices = offsetIndices(allOffsets, selectedOffsets)
indices = zeros(numel(selectedOffsets), 1);
for index = 1:numel(selectedOffsets)
    [distance, indices(index)] = min(abs(allOffsets - selectedOffsets(index)));
    assert(distance < 1e-12, "Requested angular offset is unavailable.");
end
end

function details = evaluateSelectedMultistart(cfg, scan, data, offsetsDeg, ...
    methodName)
numRows = height(data);
method = repmat(string(methodName), numRows, 1);
snrDb = data.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
profileScore = zeros(numRows, 1);
scoreGap = nan(numRows, 1);
runtimeMs = zeros(numRows, 1);
responseEvaluations = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    estimate = fsjad.angleMultistartProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), scan, offsetsDeg);
    runtimeMs(row) = 1000 * toc(timer);
    angleError = estimate.thetaDeg - data.truthThetaDeg(row);
    rangeError = estimate.rangeM - data.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    profileScore(row) = estimate.score;
    scoreGap(row) = estimate.scoreGap;
    responseEvaluations(row) = estimate.totalResponseEvaluations;
    fprintf("Validation angular multistart %d/%d complete.\n", row, numRows);
end
details = table(method, snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, profileScore, scoreGap, runtimeMs, responseEvaluations);
end

function details = evaluatePeakInitialization(cfg, scan, data, methodName)
numRows = height(data);
method = repmat(string(methodName), numRows, 1);
snrDb = data.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
profileScore = zeros(numRows, 1);
scoreGap = nan(numRows, 1);
runtimeMs = zeros(numRows, 1);
responseEvaluations = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    estimate = fsjad.peakInitializedProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), scan);
    runtimeMs(row) = 1000 * toc(timer);
    angleError = estimate.thetaDeg - data.truthThetaDeg(row);
    rangeError = estimate.rangeM - data.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    profileScore(row) = estimate.score;
    responseEvaluations(row) = estimate.totalResponseEvaluations;
end
details = table(method, snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, profileScore, scoreGap, runtimeMs, responseEvaluations);
end

function details = evaluateOracleInitialization(cfg, scan, data, methodName)
numRows = height(data);
method = repmat(string(methodName), numRows, 1);
snrDb = data.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
profileScore = zeros(numRows, 1);
scoreGap = nan(numRows, 1);
runtimeMs = zeros(numRows, 1);
responseEvaluations = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    estimate = fsjad.refineProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), ...
        data.truthThetaDeg(row), data.truthRangeM(row), scan, 20);
    runtimeMs(row) = 1000 * toc(timer);
    angleError = estimate.thetaDeg - data.truthThetaDeg(row);
    rangeError = estimate.rangeM - data.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    profileScore(row) = estimate.score;
    responseEvaluations(row) = estimate.responseEvaluations;
end
details = table(method, snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, profileScore, scoreGap, runtimeMs, responseEvaluations);
end

function comparison = pairedComparison(details, snrValues)
peakName = "Original peak-angle initialization";
multiName = "Calibration-selected angular multistart";
snrDb = snrValues(:);
rescueRate = zeros(numel(snrDb), 1);
regressionRate = zeros(numel(snrDb), 1);
meanScoreGain = zeros(numel(snrDb), 1);
for snrIndex = 1:numel(snrDb)
    peakRows = details.method == peakName & details.snrDb == snrDb(snrIndex);
    multiRows = details.method == multiName & details.snrDb == snrDb(snrIndex);
    peakCaptured = details.captured(peakRows);
    multiCaptured = details.captured(multiRows);
    rescueRate(snrIndex) = mean(multiCaptured & ~peakCaptured);
    regressionRate(snrIndex) = mean(~multiCaptured & peakCaptured);
    meanScoreGain(snrIndex) = mean(details.profileScore(multiRows) ...
        - details.profileScore(peakRows));
end
comparison = table(snrDb, rescueRate, regressionRate, meanScoreGain);
end
