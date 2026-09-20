function run_covariance_alpha_experiment
%RUN_COVARIANCE_ALPHA_EXPERIMENT Calibrate and validate truth-free alpha.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round10");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
snrValues = (-10:5:0).';
groupCounts = [4, 8, 16];
numCalibrationPerSnr = 20;
numValidationPerSnr = 100;
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];

calibration = runTrials(cfg, scan, snrValues, numCalibrationPerSnr, ...
    fusionCarriers, frontOffsetsDeg, groupCounts, ...
    cfg.randomSeed + 2501, fullfile(outputFolder, ...
    "covariance_alpha_calibration_checkpoint.mat"));
[calibrationScores, selected] = selectAnalyticRule(calibration, groupCounts);

validation = runTrials(cfg, scan, snrValues, numValidationPerSnr, ...
    fusionCarriers, frontOffsetsDeg, selected.numGroups, ...
    cfg.randomSeed + 2701, fullfile(outputFolder, ...
    "covariance_alpha_validation_checkpoint.mat"));
empirical = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round9", "range_shrinkage_screening.mat"), "snrAlphaTable");
[validationDetails, validationSummary, pairedStatistics] = ...
    summarizeValidation(validation, selected, empirical.snrAlphaTable, ...
    snrValues);
[pairwiseStatistics, pooledStatistics] = compareRangeMethods( ...
    validationDetails, snrValues);
paperComparison = compareWithPublished(validationSummary, snrValues);

writetable(calibrationScores, fullfile(outputFolder, ...
    "covariance_alpha_calibration_scores.csv"));
writetable(selected, fullfile(outputFolder, ...
    "covariance_alpha_selected.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "covariance_alpha_validation_details.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "covariance_alpha_validation_summary.csv"));
writetable(pairedStatistics, fullfile(outputFolder, ...
    "covariance_alpha_paired_statistics.csv"));
writetable(pairwiseStatistics, fullfile(outputFolder, ...
    "covariance_alpha_pairwise_statistics.csv"));
writetable(pooledStatistics, fullfile(outputFolder, ...
    "covariance_alpha_pooled_statistics.csv"));
writetable(paperComparison, fullfile(outputFolder, ...
    "covariance_alpha_paper_comparison.csv"));
save(fullfile(outputFolder, "covariance_alpha_experiment.mat"), ...
    "cfg", "snrValues", "groupCounts", "numCalibrationPerSnr", ...
    "numValidationPerSnr", "fusionCarriers", "frontOffsetsDeg", ...
    "calibration", "calibrationScores", "selected", "validation", ...
    "validationDetails", "validationSummary", "pairedStatistics", ...
    "pairwiseStatistics", "pooledStatistics", "paperComparison");
plotResults(validationSummary, paperComparison, fullfile(outputFolder, ...
    "covariance_alpha_validation.png"));

disp(calibrationScores);
disp(selected);
disp(validationSummary);
disp(pairedStatistics);
disp(pairwiseStatistics);
disp(pooledStatistics);
disp(paperComparison);
end

function trials = runTrials(cfg, scan, snrValues, numPerSnr, ...
    fusionCarriers, frontOffsetsDeg, groupCounts, seedBase, checkpointFile)
groupCounts = groupCounts(:).';
numGroupsConfigurations = numel(groupCounts);
numRows = numel(snrValues) * numPerSnr;
completedSnrCount = 0;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    trials = checkpoint.trials;
    completedSnrCount = checkpoint.completedSnrCount;
else
    trials = initializeTrials(snrValues, numPerSnr, ...
        numGroupsConfigurations);
end

truthThetaDeg = 15;
truthRangeM = 30;
truthResponse = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
for snrIndex = completedSnrCount + 1:numel(snrValues)
    stream = RandStream("mt19937ar", Seed=seedBase + snrIndex);
    rows = (snrIndex - 1) * numPerSnr + (1:numPerSnr);
    noiseVariance = signalPower / 10^(snrValues(snrIndex) / 10);
    for trialIndex = 1:numPerSnr
        row = rows(trialIndex);
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

        trials.frontAngleErrorDeg(row) = front.thetaDeg - truthThetaDeg;
        trials.frontRangeErrorM(row) = front.rangeM - truthRangeM;
        trials.musicAngleErrorDeg(row) = music.thetaDeg - truthThetaDeg;
        trials.musicRangeErrorM(row) = music.rangeM - truthRangeM;
        for configurationIndex = 1:numGroupsConfigurations
            diagnostics = fsjad.groupedCovarianceShrinkage(cfg, ...
                observation, snapshots, carrierIndex, front, scan, ...
                groupCounts(configurationIndex));
            trials.rawAlpha(row, configurationIndex) = diagnostics.rawAlpha;
            trials.conservativeAlpha(row, configurationIndex) = ...
                diagnostics.conservativeAlpha;
            trials.independentAlpha(row, configurationIndex) = ...
                diagnostics.independentAlpha;
            trials.negativeCrossMoment(row, configurationIndex) = ...
                diagnostics.negativeCrossMoment;
            trials.deltaVariance(row, configurationIndex) = ...
                diagnostics.deltaVariance;
        end
        fprintf("Covariance alpha SNR %g dB trial %d/%d complete.\n", ...
            snrValues(snrIndex), trialIndex, numPerSnr);
    end
    completedSnrCount = snrIndex;
    save(checkpointFile, "trials", "completedSnrCount");
end
assert(height(trials.base) == numRows);
end

function trials = initializeTrials(snrValues, numPerSnr, numConfigurations)
snrDb = repelem(snrValues, numPerSnr);
numRows = numel(snrDb);
trials.base = table(snrDb, zeros(numRows, 1), zeros(numRows, 1), ...
    zeros(numRows, 1), zeros(numRows, 1), VariableNames=["snrDb", ...
    "frontAngleErrorDeg", "frontRangeErrorM", ...
    "musicAngleErrorDeg", "musicRangeErrorM"]);
trials.frontAngleErrorDeg = trials.base.frontAngleErrorDeg;
trials.frontRangeErrorM = trials.base.frontRangeErrorM;
trials.musicAngleErrorDeg = trials.base.musicAngleErrorDeg;
trials.musicRangeErrorM = trials.base.musicRangeErrorM;
trials.rawAlpha = zeros(numRows, numConfigurations);
trials.conservativeAlpha = zeros(numRows, numConfigurations);
trials.independentAlpha = zeros(numRows, numConfigurations);
trials.negativeCrossMoment = zeros(numRows, numConfigurations);
trials.deltaVariance = zeros(numRows, numConfigurations);
end

function [scores, selected] = selectAnalyticRule(trials, groupCounts)
alphaTypes = ["raw"; "conservative"; "independent"];
numRows = numel(groupCounts) * numel(alphaTypes);
numGroups = zeros(numRows, 1);
alphaType = strings(numRows, 1);
rangeRmseM = zeros(numRows, 1);
rangeMseChange = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1);
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
row = 0;
for groupIndex = 1:numel(groupCounts)
    for typeIndex = 1:numel(alphaTypes)
        row = row + 1;
        alpha = alphaColumn(trials, alphaTypes(typeIndex), groupIndex);
        fusedError = trials.frontRangeErrorM + alpha .* delta;
        numGroups(row) = groupCounts(groupIndex);
        alphaType(row) = alphaTypes(typeIndex);
        rangeRmseM(row) = sqrt(mean(fusedError.^2));
        rangeMseChange(row) = mean( ...
            fusedError.^2 - trials.frontRangeErrorM.^2);
        meanAlpha(row) = mean(alpha);
    end
end
scores = table(numGroups, alphaType, rangeRmseM, ...
    rangeMseChange, meanAlpha);
ranking = sortrows(scores, ["rangeRmseM", "meanAlpha"], ...
    ["ascend", "ascend"]);
selected = ranking(1, :);
end

function [details, summary, statistics] = summarizeValidation( ...
    trials, selected, empiricalAlphaTable, snrValues)
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
selectedGroupIndex = 1;
selectedAlpha = alphaColumn(trials, selected.alphaType, selectedGroupIndex);
rawAlpha = trials.rawAlpha(:, selectedGroupIndex);
conservativeAlpha = trials.conservativeAlpha(:, selectedGroupIndex);
independentAlpha = trials.independentAlpha(:, selectedGroupIndex);
empiricalAlpha = zeros(size(delta));
for snrIndex = 1:numel(snrValues)
    rows = trials.base.snrDb == snrValues(snrIndex);
    source = empiricalAlphaTable.snrDb == snrValues(snrIndex);
    empiricalAlpha(rows) = empiricalAlphaTable.alpha(source);
end
oracleAlpha = fsjad.oracleRangeShrinkage(trials.frontRangeErrorM, delta);

methodNames = ["Full-spectrum front"; "Zhang-style full MUSIC"; ...
    "Covariance raw"; "Covariance conservative"; ...
    "Independent-variance approximation"; "Selected analytic"; ...
    "Empirical SNR shrinkage"; "Oracle shrinkage"];
alphaMatrix = [zeros(size(delta)).'; ones(size(delta)).'; ...
    rawAlpha.'; conservativeAlpha.'; independentAlpha.'; ...
    selectedAlpha.'; empiricalAlpha.'; oracleAlpha.'];
errorMatrix = trials.frontRangeErrorM.' + alphaMatrix .* delta.';
angleMatrix = [trials.frontAngleErrorDeg.'; ...
    repmat(trials.musicAngleErrorDeg.', numel(methodNames) - 1, 1)];
numTrials = numel(delta);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(trials.base.snrDb, numel(methodNames));
details = table(method, snrDb, angleMatrix(:), errorMatrix(:), ...
    alphaMatrix(:), VariableNames=["method", "snrDb", ...
    "angleErrorDeg", "rangeErrorM", "alpha"]);

[summary, statistics] = groupMetrics(details, trials.frontRangeErrorM, ...
    trials.base.snrDb, methodNames, snrValues);
end

function alpha = alphaColumn(trials, alphaType, groupIndex)
if alphaType == "raw"
    alpha = trials.rawAlpha(:, groupIndex);
elseif alphaType == "conservative"
    alpha = trials.conservativeAlpha(:, groupIndex);
elseif alphaType == "independent"
    alpha = trials.independentAlpha(:, groupIndex);
else
    error("fsjad:UnknownAlphaType", "Unknown alpha type.");
end
end

function [summary, statistics] = groupMetrics(details, frontError, ...
    trialSnrDb, methodNames, snrValues)
numRows = numel(methodNames) * numel(snrValues);
summaryMethod = strings(numRows, 1);
summarySnrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1);
mseChange = zeros(numRows, 1);
standardErrorMseChange = zeros(numRows, 1);
ci95LowerMseChange = zeros(numRows, 1);
ci95UpperMseChange = zeros(numRows, 1);
row = 0;
for methodIndex = 1:numel(methodNames)
    for snrIndex = 1:numel(snrValues)
        row = row + 1;
        rows = details.method == methodNames(methodIndex) ...
            & details.snrDb == snrValues(snrIndex);
        trialRows = trialSnrDb == snrValues(snrIndex);
        squaredChange = details.rangeErrorM(rows).^2 ...
            - frontError(trialRows).^2;
        standardError = std(squaredChange) / sqrt(sum(rows));
        summaryMethod(row) = methodNames(methodIndex);
        summarySnrDb(row) = snrValues(snrIndex);
        angleRmseDeg(row) = sqrt(mean(details.angleErrorDeg(rows).^2));
        rangeRmseM(row) = sqrt(mean(details.rangeErrorM(rows).^2));
        meanAlpha(row) = mean(details.alpha(rows));
        mseChange(row) = mean(squaredChange);
        standardErrorMseChange(row) = standardError;
        ci95LowerMseChange(row) = mseChange(row) - 1.96 * standardError;
        ci95UpperMseChange(row) = mseChange(row) + 1.96 * standardError;
    end
end
summary = table(summaryMethod, summarySnrDb, angleRmseDeg, ...
    rangeRmseM, meanAlpha, VariableNames=["method", "snrDb", ...
    "angleRmseDeg", "rangeRmseM", "meanAlpha"]);
statistics = table(summaryMethod, summarySnrDb, mseChange, ...
    standardErrorMseChange, ci95LowerMseChange, ci95UpperMseChange, ...
    VariableNames=["method", "snrDb", "mseChange", ...
    "standardErrorMseChange", "ci95LowerMseChange", ...
    "ci95UpperMseChange"]);
end

function comparison = compareWithPublished(summary, snrValues)
rows = summary.method == "Selected analytic";
snrDb = summary.snrDb(rows);
assert(isequal(snrDb, snrValues));
analyticAngleRmseDeg = summary.angleRmseDeg(rows);
analyticRangeRmseM = summary.rangeRmseM(rows);
publishedAngleRmseDeg = [0.10222305; 0.026220697; 0.0077105099];
publishedRangeRmseM = [0.099998239; 0.039411058; 0.015372596];
angleRatioToPublished = analyticAngleRmseDeg ./ publishedAngleRmseDeg;
rangeRatioToPublished = analyticRangeRmseM ./ publishedRangeRmseM;
comparison = table(snrDb, analyticAngleRmseDeg, ...
    publishedAngleRmseDeg, angleRatioToPublished, analyticRangeRmseM, ...
    publishedRangeRmseM, rangeRatioToPublished);
end

function [statistics, pooled] = compareRangeMethods(details, snrValues)
methodNames = ["Selected analytic"; "Covariance conservative"];
referenceNames = ["Full-spectrum front"; "Zhang-style full MUSIC"];
numRows = numel(methodNames) * numel(referenceNames) * numel(snrValues);
method = strings(numRows, 1);
reference = strings(numRows, 1);
snrDb = zeros(numRows, 1);
methodRangeRmseM = zeros(numRows, 1);
referenceRangeRmseM = zeros(numRows, 1);
mseChange = zeros(numRows, 1);
ci95LowerMseChange = zeros(numRows, 1);
ci95UpperMseChange = zeros(numRows, 1);
row = 0;
for methodIndex = 1:numel(methodNames)
    for referenceIndex = 1:numel(referenceNames)
        for snrIndex = 1:numel(snrValues)
            row = row + 1;
            methodRows = details.method == methodNames(methodIndex) ...
                & details.snrDb == snrValues(snrIndex);
            referenceRows = details.method == ...
                referenceNames(referenceIndex) ...
                & details.snrDb == snrValues(snrIndex);
            methodError = details.rangeErrorM(methodRows);
            referenceError = details.rangeErrorM(referenceRows);
            [change, lower, upper] = pairedMseInterval( ...
                methodError, referenceError);
            method(row) = methodNames(methodIndex);
            reference(row) = referenceNames(referenceIndex);
            snrDb(row) = snrValues(snrIndex);
            methodRangeRmseM(row) = sqrt(mean(methodError.^2));
            referenceRangeRmseM(row) = sqrt(mean(referenceError.^2));
            mseChange(row) = change;
            ci95LowerMseChange(row) = lower;
            ci95UpperMseChange(row) = upper;
        end
    end
end
statistics = table(method, reference, snrDb, methodRangeRmseM, ...
    referenceRangeRmseM, mseChange, ci95LowerMseChange, ...
    ci95UpperMseChange);

numPooledRows = numel(methodNames) * numel(referenceNames);
method = strings(numPooledRows, 1);
reference = strings(numPooledRows, 1);
methodRangeRmseM = zeros(numPooledRows, 1);
referenceRangeRmseM = zeros(numPooledRows, 1);
mseChange = zeros(numPooledRows, 1);
ci95LowerMseChange = zeros(numPooledRows, 1);
ci95UpperMseChange = zeros(numPooledRows, 1);
row = 0;
for methodIndex = 1:numel(methodNames)
    for referenceIndex = 1:numel(referenceNames)
        row = row + 1;
        methodError = details.rangeErrorM( ...
            details.method == methodNames(methodIndex));
        referenceError = details.rangeErrorM( ...
            details.method == referenceNames(referenceIndex));
        [change, lower, upper] = pairedMseInterval( ...
            methodError, referenceError);
        method(row) = methodNames(methodIndex);
        reference(row) = referenceNames(referenceIndex);
        methodRangeRmseM(row) = sqrt(mean(methodError.^2));
        referenceRangeRmseM(row) = sqrt(mean(referenceError.^2));
        mseChange(row) = change;
        ci95LowerMseChange(row) = lower;
        ci95UpperMseChange(row) = upper;
    end
end
pooled = table(method, reference, methodRangeRmseM, ...
    referenceRangeRmseM, mseChange, ci95LowerMseChange, ...
    ci95UpperMseChange);
end

function [change, lower, upper] = pairedMseInterval( ...
    methodError, referenceError)
assert(numel(methodError) == numel(referenceError));
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
standardError = std(squaredChange) / sqrt(numel(squaredChange));
lower = change - 1.96 * standardError;
upper = change + 1.96 * standardError;
end

function plotResults(summary, comparison, outputFile)
figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
methodNames = unique(summary.method, "stable");
lineStyles = ["-o", "-s", "-^", "-v", "-d", "-x", "--+", "--p"];
axisHandle = nexttile;
axisHandle.YScale = "log";
hold(axisHandle, "on");
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.rangeRmseM(rows), ...
        lineStyles(methodIndex), LineWidth=1.2, MarkerSize=5);
end
semilogy(comparison.snrDb, comparison.publishedRangeRmseM, ":h", ...
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
ylabel(axisHandle, "Mean alpha");
ylim(axisHandle, [0, 1]);
legend(axisHandle, methodNames(3:end), Location="best");
title(layout, "Truth-free covariance shrinkage validation");
exportgraphics(figureHandle, outputFile, Resolution=180);
close(figureHandle);
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end
