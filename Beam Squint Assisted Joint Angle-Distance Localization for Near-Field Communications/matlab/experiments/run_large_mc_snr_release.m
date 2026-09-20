function run_large_mc_snr_release
%RUN_LARGE_MC_SNR_RELEASE Calibrate and validate SNR-released raw alpha.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round12");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 12 uses %d parallel workers.\n", pool.NumWorkers);

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
snrValues = (-10:5:0).';
fusionCarriers = 513;
bootstrapCarrierCount = 65;
bootstrapCount = 8;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
batchSize = 24;

numCalibrationPerSnr = 300;
calibration = runTrials(cfg, scan, snrValues, ...
    numCalibrationPerSnr, fusionCarriers, frontOffsetsDeg, ...
    bootstrapCarrierCount, bootstrapCount, cfg.randomSeed + 4101, ...
    batchSize, true, fullfile(outputFolder, ...
    "snr_release_calibration_checkpoint.mat"));
baseTypes = ["zero"; "raw"; "conservative"];
snrSources = ["front"; "snapshot"; "mean"];
thresholdValuesDb = [-5, -4, -3, -2, -1, 0];
slopeValuesDb = [1, 1.5, 2, 3];
[calibrationScores, selectedRule] = calibrateReleaseRule( ...
    calibration, snrValues, baseTypes, snrSources, ...
    thresholdValuesDb, slopeValuesDb);
writetable(calibrationScores, fullfile(outputFolder, ...
    "snr_release_calibration_scores.csv"));
writetable(selectedRule, fullfile(outputFolder, ...
    "snr_release_selected_rule.csv"));
save(fullfile(outputFolder, "snr_release_calibration.mat"), ...
    "cfg", "snrValues", "fusionCarriers", "bootstrapCarrierCount", ...
    "bootstrapCount", "frontOffsetsDeg", "batchSize", ...
    "numCalibrationPerSnr", "calibration", "baseTypes", ...
    "snrSources", "thresholdValuesDb", "slopeValuesDb", ...
    "calibrationScores", "selectedRule");
disp(selectedRule);

numValidationPerSnr = 3334;
validation = runTrials(cfg, scan, snrValues, numValidationPerSnr, ...
    fusionCarriers, frontOffsetsDeg, bootstrapCarrierCount, ...
    bootstrapCount, cfg.randomSeed + 5101, batchSize, false, ...
    fullfile(outputFolder, "snr_release_validation_checkpoint.mat"));
[details, summary, pairwise, pooled, seedAudit] = ...
    summarizeValidation(validation, selectedRule, snrValues, ...
    cfg.randomSeed + 5101);
paperComparison = compareWithPublished(summary, snrValues);

writetable(details, fullfile(outputFolder, ...
    "snr_release_validation_details.csv"));
writetable(summary, fullfile(outputFolder, ...
    "snr_release_validation_summary.csv"));
writetable(pairwise, fullfile(outputFolder, ...
    "snr_release_pairwise_statistics.csv"));
writetable(pooled, fullfile(outputFolder, ...
    "snr_release_pooled_statistics.csv"));
writetable(seedAudit, fullfile(outputFolder, ...
    "snr_release_seed_audit.csv"));
writetable(paperComparison, fullfile(outputFolder, ...
    "snr_release_paper_comparison.csv"));
save(fullfile(outputFolder, "snr_release_experiment.mat"), ...
    "cfg", "snrValues", "fusionCarriers", "bootstrapCarrierCount", ...
    "bootstrapCount", "frontOffsetsDeg", "batchSize", ...
    "numCalibrationPerSnr", "calibration", "baseTypes", ...
    "snrSources", "thresholdValuesDb", "slopeValuesDb", ...
    "calibrationScores", "selectedRule", "numValidationPerSnr", ...
    "validation", "details", "summary", "pairwise", "pooled", ...
    "seedAudit", "paperComparison");
plotResults(summary, paperComparison, fullfile(outputFolder, ...
    "snr_release_validation.png"));

disp(selectedRule);
disp(summary);
disp(pairwise);
disp(pooled);
disp(seedAudit(1:min(20, height(seedAudit)), :));
disp(paperComparison);
end

function trials = runTrials(cfg, scan, snrValues, numPerSnr, ...
    fusionCarriers, frontOffsetsDeg, bootstrapCarrierCount, ...
    bootstrapCount, seedBase, batchSize, useBootstrap, checkpointFile)
numRows = numel(snrValues) * numPerSnr;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    trials = checkpoint.trials;
    completedRows = checkpoint.completedRows;
else
    trials = initializeTrials(snrValues, numPerSnr);
    completedRows = 0;
end
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    numBatchRows = numel(rows);
    snrBatch = trials.snrDb(rows);
    frontAngleErrorDeg = zeros(numBatchRows, 1);
    frontRangeErrorM = zeros(numBatchRows, 1);
    musicAngleErrorDeg = zeros(numBatchRows, 1);
    musicRangeErrorM = zeros(numBatchRows, 1);
    rawAlpha = zeros(numBatchRows, 1);
    conservativeAlpha = zeros(numBatchRows, 1);
    independentAlpha = zeros(numBatchRows, 1);
    frontSnrDb = zeros(numBatchRows, 1);
    snapshotSnrDb = zeros(numBatchRows, 1);
    parfor batchIndex = 1:numBatchRows
        row = rows(batchIndex);
        result = simulateTrial(cfg, scan, snrBatch(batchIndex), ...
            fusionCarriers, frontOffsetsDeg, bootstrapCarrierCount, ...
            bootstrapCount, useBootstrap, seedBase + row, ...
            seedBase + 100000 + row);
        frontAngleErrorDeg(batchIndex) = result.frontAngleErrorDeg;
        frontRangeErrorM(batchIndex) = result.frontRangeErrorM;
        musicAngleErrorDeg(batchIndex) = result.musicAngleErrorDeg;
        musicRangeErrorM(batchIndex) = result.musicRangeErrorM;
        rawAlpha(batchIndex) = result.rawAlpha;
        conservativeAlpha(batchIndex) = result.conservativeAlpha;
        independentAlpha(batchIndex) = result.independentAlpha;
        frontSnrDb(batchIndex) = result.frontSnrDb;
        snapshotSnrDb(batchIndex) = result.snapshotSnrDb;
    end
    trials.frontAngleErrorDeg(rows) = frontAngleErrorDeg;
    trials.frontRangeErrorM(rows) = frontRangeErrorM;
    trials.musicAngleErrorDeg(rows) = musicAngleErrorDeg;
    trials.musicRangeErrorM(rows) = musicRangeErrorM;
    trials.rawAlpha(rows) = rawAlpha;
    trials.conservativeAlpha(rows) = conservativeAlpha;
    trials.independentAlpha(rows) = independentAlpha;
    trials.frontSnrDb(rows) = frontSnrDb;
    trials.snapshotSnrDb(rows) = snapshotSnrDb;
    completedRows = rows(end);
    save(checkpointFile, "trials", "completedRows");
    fprintf("Large MC rows %d/%d complete.\n", completedRows, numRows);
end
end

function result = simulateTrial(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, bootstrapCarrierCount, bootstrapCount, ...
    useBootstrap, baseSeed, bootstrapSeed)
truthThetaDeg = 15;
truthRangeM = 30;
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
noiseVariance = signalPower / 10^(snrDb / 10);
stream = RandStream("mt19937ar", Seed=baseSeed);
beta = exp(1i * 2 * pi * rand(stream));
noise = sqrt(noiseVariance / 2) * (randn(stream, ...
    cfg.numSubcarriers, 1) + 1i * randn(stream, ...
    cfg.numSubcarriers, 1));
observation = beta * truthResponse + noise;
[~, peakPosition] = max(abs(observation).^2);
carrierIndex = fixedCountWindow(peakPosition - 1, fusionCarriers, ...
    cfg.numSubcarriers);
front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
    frontOffsetsDeg);
snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, truthRangeM, ...
    snrDb, carrierIndex, stream);
music = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);
if useBootstrap
    bootstrapStream = RandStream("mt19937ar", Seed=bootstrapSeed);
    diagnostics = fsjad.parametricBootstrapShrinkage(cfg, observation, ...
        snapshots, carrierIndex, front, music, scan, bootstrapCount, ...
        bootstrapCarrierCount, bootstrapStream);
    rawAlpha = diagnostics.rawAlpha;
    conservativeAlpha = diagnostics.conservativeAlpha;
    independentAlpha = diagnostics.independentAlpha;
else
    diagnostics = fsjad.fittedSnrDiagnostics(cfg, observation, ...
        snapshots, carrierIndex, front, music, scan);
    rawAlpha = 0;
    conservativeAlpha = 0;
    independentAlpha = 0;
end
result.frontAngleErrorDeg = front.thetaDeg - truthThetaDeg;
result.frontRangeErrorM = front.rangeM - truthRangeM;
result.musicAngleErrorDeg = music.thetaDeg - truthThetaDeg;
result.musicRangeErrorM = music.rangeM - truthRangeM;
result.rawAlpha = rawAlpha;
result.conservativeAlpha = conservativeAlpha;
result.independentAlpha = independentAlpha;
result.frontSnrDb = diagnostics.frontSnrDb;
result.snapshotSnrDb = diagnostics.snapshotSnrDb;
end

function trials = initializeTrials(snrValues, numPerSnr)
trials.snrDb = repelem(snrValues, numPerSnr);
numRows = numel(trials.snrDb);
trials.frontAngleErrorDeg = zeros(numRows, 1);
trials.frontRangeErrorM = zeros(numRows, 1);
trials.musicAngleErrorDeg = zeros(numRows, 1);
trials.musicRangeErrorM = zeros(numRows, 1);
trials.rawAlpha = zeros(numRows, 1);
trials.conservativeAlpha = zeros(numRows, 1);
trials.independentAlpha = zeros(numRows, 1);
trials.frontSnrDb = zeros(numRows, 1);
trials.snapshotSnrDb = zeros(numRows, 1);
end

function [scores, selected] = calibrateReleaseRule(trials, snrValues, ...
    baseTypes, snrSources, thresholdValuesDb, slopeValuesDb)
numRows = numel(baseTypes) * numel(snrSources) ...
    * numel(thresholdValuesDb) * numel(slopeValuesDb);
baseType = strings(numRows, 1);
snrSource = strings(numRows, 1);
thresholdDb = zeros(numRows, 1);
slopeDb = zeros(numRows, 1);
meanRelativeMseToBestEndpoint = zeros(numRows, 1);
maximumRelativeMseToBestEndpoint = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1);
relativeMseBySnr = zeros(numRows, numel(snrValues));
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
row = 0;
for baseIndex = 1:numel(baseTypes)
    baseAlpha = baseAlphaForType(trials, baseTypes(baseIndex));
    for sourceIndex = 1:numel(snrSources)
        snrEstimate = snrForSource(trials, snrSources(sourceIndex));
        for thresholdIndex = 1:numel(thresholdValuesDb)
            for slopeIndex = 1:numel(slopeValuesDb)
                row = row + 1;
                alpha = releasedAlpha(baseAlpha, snrEstimate, ...
                    thresholdValuesDb(thresholdIndex), ...
                    slopeValuesDb(slopeIndex));
                for snrIndex = 1:numel(snrValues)
                    rows = trials.snrDb == snrValues(snrIndex);
                    fusedError = trials.frontRangeErrorM(rows) ...
                        + alpha(rows) .* delta(rows);
                    bestEndpointMse = min( ...
                        mean(trials.frontRangeErrorM(rows).^2), ...
                        mean(trials.musicRangeErrorM(rows).^2));
                    relativeMseBySnr(row, snrIndex) = ...
                        mean(fusedError.^2) / bestEndpointMse;
                end
                baseType(row) = baseTypes(baseIndex);
                snrSource(row) = snrSources(sourceIndex);
                thresholdDb(row) = thresholdValuesDb(thresholdIndex);
                slopeDb(row) = slopeValuesDb(slopeIndex);
                meanRelativeMseToBestEndpoint(row) = ...
                    mean(relativeMseBySnr(row, :));
                maximumRelativeMseToBestEndpoint(row) = ...
                    max(relativeMseBySnr(row, :));
                meanAlpha(row) = mean(alpha);
            end
        end
    end
end
scores = table(baseType, snrSource, thresholdDb, slopeDb, ...
    meanRelativeMseToBestEndpoint, maximumRelativeMseToBestEndpoint, ...
    meanAlpha);
for snrIndex = 1:numel(snrValues)
    scores.("relativeMseSnr" + string(snrIndex)) = ...
        relativeMseBySnr(:, snrIndex);
end
ranking = sortrows(scores, ...
    ["maximumRelativeMseToBestEndpoint", ...
    "meanRelativeMseToBestEndpoint", "meanAlpha"], ...
    ["ascend", "ascend", "ascend"]);
selected = ranking(1, :);
end

function alpha = baseAlphaForType(trials, baseType)
if baseType == "zero"
    alpha = zeros(size(trials.rawAlpha));
elseif baseType == "raw"
    alpha = trials.rawAlpha;
elseif baseType == "conservative"
    alpha = trials.conservativeAlpha;
else
    error("fsjad:UnknownReleaseBase", "Unknown release base alpha.");
end
end

function snrEstimate = snrForSource(trials, source)
if source == "front"
    snrEstimate = trials.frontSnrDb;
elseif source == "snapshot"
    snrEstimate = trials.snapshotSnrDb;
elseif source == "mean"
    snrEstimate = (trials.frontSnrDb + trials.snapshotSnrDb) / 2;
else
    error("fsjad:UnknownSnrSource", "Unknown SNR estimate source.");
end
end

function alpha = releasedAlpha(baseAlpha, snrEstimateDb, ...
    thresholdDb, slopeDb)
release = 1 ./ (1 + exp((snrEstimateDb - thresholdDb) / slopeDb));
alpha = baseAlpha + (1 - baseAlpha) .* release;
alpha = min(max(alpha, 0), 1);
end

function [details, summary, pairwise, pooled, seedAudit] = ...
    summarizeValidation(trials, selectedRule, snrValues, seedBase)
baseAlpha = baseAlphaForType(trials, selectedRule.baseType);
snrEstimate = snrForSource(trials, selectedRule.snrSource);
selectedAlpha = releasedAlpha(baseAlpha, snrEstimate, ...
    selectedRule.thresholdDb, selectedRule.slopeDb);
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
oracleAlpha = fsjad.oracleRangeShrinkage(trials.frontRangeErrorM, delta);
methodNames = ["Full-spectrum front"; "Zhang-style full MUSIC"; ...
    "Bootstrap raw"; "Bootstrap conservative"; ...
    "Bootstrap independent"; "Selected SNR release"; ...
    "Oracle shrinkage"];
alphaMatrix = [zeros(size(delta)).'; ones(size(delta)).'; ...
    trials.rawAlpha.'; trials.conservativeAlpha.'; ...
    trials.independentAlpha.'; selectedAlpha.'; oracleAlpha.'];
errorMatrix = trials.frontRangeErrorM.' + alphaMatrix .* delta.';
angleMatrix = [trials.frontAngleErrorDeg.'; repmat( ...
    trials.musicAngleErrorDeg.', numel(methodNames) - 1, 1)];
numTrials = numel(delta);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(trials.snrDb, numel(methodNames));
details = table(method, snrDb, angleMatrix(:), errorMatrix(:), ...
    alphaMatrix(:), VariableNames=["method", "snrDb", ...
    "angleErrorDeg", "rangeErrorM", "alpha"]);
summary = groupMetrics(details, methodNames, snrValues);
[pairwise, pooled] = compareSelected(details, snrValues);
seedAudit = favorableSeedAudit(trials, selectedAlpha, seedBase);
end

function summary = groupMetrics(details, methodNames, snrValues)
numRows = numel(methodNames) * numel(snrValues);
method = strings(numRows, 1);
snrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1);
row = 0;
for methodIndex = 1:numel(methodNames)
    for snrIndex = 1:numel(snrValues)
        row = row + 1;
        rows = details.method == methodNames(methodIndex) ...
            & details.snrDb == snrValues(snrIndex);
        method(row) = methodNames(methodIndex);
        snrDb(row) = snrValues(snrIndex);
        angleRmseDeg(row) = sqrt(mean(details.angleErrorDeg(rows).^2));
        rangeRmseM(row) = sqrt(mean(details.rangeErrorM(rows).^2));
        meanAlpha(row) = mean(details.alpha(rows));
    end
end
summary = table(method, snrDb, angleRmseDeg, rangeRmseM, meanAlpha);
end

function [statistics, pooled] = compareSelected(details, snrValues)
methodName = "Selected SNR release";
referenceNames = ["Full-spectrum front"; "Zhang-style full MUSIC"];
numRows = numel(referenceNames) * numel(snrValues);
method = repmat(methodName, numRows, 1);
reference = strings(numRows, 1);
snrDb = zeros(numRows, 1);
mseChange = zeros(numRows, 1);
ci95LowerMseChange = zeros(numRows, 1);
ci95UpperMseChange = zeros(numRows, 1);
row = 0;
for referenceIndex = 1:numel(referenceNames)
    for snrIndex = 1:numel(snrValues)
        row = row + 1;
        methodRows = details.method == methodName ...
            & details.snrDb == snrValues(snrIndex);
        referenceRows = details.method == referenceNames(referenceIndex) ...
            & details.snrDb == snrValues(snrIndex);
        [change, lower, upper] = pairedMseInterval( ...
            details.rangeErrorM(methodRows), ...
            details.rangeErrorM(referenceRows));
        reference(row) = referenceNames(referenceIndex);
        snrDb(row) = snrValues(snrIndex);
        mseChange(row) = change;
        ci95LowerMseChange(row) = lower;
        ci95UpperMseChange(row) = upper;
    end
end
statistics = table(method, reference, snrDb, mseChange, ...
    ci95LowerMseChange, ci95UpperMseChange);

method = repmat(methodName, numel(referenceNames), 1);
reference = referenceNames;
mseChange = zeros(numel(referenceNames), 1);
ci95LowerMseChange = zeros(numel(referenceNames), 1);
ci95UpperMseChange = zeros(numel(referenceNames), 1);
for referenceIndex = 1:numel(referenceNames)
    methodError = details.rangeErrorM(details.method == methodName);
    referenceError = details.rangeErrorM( ...
        details.method == referenceNames(referenceIndex));
    [change, lower, upper] = pairedMseInterval( ...
        methodError, referenceError);
    mseChange(referenceIndex) = change;
    ci95LowerMseChange(referenceIndex) = lower;
    ci95UpperMseChange(referenceIndex) = upper;
end
pooled = table(method, reference, mseChange, ...
    ci95LowerMseChange, ci95UpperMseChange);
end

function [change, lower, upper] = pairedMseInterval( ...
    methodError, referenceError)
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
standardError = std(squaredChange) / sqrt(numel(squaredChange));
lower = change - 1.96 * standardError;
upper = change + 1.96 * standardError;
end

function audit = favorableSeedAudit(trials, alpha, seedBase)
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
fusedErrorM = trials.frontRangeErrorM + alpha .* delta;
gainMse = min(trials.frontRangeErrorM.^2, ...
    trials.musicRangeErrorM.^2) - fusedErrorM.^2;
[~, order] = sort(gainMse, "descend");
topCount = min(100, numel(order));
rows = order(1:topCount);
row = rows;
snrDb = trials.snrDb(rows);
baseSeed = seedBase + rows;
bootstrapSeed = seedBase + 100000 + rows;
frontErrorM = trials.frontRangeErrorM(rows);
musicErrorM = trials.musicRangeErrorM(rows);
selectedErrorM = fusedErrorM(rows);
selectedAlpha = alpha(rows);
gainMse = gainMse(rows);
audit = table(row, snrDb, baseSeed, bootstrapSeed, frontErrorM, ...
    musicErrorM, selectedErrorM, selectedAlpha, gainMse);
end

function comparison = compareWithPublished(summary, snrValues)
rows = summary.method == "Selected SNR release";
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

function plotResults(summary, comparison, outputFile)
figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
methodNames = unique(summary.method, "stable");
axisHandle = nexttile;
axisHandle.YScale = "log";
hold(axisHandle, "on");
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.rangeRmseM(rows), ...
        "-o", LineWidth=1.1, MarkerSize=4);
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
        "-o", LineWidth=1.1, MarkerSize=4);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Mean alpha");
ylim(axisHandle, [0, 1]);
legend(axisHandle, methodNames(3:end), Location="best");
title(layout, "Large-MC SNR-released shrinkage validation");
exportgraphics(figureHandle, outputFile, Resolution=180);
close(figureHandle);
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end
