function run_shrinkage_low_snr_stress
%RUN_SHRINKAGE_LOW_SNR_STRESS Stress-test frozen shrinkage at low SNR.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round9");
screening = load(fullfile(outputFolder, "range_shrinkage_screening.mat"));

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
snrValues = (-10:5:0).';
numPerSnr = 200;
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];

trials = runTrials(cfg, scan, snrValues, numPerSnr, ...
    fusionCarriers, frontOffsetsDeg, cfg.randomSeed + 2301, ...
    fullfile(outputFolder, "shrinkage_stress_checkpoint.mat"));
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
predictedAlpha = min(max(predict(screening.model, ...
    trials(:, screening.featureNames)), 0), 1);
globalAlpha = screening.globalAlpha * ones(height(trials), 1);
snrAlpha = zeros(height(trials), 1);
for snrIndex = 1:numel(snrValues)
    rows = trials.snrDb == snrValues(snrIndex);
    sourceRow = screening.snrAlphaTable.snrDb == snrValues(snrIndex);
    snrAlpha(rows) = screening.snrAlphaTable.alpha(sourceRow);
end
minimumAlpha = screening.selectedMinimum.alphaScale * predictedAlpha;
conservativeAlpha = screening.selectedConservative.alphaScale ...
    * predictedAlpha;
oracleAlpha = fsjad.oracleRangeShrinkage(trials.frontRangeErrorM, delta);

[details, summary, pairedStatistics] = summarizeMethods(trials, delta, ...
    globalAlpha, snrAlpha, minimumAlpha, conservativeAlpha, ...
    oracleAlpha, snrValues);
paperComparison = compareWithPublished(summary, snrValues);
trials.predictedAlpha = predictedAlpha;
trials.minimumAlpha = minimumAlpha;
trials.conservativeAlpha = conservativeAlpha;
trials.oracleAlpha = oracleAlpha;
writetable(trials, fullfile(outputFolder, ...
    "shrinkage_stress_trials.csv"));
writetable(details, fullfile(outputFolder, ...
    "shrinkage_stress_details.csv"));
writetable(summary, fullfile(outputFolder, ...
    "shrinkage_stress_summary.csv"));
writetable(pairedStatistics, fullfile(outputFolder, ...
    "shrinkage_stress_paired_statistics.csv"));
writetable(paperComparison, fullfile(outputFolder, ...
    "shrinkage_stress_paper_comparison.csv"));
save(fullfile(outputFolder, "shrinkage_low_snr_stress.mat"), ...
    "cfg", "snrValues", "numPerSnr", "fusionCarriers", ...
    "frontOffsetsDeg", "trials", "details", "summary", ...
    "pairedStatistics", "paperComparison");
plotResults(summary, paperComparison, fullfile(outputFolder, ...
    "shrinkage_low_snr_stress.png"));

disp(summary);
disp(pairedStatistics);
disp(paperComparison);
end

function trials = runTrials(cfg, scan, snrValues, numPerSnr, ...
    fusionCarriers, frontOffsetsDeg, seedBase, checkpointFile)
numSnr = numel(snrValues);
completedSnrCount = 0;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    trials = checkpoint.trials;
    completedSnrCount = checkpoint.completedSnrCount;
else
    trials = initializeTrials(snrValues, numPerSnr);
end

truthThetaDeg = 15;
truthRangeM = 30;
truthResponse = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
for snrIndex = completedSnrCount + 1:numSnr
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
        diagnostics = fsjad.musicConfidenceFeatures(front, music);

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
        fprintf("Shrinkage stress SNR %g dB trial %d/%d complete.\n", ...
            snrValues(snrIndex), trialIndex, numPerSnr);
    end
    completedSnrCount = snrIndex;
    save(checkpointFile, "trials", "completedSnrCount");
end
end

function trials = initializeTrials(snrValues, numPerSnr)
data.snrDb = repelem(snrValues, numPerSnr);
baseNames = ["frontThetaDeg", "frontRangeM", "musicThetaDeg", ...
    "musicRangeM", "frontAngleErrorDeg", "frontRangeErrorM", ...
    "musicAngleErrorDeg", "musicRangeErrorM"];
featureNames = confidenceFeatureNames();
allNames = [baseNames, featureNames(featureNames ~= "snrDb" ...
    & featureNames ~= "frontThetaDeg" & featureNames ~= "frontRangeM")];
for nameIndex = 1:numel(allNames)
    data.(allNames(nameIndex)) = zeros(numel(data.snrDb), 1);
end
trials = struct2table(data);
end

function [details, summary, pairedStatistics] = summarizeMethods( ...
    trials, delta, globalAlpha, snrAlpha, minimumAlpha, ...
    conservativeAlpha, oracleAlpha, snrValues)
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
        frontRows = trials.snrDb == snrValues(snrIndex);
        squaredChange = details.rangeErrorM(rows).^2 ...
            - trials.frontRangeErrorM(frontRows).^2;
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
pairedStatistics = table(summaryMethod, summarySnrDb, mseChange, ...
    standardErrorMseChange, ci95LowerMseChange, ci95UpperMseChange, ...
    VariableNames=["method", "snrDb", "mseChange", ...
    "standardErrorMseChange", "ci95LowerMseChange", ...
    "ci95UpperMseChange"]);
end

function comparison = compareWithPublished(summary, snrValues)
rows = summary.method == "Learned conservative shrinkage";
snrDb = summary.snrDb(rows);
assert(isequal(snrDb, snrValues));
learnedAngleRmseDeg = summary.angleRmseDeg(rows);
learnedRangeRmseM = summary.rangeRmseM(rows);
publishedAngleRmseDeg = [0.10222305; 0.026220697; 0.0077105099];
publishedRangeRmseM = [0.099998239; 0.039411058; 0.015372596];
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
        lineStyles(methodIndex), LineWidth=1.2, MarkerSize=6);
end
semilogy(comparison.snrDb, comparison.publishedRangeRmseM, ":p", ...
    LineWidth=1.5, MarkerSize=7);
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
        lineStyles(methodIndex), LineWidth=1.2, MarkerSize=6);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Mean shrinkage coefficient");
ylim(axisHandle, [0, 1]);
legend(axisHandle, methodNames(3:end), Location="best");
title(layout, "Frozen low-SNR shrinkage stress test, 200 trials/SNR");
exportgraphics(figureHandle, outputFile, Resolution=180);
close(figureHandle);
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
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
