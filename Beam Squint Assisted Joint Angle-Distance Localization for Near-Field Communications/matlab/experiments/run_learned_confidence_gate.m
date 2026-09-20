function run_learned_confidence_gate
%RUN_LEARNED_CONFIDENCE_GATE Learn and validate a truth-free range gate.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
snrValues = (-10:5:20).';
numCalibrationPerSnr = 30;
numValidationPerSnr = 60;

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round8");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
calibration = runFeatureTrials(cfg, scan, snrValues, ...
    numCalibrationPerSnr, true, fusionCarriers, frontOffsetsDeg, ...
    cfg.randomSeed + 1801, fullfile(outputFolder, ...
    "learned_gate_calibration_checkpoint.mat"));

featureNames = confidenceFeatureNames();
[model, outOfFoldPrediction, thresholdScores, selectedMinimum, ...
    selectedConservative, featureImportance] = trainGate( ...
    calibration, featureNames, cfg.randomSeed + 1901);

validation = runFeatureTrials(cfg, scan, snrValues, ...
    numValidationPerSnr, false, fusionCarriers, frontOffsetsDeg, ...
    cfg.randomSeed + 2001, fullfile(outputFolder, ...
    "learned_gate_validation_checkpoint.mat"));
validationPrediction = predict(model, validation(:, featureNames));
minimumUse = validationPrediction > selectedMinimum.predictionThreshold;
conservativeUse = validationPrediction ...
    > selectedConservative.predictionThreshold;
oracleUse = validation.musicRangeErrorM.^2 ...
    < validation.frontRangeErrorM.^2;
[validationDetails, validationSummary] = summarizeValidation(validation, ...
    minimumUse, conservativeUse, oracleUse, snrValues);
paperComparison = compareWithPublished(validationSummary, snrValues);

calibration.predictedRangeMseGain = outOfFoldPrediction;
validation.predictedRangeMseGain = validationPrediction;
validation.minimumGateUse = minimumUse;
validation.conservativeGateUse = conservativeUse;
validation.oracleGateUse = oracleUse;
writetable(calibration, fullfile(outputFolder, ...
    "learned_gate_calibration_trials.csv"));
writetable(thresholdScores, fullfile(outputFolder, ...
    "learned_gate_threshold_scores.csv"));
writetable(selectedMinimum, fullfile(outputFolder, ...
    "learned_gate_selected_minimum.csv"));
writetable(selectedConservative, fullfile(outputFolder, ...
    "learned_gate_selected_conservative.csv"));
writetable(featureImportance, fullfile(outputFolder, ...
    "learned_gate_feature_importance.csv"));
writetable(validation, fullfile(outputFolder, ...
    "learned_gate_validation_trials.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "learned_gate_validation_details.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "learned_gate_validation_summary.csv"));
writetable(paperComparison, fullfile(outputFolder, ...
    "learned_gate_paper_comparison.csv"));
save(fullfile(outputFolder, "learned_confidence_gate.mat"), ...
    "cfg", "fusionCarriers", "frontOffsetsDeg", "snrValues", ...
    "numCalibrationPerSnr", "numValidationPerSnr", "featureNames", ...
    "calibration", "model", "thresholdScores", "selectedMinimum", ...
    "selectedConservative", "featureImportance", "validation", ...
    "validationDetails", "validationSummary", "paperComparison");
plotComparison(validationSummary, paperComparison, fullfile(outputFolder, ...
    "learned_confidence_gate.png"));

disp(selectedMinimum);
disp(selectedConservative);
disp(featureImportance(1:min(12, height(featureImportance)), :));
disp(validationSummary);
disp(paperComparison);
end

function trials = runFeatureTrials(cfg, scan, snrValues, numPerSnr, ...
    randomizeLocation, fusionCarriers, frontOffsetsDeg, seedBase, ...
    checkpointFile)
numSnr = numel(snrValues);
numRows = numSnr * numPerSnr;
completedSnrCount = 0;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    trials = checkpoint.trials;
    completedSnrCount = checkpoint.completedSnrCount;
else
    trials = initializeTrials(snrValues, numPerSnr);
end

for snrIndex = completedSnrCount + 1:numSnr
    stream = RandStream("mt19937ar", Seed=seedBase + snrIndex);
    rows = (snrIndex - 1) * numPerSnr + (1:numPerSnr);
    for trialIndex = 1:numPerSnr
        row = rows(trialIndex);
        if randomizeLocation
            truthThetaDeg = 5 + 20 * rand(stream);
            truthRangeM = 20 + 20 * rand(stream);
        else
            truthThetaDeg = 15;
            truthRangeM = 30;
        end
        truthResponse = fsjad.exactSpectralResponse(cfg, ...
            deg2rad(truthThetaDeg), truthRangeM, scan);
        signalPower = mean(abs(truthResponse).^2);
        noiseVariance = signalPower / 10^(snrValues(snrIndex) / 10);
        beta = exp(1i * 2 * pi * rand(stream));
        noise = sqrt(noiseVariance / 2) * (randn(stream, ...
            cfg.numSubcarriers, 1) + 1i * randn(stream, ...
            cfg.numSubcarriers, 1));
        observation = beta * truthResponse + noise;
        [~, peakPosition] = max(abs(observation).^2);
        peakCarrierIndex = peakPosition - 1;
        front = fsjad.angleMultistartProfileEstimate(cfg, observation, ...
            scan, frontOffsetsDeg);
        carrierIndex = fixedCountWindow(peakCarrierIndex, ...
            fusionCarriers, cfg.numSubcarriers);
        snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, ...
            truthRangeM, snrValues(snrIndex), carrierIndex, stream);
        music = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
            front.thetaDeg, front.rangeM);
        diagnostics = fsjad.musicConfidenceFeatures(front, music);

        trials.truthThetaDeg(row) = truthThetaDeg;
        trials.truthRangeM(row) = truthRangeM;
        trials.frontThetaDeg(row) = front.thetaDeg;
        trials.frontRangeM(row) = front.rangeM;
        trials.musicThetaDeg(row) = music.thetaDeg;
        trials.musicRangeM(row) = music.rangeM;
        trials.frontAngleErrorDeg(row) = front.thetaDeg - truthThetaDeg;
        trials.frontRangeErrorM(row) = front.rangeM - truthRangeM;
        trials.musicAngleErrorDeg(row) = music.thetaDeg - truthThetaDeg;
        trials.musicRangeErrorM(row) = music.rangeM - truthRangeM;
        diagnosticNames = string(fieldnames(diagnostics));
        for diagnosticIndex = 1:numel(diagnosticNames)
            name = diagnosticNames(diagnosticIndex);
            trials.(name)(row) = diagnostics.(name);
        end
        fprintf("Learned gate %s SNR %g dB trial %d/%d complete.\n", ...
            locationLabel(randomizeLocation), snrValues(snrIndex), ...
            trialIndex, numPerSnr);
    end
    completedSnrCount = snrIndex;
    save(checkpointFile, "trials", "completedSnrCount");
end
assert(height(trials) == numRows);
end

function trials = initializeTrials(snrValues, numPerSnr)
data.snrDb = repelem(snrValues, numPerSnr);
baseNames = ["truthThetaDeg", "truthRangeM", "frontThetaDeg", ...
    "frontRangeM", "musicThetaDeg", "musicRangeM", ...
    "frontAngleErrorDeg", "frontRangeErrorM", ...
    "musicAngleErrorDeg", "musicRangeErrorM"];
featureNames = confidenceFeatureNames();
allNames = [baseNames, featureNames(featureNames ~= "snrDb" ...
    & featureNames ~= "frontThetaDeg" & featureNames ~= "frontRangeM")];
for nameIndex = 1:numel(allNames)
    data.(allNames(nameIndex)) = zeros(numel(data.snrDb), 1);
end
trials = struct2table(data);
end

function label = locationLabel(randomizeLocation)
if randomizeLocation
    label = "calibration";
else
    label = "validation";
end
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

function [model, outOfFoldPrediction, thresholdScores, ...
    selectedMinimum, selectedConservative, featureImportance] = ...
    trainGate(calibration, featureNames, randomSeed)
predictors = calibration(:, featureNames);
targetGain = calibration.frontRangeErrorM.^2 ...
    - calibration.musicRangeErrorM.^2;
numFolds = 5;
foldIndex = mod((0:height(calibration) - 1).', numFolds) + 1;
outOfFoldPrediction = zeros(height(calibration), 1);
treeTemplate = templateTree(MinLeafSize=8, MaxNumSplits=25, ...
    Surrogate="off");
previousRandomState = rng;
cleanupRandomState = onCleanup(@() rng(previousRandomState));
rng(randomSeed, "twister");
for fold = 1:numFolds
    trainRows = foldIndex ~= fold;
    testRows = foldIndex == fold;
    foldModel = fitrensemble(predictors(trainRows, :), ...
        targetGain(trainRows), Method="Bag", NumLearningCycles=150, ...
        Learners=treeTemplate);
    outOfFoldPrediction(testRows) = predict( ...
        foldModel, predictors(testRows, :));
end
model = fitrensemble(predictors, targetGain, Method="Bag", ...
    NumLearningCycles=300, Learners=treeTemplate);

thresholdCandidates = unique([-inf; 0; quantile(outOfFoldPrediction, ...
    (0.02:0.02:0.98).'); inf]);
thresholdScores = scoreThresholds(calibration, outOfFoldPrediction, ...
    thresholdCandidates, foldIndex, numFolds);
ranking = sortrows(thresholdScores, ...
    ["rangeMseChange", "updateRate"], ["ascend", "ascend"]);
selectedMinimum = ranking(1, :);
oneStandardErrorLimit = selectedMinimum.rangeMseChange ...
    + selectedMinimum.standardErrorMseChange;
eligible = thresholdScores.rangeMseChange <= oneStandardErrorLimit;
conservativeRanking = sortrows(thresholdScores(eligible, :), ...
    ["updateRate", "rangeMseChange"], ["ascend", "ascend"]);
selectedConservative = conservativeRanking(1, :);

importance = predictorImportance(model).';
featureImportance = table(featureNames.', importance, ...
    VariableNames=["feature", "importance"]);
featureImportance = sortrows(featureImportance, "importance", "descend");
end

function scores = scoreThresholds(trials, prediction, thresholds, ...
    foldIndex, numFolds)
numThresholds = numel(thresholds);
predictionThreshold = thresholds;
rangeRmseM = zeros(numThresholds, 1);
rangeMseChange = zeros(numThresholds, 1);
standardErrorMseChange = zeros(numThresholds, 1);
updateRate = zeros(numThresholds, 1);
improvementRate = zeros(numThresholds, 1);
frontSquaredError = trials.frontRangeErrorM.^2;
for thresholdIndex = 1:numThresholds
    useMusic = prediction > thresholds(thresholdIndex);
    hybridError = trials.frontRangeErrorM;
    hybridError(useMusic) = trials.musicRangeErrorM(useMusic);
    squaredChange = hybridError.^2 - frontSquaredError;
    foldMeanChange = zeros(numFolds, 1);
    for fold = 1:numFolds
        foldMeanChange(fold) = mean(squaredChange(foldIndex == fold));
    end
    rangeRmseM(thresholdIndex) = sqrt(mean(hybridError.^2));
    rangeMseChange(thresholdIndex) = mean(squaredChange);
    standardErrorMseChange(thresholdIndex) = std(foldMeanChange) ...
        / sqrt(numFolds);
    updateRate(thresholdIndex) = mean(useMusic);
    improvementRate(thresholdIndex) = mean( ...
        hybridError.^2 < frontSquaredError);
end
scores = table(predictionThreshold, rangeRmseM, rangeMseChange, ...
    standardErrorMseChange, updateRate, improvementRate);
end

function [details, summary] = summarizeValidation(trials, minimumUse, ...
    conservativeUse, oracleUse, snrValues)
numTrials = height(trials);
methodNames = ["Full-spectrum front"; "Fixed narrow MUSIC"; ...
    "Learned minimum gate"; "Learned conservative gate"; "Oracle gate"];
numMethods = numel(methodNames);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(trials.snrDb, numMethods);
minimumError = gatedError(trials, minimumUse);
conservativeError = gatedError(trials, conservativeUse);
oracleError = gatedError(trials, oracleUse);
angleErrorDeg = [trials.frontAngleErrorDeg.'; ...
    trials.musicAngleErrorDeg.'; trials.musicAngleErrorDeg.'; ...
    trials.musicAngleErrorDeg.'; trials.musicAngleErrorDeg.'];
rangeErrorM = [trials.frontRangeErrorM.'; ...
    trials.musicRangeErrorM.'; minimumError.'; conservativeError.'; ...
    oracleError.'];
updatedRange = [false(1, numTrials); true(1, numTrials); ...
    minimumUse.'; conservativeUse.'; oracleUse.'];
details = table(method, snrDb, angleErrorDeg(:), rangeErrorM(:), ...
    updatedRange(:), VariableNames=["method", "snrDb", ...
    "angleErrorDeg", "rangeErrorM", "updatedRange"]);

numRows = numMethods * numel(snrValues);
summaryMethod = strings(numRows, 1);
summarySnrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
updateRate = zeros(numRows, 1);
row = 0;
for methodIndex = 1:numMethods
    for snrIndex = 1:numel(snrValues)
        row = row + 1;
        rows = details.method == methodNames(methodIndex) ...
            & details.snrDb == snrValues(snrIndex);
        summaryMethod(row) = methodNames(methodIndex);
        summarySnrDb(row) = snrValues(snrIndex);
        angleRmseDeg(row) = sqrt(mean(details.angleErrorDeg(rows).^2));
        rangeRmseM(row) = sqrt(mean(details.rangeErrorM(rows).^2));
        updateRate(row) = mean(details.updatedRange(rows));
    end
end
summary = table(summaryMethod, summarySnrDb, angleRmseDeg, ...
    rangeRmseM, updateRate, VariableNames=["method", "snrDb", ...
    "angleRmseDeg", "rangeRmseM", "updateRate"]);
end

function error = gatedError(trials, useMusic)
error = trials.frontRangeErrorM;
error(useMusic) = trials.musicRangeErrorM(useMusic);
end

function comparison = compareWithPublished(summary, snrValues)
methodName = "Learned conservative gate";
rows = summary.method == methodName;
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

function plotComparison(summary, comparison, outputFile)
figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotMetric(summary, comparison, "angleRmseDeg", ...
    "publishedAngleRmseDeg", "Angle RMSE (deg)");
plotMetric(summary, comparison, "rangeRmseM", ...
    "publishedRangeRmseM", "Range RMSE (m)");
title(layout, "Learned single-path confidence gate vs published Fig. 10");
exportgraphics(figureHandle, outputFile, Resolution=180);
close(figureHandle);
end

function plotMetric(summary, comparison, localVariable, ...
    publishedVariable, yLabel)
axisHandle = nexttile;
axisHandle.YScale = "log";
hold(axisHandle, "on");
methodNames = unique(summary.method, "stable");
lineStyles = ["-o", "-s", "-^", "-v", "--d"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.(localVariable)(rows), ...
        lineStyles(methodIndex), LineWidth=1.3, MarkerSize=5);
end
semilogy(comparison.snrDb, comparison.(publishedVariable), ":p", ...
    LineWidth=1.5, MarkerSize=6);
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, yLabel);
legend(axisHandle, [methodNames; "Published Proposed"], Location="best");
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end
