function run_range_shrinkage_screening
%RUN_RANGE_SHRINKAGE_SCREENING Learn continuous MUSIC range shrinkage.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
round8Folder = fullfile(projectFolder, "results", "full_spectrum", "round8");
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round9");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
calibration = readtable(fullfile(round8Folder, ...
    "learned_gate_calibration_trials.csv"));
validation = readtable(fullfile(round8Folder, ...
    "learned_gate_validation_trials.csv"));
snrValues = (-10:5:20).';
featureNames = confidenceFeatureNames();

calibrationDelta = calibration.musicRangeErrorM ...
    - calibration.frontRangeErrorM;
validationDelta = validation.musicRangeErrorM ...
    - validation.frontRangeErrorM;
globalAlpha = leastSquaresAlpha(calibration.frontRangeErrorM, ...
    calibrationDelta);
snrAlpha = zeros(numel(snrValues), 1);
for snrIndex = 1:numel(snrValues)
    rows = calibration.snrDb == snrValues(snrIndex);
    snrAlpha(snrIndex) = leastSquaresAlpha( ...
        calibration.frontRangeErrorM(rows), calibrationDelta(rows));
end
snrAlphaTable = table(snrValues, snrAlpha, ...
    VariableNames=["snrDb", "alpha"]);

[model, outOfFoldAlpha, scaleScores, selectedMinimum, ...
    selectedConservative, featureImportance] = trainAlphaModel( ...
    calibration, calibrationDelta, featureNames, 2117);
validationPredictedAlpha = min(max(predict( ...
    model, validation(:, featureNames)), 0), 1);
minimumAlpha = selectedMinimum.alphaScale * validationPredictedAlpha;
conservativeAlpha = selectedConservative.alphaScale ...
    * validationPredictedAlpha;
globalAlphaVector = globalAlpha * ones(height(validation), 1);
snrAlphaVector = zeros(height(validation), 1);
for snrIndex = 1:numel(snrValues)
    rows = validation.snrDb == snrValues(snrIndex);
    snrAlphaVector(rows) = snrAlpha(snrIndex);
end
oracleAlpha = fsjad.oracleRangeShrinkage( ...
    validation.frontRangeErrorM, validationDelta);

[validationDetails, validationSummary] = summarizeMethods(validation, ...
    validationDelta, globalAlphaVector, snrAlphaVector, minimumAlpha, ...
    conservativeAlpha, oracleAlpha, snrValues);
paperComparison = compareWithPublished(validationSummary, snrValues);

calibration.oracleAlpha = fsjad.oracleRangeShrinkage( ...
    calibration.frontRangeErrorM, calibrationDelta);
calibration.outOfFoldPredictedAlpha = outOfFoldAlpha;
validation.predictedAlpha = validationPredictedAlpha;
validation.minimumAlpha = minimumAlpha;
validation.conservativeAlpha = conservativeAlpha;
validation.oracleAlpha = oracleAlpha;
writetable(snrAlphaTable, fullfile(outputFolder, ...
    "shrinkage_snr_alpha.csv"));
writetable(scaleScores, fullfile(outputFolder, ...
    "shrinkage_scale_scores.csv"));
writetable(selectedMinimum, fullfile(outputFolder, ...
    "shrinkage_selected_minimum.csv"));
writetable(selectedConservative, fullfile(outputFolder, ...
    "shrinkage_selected_conservative.csv"));
writetable(featureImportance, fullfile(outputFolder, ...
    "shrinkage_feature_importance.csv"));
writetable(calibration, fullfile(outputFolder, ...
    "shrinkage_calibration_predictions.csv"));
writetable(validation, fullfile(outputFolder, ...
    "shrinkage_validation_predictions.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "shrinkage_validation_details.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "shrinkage_validation_summary.csv"));
writetable(paperComparison, fullfile(outputFolder, ...
    "shrinkage_paper_comparison.csv"));
save(fullfile(outputFolder, "range_shrinkage_screening.mat"), ...
    "featureNames", "globalAlpha", "snrAlphaTable", "model", ...
    "scaleScores", "selectedMinimum", "selectedConservative", ...
    "featureImportance", "validationSummary", "paperComparison");
plotResults(validationSummary, paperComparison, fullfile(outputFolder, ...
    "range_shrinkage_screening.png"));

fprintf("Global alpha: %.8f\n", globalAlpha);
disp(snrAlphaTable);
disp(selectedMinimum);
disp(selectedConservative);
disp(validationSummary);
disp(paperComparison);
end

function alpha = leastSquaresAlpha(frontError, delta)
denominator = sum(delta.^2);
if denominator <= eps
    alpha = 0;
else
    alpha = min(max(-sum(frontError .* delta) / denominator, 0), 1);
end
end

function [model, outOfFoldAlpha, scores, selectedMinimum, ...
    selectedConservative, featureImportance] = trainAlphaModel( ...
    calibration, delta, featureNames, randomSeed)
predictors = calibration(:, featureNames);
oracleAlpha = fsjad.oracleRangeShrinkage( ...
    calibration.frontRangeErrorM, delta);
sampleWeight = max(delta.^2, eps);
numFolds = 5;
foldIndex = mod((0:height(calibration) - 1).', numFolds) + 1;
outOfFoldAlpha = zeros(height(calibration), 1);
treeTemplate = templateTree(MinLeafSize=8, MaxNumSplits=25, ...
    Surrogate="off");
previousRandomState = rng;
cleanupRandomState = onCleanup(@() rng(previousRandomState));
rng(randomSeed, "twister");
for fold = 1:numFolds
    trainRows = foldIndex ~= fold;
    testRows = foldIndex == fold;
    foldModel = fitrensemble(predictors(trainRows, :), ...
        oracleAlpha(trainRows), Method="Bag", NumLearningCycles=150, ...
        Learners=treeTemplate, Weights=sampleWeight(trainRows));
    outOfFoldAlpha(testRows) = min(max(predict( ...
        foldModel, predictors(testRows, :)), 0), 1);
end
model = fitrensemble(predictors, oracleAlpha, Method="Bag", ...
    NumLearningCycles=300, Learners=treeTemplate, Weights=sampleWeight);

alphaScales = (0:0.02:1).';
scores = scoreScales(calibration.frontRangeErrorM, delta, ...
    outOfFoldAlpha, alphaScales, foldIndex, numFolds);
ranking = sortrows(scores, ["rangeMseChange", "meanAlpha"], ...
    ["ascend", "ascend"]);
selectedMinimum = ranking(1, :);
oneStandardErrorLimit = selectedMinimum.rangeMseChange ...
    + selectedMinimum.standardErrorMseChange;
eligible = scores.rangeMseChange <= oneStandardErrorLimit;
conservativeRanking = sortrows(scores(eligible, :), ...
    ["alphaScale", "rangeMseChange"], ["ascend", "ascend"]);
selectedConservative = conservativeRanking(1, :);

importance = predictorImportance(model).';
featureImportance = table(featureNames.', importance, ...
    VariableNames=["feature", "importance"]);
featureImportance = sortrows(featureImportance, "importance", "descend");
end

function scores = scoreScales(frontError, delta, predictedAlpha, ...
    alphaScales, foldIndex, numFolds)
numScales = numel(alphaScales);
alphaScale = alphaScales;
rangeRmseM = zeros(numScales, 1);
rangeMseChange = zeros(numScales, 1);
standardErrorMseChange = zeros(numScales, 1);
meanAlpha = zeros(numScales, 1);
for scaleIndex = 1:numScales
    alpha = alphaScales(scaleIndex) * predictedAlpha;
    fusedError = frontError + alpha .* delta;
    squaredChange = fusedError.^2 - frontError.^2;
    foldMeanChange = zeros(numFolds, 1);
    for fold = 1:numFolds
        foldMeanChange(fold) = mean(squaredChange(foldIndex == fold));
    end
    rangeRmseM(scaleIndex) = sqrt(mean(fusedError.^2));
    rangeMseChange(scaleIndex) = mean(squaredChange);
    standardErrorMseChange(scaleIndex) = std(foldMeanChange) ...
        / sqrt(numFolds);
    meanAlpha(scaleIndex) = mean(alpha);
end
scores = table(alphaScale, rangeRmseM, rangeMseChange, ...
    standardErrorMseChange, meanAlpha);
end

function [details, summary] = summarizeMethods(trials, delta, ...
    globalAlpha, snrAlpha, minimumAlpha, conservativeAlpha, ...
    oracleAlpha, snrValues)
methodNames = ["Full-spectrum front"; "Fixed narrow MUSIC"; ...
    "Global shrinkage"; "SNR shrinkage"; "Learned minimum shrinkage"; ...
    "Learned conservative shrinkage"; "Oracle shrinkage"];
alphaMatrix = [zeros(size(delta)).'; ones(size(delta)).'; ...
    globalAlpha.'; snrAlpha.'; minimumAlpha.'; conservativeAlpha.'; ...
    oracleAlpha.'];
errorMatrix = trials.frontRangeErrorM.' + alphaMatrix .* delta.';
angleMatrix = [trials.frontAngleErrorDeg.'; ...
    repmat(trials.musicAngleErrorDeg.', numel(methodNames) - 1, 1)];
numTrials = height(trials);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(trials.snrDb, numel(methodNames));
details = table(method, snrDb, angleMatrix(:), errorMatrix(:), ...
    alphaMatrix(:), VariableNames=["method", "snrDb", ...
    "angleErrorDeg", "rangeErrorM", "alpha"]);

numRows = numel(methodNames) * numel(snrValues);
summaryMethod = strings(numRows, 1);
summarySnrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1);
row = 0;
for methodIndex = 1:numel(methodNames)
    for snrIndex = 1:numel(snrValues)
        row = row + 1;
        rows = details.method == methodNames(methodIndex) ...
            & details.snrDb == snrValues(snrIndex);
        summaryMethod(row) = methodNames(methodIndex);
        summarySnrDb(row) = snrValues(snrIndex);
        angleRmseDeg(row) = sqrt(mean(details.angleErrorDeg(rows).^2));
        rangeRmseM(row) = sqrt(mean(details.rangeErrorM(rows).^2));
        meanAlpha(row) = mean(details.alpha(rows));
    end
end
summary = table(summaryMethod, summarySnrDb, angleRmseDeg, ...
    rangeRmseM, meanAlpha, VariableNames=["method", "snrDb", ...
    "angleRmseDeg", "rangeRmseM", "meanAlpha"]);
end

function comparison = compareWithPublished(summary, snrValues)
rows = summary.method == "Learned conservative shrinkage";
snrDb = summary.snrDb(rows);
assert(isequal(snrDb, snrValues));
learnedAngleRmseDeg = summary.angleRmseDeg(rows);
learnedRangeRmseM = summary.rangeRmseM(rows);
publishedAngleRmseDeg = [0.10222305; 0.026220697; 0.0077105099; ...
    0.0026459847; 0.0012447656; 0.00084484464; 0.00075050297];
publishedRangeRmseM = [0.099998239; 0.039411058; 0.015372596; ...
    0.0059306791; 0.0022856537; 0.00087991824; 0.00033835853];
angleRatioToPublished = learnedAngleRmseDeg ./ publishedAngleRmseDeg;
rangeRatioToPublished = learnedRangeRmseM ./ publishedRangeRmseM;
comparison = table(snrDb, learnedAngleRmseDeg, ...
    publishedAngleRmseDeg, angleRatioToPublished, learnedRangeRmseM, ...
    publishedRangeRmseM, rangeRatioToPublished);
end

function plotResults(summary, comparison, outputFile)
figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
methodNames = unique(summary.method, "stable");
lineStyles = ["-o", "-s", "-^", "-v", "-d", "-x", "--+"];
axisHandle = nexttile;
axisHandle.YScale = "log";
hold(axisHandle, "on");
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.rangeRmseM(rows), ...
        lineStyles(methodIndex), LineWidth=1.2, MarkerSize=5);
end
semilogy(comparison.snrDb, comparison.publishedRangeRmseM, ":p", ...
    LineWidth=1.5, MarkerSize=6);
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Range RMSE (m)");
legend(axisHandle, [methodNames; "Published Proposed"], Location="best");

axisHandle = nexttile;
hold(axisHandle, "on");
for methodIndex = 3:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    plot(summary.snrDb(rows), summary.meanAlpha(rows), ...
        lineStyles(methodIndex), LineWidth=1.2, MarkerSize=5);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Mean shrinkage coefficient");
ylim(axisHandle, [0, 1]);
legend(axisHandle, methodNames(3:end), Location="best");
title(layout, "Continuous single-path range shrinkage");
exportgraphics(figureHandle, outputFile, Resolution=180);
close(figureHandle);
end

function names = confidenceFeatureNames
names = ["snrDb", "frontThetaDeg", "frontRangeM", "frontScore", ...
    "frontScoreGap", "frontConverged", "rangeDeltaM", ...
    "absRangeDeltaM", "angleDeltaDeg", "absAngleDeltaDeg", ...
    "initialBoundaryPeak", "initialLogPeakToMedian", ...
    "initialCompetitorGap", "initialRangeNeighborDrop", ...
    "initialAngleNeighborDrop", "initialRangeBoundaryDistance", ...
    "initialAngleBoundaryDistance", "refinedBoundaryPeak", ...
    "refinedLogPeakToMedian", "refinedCompetitorGap", ...
    "refinedRangeNeighborDrop", "refinedAngleNeighborDrop", ...
    "refinedRangeBoundaryDistance", "refinedAngleBoundaryDistance"];
end
