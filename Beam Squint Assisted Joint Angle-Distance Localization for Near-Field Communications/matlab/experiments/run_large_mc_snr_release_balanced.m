function run_large_mc_snr_release_balanced
%RUN_LARGE_MC_SNR_RELEASE_BALANCED Sequential balanced large-MC validation.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round12");
calibrationFile = fullfile(outputFolder, "snr_release_calibration.mat");
calibrated = load(calibrationFile, "cfg", "snrValues", ...
    "fusionCarriers", "frontOffsetsDeg", "selectedRule");
cfg = calibrated.cfg;
snrValues = calibrated.snrValues;
scan = fsjad.prepareScan(cfg);
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Balanced validation uses %d workers.\n", pool.NumWorkers);

originalFile = fullfile(outputFolder, ...
    "snr_release_validation_checkpoint.mat");
original = load(originalFile, "trials", "completedRows");
assert(all(original.trials.snrDb(1:original.completedRows) == -10));
originalCount = original.completedRows;
originalSeedBase = cfg.randomSeed + 5101;
maxPerSnr = 3334;
minimumPerSnr = 500;
relativeHalfWidthTolerance = 0.01;
catchupSnrDb = [repmat(-5, originalCount, 1); ...
    zeros(originalCount, 1)];
remainingPerSnr = maxPerSnr - originalCount;
balancedSnrDb = repmat(snrValues, remainingPerSnr, 1);
supplementSnrDb = [catchupSnrDb; balancedSnrDb];
supplementSeedBase = cfg.randomSeed + 15101;
checkpointFile = fullfile(outputFolder, ...
    "snr_release_balanced_validation_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    supplement = checkpoint.supplement;
    completedRows = checkpoint.completedRows;
    completedSnrDb = [original.trials.snrDb(1:originalCount); ...
        supplement.snrDb(1:completedRows)];
    completedCounts = arrayfun(@(value) sum(completedSnrDb == value), ...
        snrValues);
    equalizedCount = max(completedCounts);
    futureSnrDb = zeros(0, 1);
    for snrIndex = 1:numel(snrValues)
        deficit = equalizedCount - completedCounts(snrIndex);
        futureSnrDb = [futureSnrDb; ...
            repmat(snrValues(snrIndex), deficit, 1)]; %#ok<AGROW>
    end
    futureSnrDb = [futureSnrDb; ...
        repmat(snrValues, maxPerSnr - equalizedCount, 1)];
    assert(numel(futureSnrDb) == numel(supplementSnrDb) - completedRows);
    supplement.snrDb(completedRows + 1:end) = futureSnrDb;
else
    supplement = initializeTrials(supplementSnrDb);
    completedRows = 0;
end

batchSize = 24;
stopDecision = table();
for batchStart = completedRows + 1:batchSize:numel(supplementSnrDb)
    rows = batchStart:min(batchStart + batchSize - 1, ...
        numel(supplementSnrDb));
    batch = runBatch(cfg, scan, supplementSnrDb(rows), ...
        calibrated.fusionCarriers, calibrated.frontOffsetsDeg, ...
        supplementSeedBase + rows);
    supplement = storeBatch(supplement, rows, batch);
    completedRows = rows(end);
    save(checkpointFile, "supplement", "completedRows");
    [combined, counts] = combineTrials(original.trials, originalCount, ...
        originalSeedBase, supplement, completedRows, snrValues);
    if all(counts >= minimumPerSnr)
        [shouldStop, stopDecision] = precisionStop(combined, ...
            calibrated.selectedRule, snrValues, ...
            relativeHalfWidthTolerance);
        writetable(stopDecision, fullfile(outputFolder, ...
            "snr_release_sequential_stop_audit.csv"));
        fprintf("Balanced validation counts [%d %d %d], stop=%d.\n", ...
            counts, shouldStop);
        if shouldStop
            break;
        end
    else
        fprintf("Balanced validation counts [%d %d %d].\n", counts);
    end
end

[combined, counts] = combineTrials(original.trials, originalCount, ...
    originalSeedBase, supplement, completedRows, snrValues);
[details, summary, pairwise, pooled, seedAudit] = summarizeResults( ...
    combined, calibrated.selectedRule, snrValues);
paperComparison = compareWithPublished(summary, snrValues);
writetable(summary, fullfile(outputFolder, ...
    "snr_release_large_validation_summary.csv"));
writetable(pairwise, fullfile(outputFolder, ...
    "snr_release_large_pairwise_statistics.csv"));
writetable(pooled, fullfile(outputFolder, ...
    "snr_release_large_pooled_statistics.csv"));
writetable(seedAudit, fullfile(outputFolder, ...
    "snr_release_large_seed_audit.csv"));
writetable(paperComparison, fullfile(outputFolder, ...
    "snr_release_large_paper_comparison.csv"));
save(fullfile(outputFolder, "snr_release_large_validation.mat"), ...
    "combined", "counts", "details", "summary", "pairwise", ...
    "pooled", "seedAudit", "paperComparison", "stopDecision", ...
    "minimumPerSnr", "maxPerSnr", "relativeHalfWidthTolerance", ...
    "originalCount", "supplementSeedBase");
disp(summary);
disp(pairwise);
disp(pooled);
disp(stopDecision);
end

function trials = initializeTrials(snrDb)
numRows = numel(snrDb);
trials.snrDb = snrDb;
trials.frontAngleErrorDeg = zeros(numRows, 1);
trials.frontRangeErrorM = zeros(numRows, 1);
trials.musicAngleErrorDeg = zeros(numRows, 1);
trials.musicRangeErrorM = zeros(numRows, 1);
trials.rawAlpha = zeros(numRows, 1);
trials.conservativeAlpha = zeros(numRows, 1);
trials.independentAlpha = zeros(numRows, 1);
trials.frontSnrDb = zeros(numRows, 1);
trials.snapshotSnrDb = zeros(numRows, 1);
trials.baseSeed = zeros(numRows, 1);
end

function batch = runBatch(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, seeds)
numRows = numel(snrDb);
batch = initializeTrials(snrDb);
frontAngleErrorDeg = zeros(numRows, 1);
frontRangeErrorM = zeros(numRows, 1);
musicAngleErrorDeg = zeros(numRows, 1);
musicRangeErrorM = zeros(numRows, 1);
frontSnrDb = zeros(numRows, 1);
snapshotSnrDb = zeros(numRows, 1);
parfor row = 1:numRows
    result = fsjad.simulateSnrReleaseTrial(cfg, scan, snrDb(row), ...
        fusionCarriers, frontOffsetsDeg, seeds(row));
    frontAngleErrorDeg(row) = result.frontAngleErrorDeg;
    frontRangeErrorM(row) = result.frontRangeErrorM;
    musicAngleErrorDeg(row) = result.musicAngleErrorDeg;
    musicRangeErrorM(row) = result.musicRangeErrorM;
    frontSnrDb(row) = result.frontSnrDb;
    snapshotSnrDb(row) = result.snapshotSnrDb;
end
batch.frontAngleErrorDeg = frontAngleErrorDeg;
batch.frontRangeErrorM = frontRangeErrorM;
batch.musicAngleErrorDeg = musicAngleErrorDeg;
batch.musicRangeErrorM = musicRangeErrorM;
batch.frontSnrDb = frontSnrDb;
batch.snapshotSnrDb = snapshotSnrDb;
batch.baseSeed = seeds;
end

function trials = storeBatch(trials, rows, batch)
names = ["frontAngleErrorDeg", "frontRangeErrorM", ...
    "musicAngleErrorDeg", "musicRangeErrorM", "frontSnrDb", ...
    "snapshotSnrDb", "baseSeed"];
for name = names
    trials.(name)(rows) = batch.(name);
end
end

function [combined, counts] = combineTrials(original, originalCount, ...
    originalSeedBase, supplement, completedRows, snrValues)
names = ["snrDb", "frontAngleErrorDeg", "frontRangeErrorM", ...
    "musicAngleErrorDeg", "musicRangeErrorM", "rawAlpha", ...
    "conservativeAlpha", "independentAlpha", "frontSnrDb", ...
    "snapshotSnrDb"];
for name = names
    combined.(name) = [original.(name)(1:originalCount); ...
        supplement.(name)(1:completedRows)];
end
combined.baseSeed = [(originalSeedBase + (1:originalCount)).'; ...
    supplement.baseSeed(1:completedRows)];
counts = zeros(size(snrValues));
for snrIndex = 1:numel(snrValues)
    counts(snrIndex) = sum(combined.snrDb == snrValues(snrIndex));
end
end

function [shouldStop, audit] = precisionStop(trials, rule, snrValues, ...
    relativeTolerance)
alpha = computeSelectedAlpha(trials, rule);
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
selectedError = trials.frontRangeErrorM + alpha .* delta;
snrDb = snrValues;
sampleCount = zeros(size(snrValues));
reference = strings(size(snrValues));
mseChange = zeros(size(snrValues));
ci95Lower = zeros(size(snrValues));
ci95Upper = zeros(size(snrValues));
relativeHalfWidth = zeros(size(snrValues));
criterionMet = false(size(snrValues));
for snrIndex = 1:numel(snrValues)
    rows = trials.snrDb == snrValues(snrIndex);
    frontMse = mean(trials.frontRangeErrorM(rows).^2);
    musicMse = mean(trials.musicRangeErrorM(rows).^2);
    if frontMse <= musicMse
        referenceError = trials.frontRangeErrorM(rows);
        reference(snrIndex) = "front";
        referenceMse = frontMse;
    else
        referenceError = trials.musicRangeErrorM(rows);
        reference(snrIndex) = "music";
        referenceMse = musicMse;
    end
    change = selectedError(rows).^2 - referenceError.^2;
    halfWidth = 1.96 * std(change) / sqrt(sum(rows));
    sampleCount(snrIndex) = sum(rows);
    mseChange(snrIndex) = mean(change);
    ci95Lower(snrIndex) = mean(change) - halfWidth;
    ci95Upper(snrIndex) = mean(change) + halfWidth;
    relativeHalfWidth(snrIndex) = halfWidth / referenceMse;
    criterionMet(snrIndex) = ci95Upper(snrIndex) <= 0 ...
        || relativeHalfWidth(snrIndex) <= relativeTolerance;
end
audit = table(snrDb, sampleCount, reference, mseChange, ci95Lower, ...
    ci95Upper, relativeHalfWidth, criterionMet);
shouldStop = all(criterionMet);
end

function alpha = computeSelectedAlpha(trials, rule)
if rule.baseType == "zero"
    baseAlpha = zeros(size(trials.snrDb));
elseif rule.baseType == "raw"
    baseAlpha = trials.rawAlpha;
else
    baseAlpha = trials.conservativeAlpha;
end
if rule.snrSource == "front"
    snrEstimate = trials.frontSnrDb;
elseif rule.snrSource == "snapshot"
    snrEstimate = trials.snapshotSnrDb;
else
    snrEstimate = (trials.frontSnrDb + trials.snapshotSnrDb) / 2;
end
release = 1 ./ (1 + exp((snrEstimate - rule.thresholdDb) ...
    / rule.slopeDb));
alpha = baseAlpha + (1 - baseAlpha) .* release;
end

function [details, summary, pairwise, pooled, seedAudit] = ...
    summarizeResults(trials, rule, snrValues)
alpha = computeSelectedAlpha(trials, rule);
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
oracleAlpha = fsjad.oracleRangeShrinkage(trials.frontRangeErrorM, delta);
methodNames = ["Full-spectrum front"; "Zhang-style full MUSIC"; ...
    "Selected SNR release"; "Oracle shrinkage"];
alphaMatrix = [zeros(size(delta)).'; ones(size(delta)).'; ...
    alpha.'; oracleAlpha.'];
errorMatrix = trials.frontRangeErrorM.' + alphaMatrix .* delta.';
angleMatrix = [trials.frontAngleErrorDeg.'; repmat( ...
    trials.musicAngleErrorDeg.', numel(methodNames) - 1, 1)];
numTrials = numel(delta);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(trials.snrDb, numel(methodNames));
details = table(method, snrDb, angleMatrix(:), errorMatrix(:), ...
    alphaMatrix(:), VariableNames=["method", "snrDb", ...
    "angleErrorDeg", "rangeErrorM", "alpha"]);
summary = metricSummary(details, methodNames, snrValues);
[pairwise, pooled] = pairedSummary(details, snrValues);
gain = min(trials.frontRangeErrorM.^2, trials.musicRangeErrorM.^2) ...
    - (trials.frontRangeErrorM + alpha .* delta).^2;
[~, order] = sort(gain, "descend");
rows = order(1:min(100, numel(order)));
row = rows;
snrDb = trials.snrDb(rows);
frontErrorM = trials.frontRangeErrorM(rows);
musicErrorM = trials.musicRangeErrorM(rows);
selectedErrorM = frontErrorM + alpha(rows) .* ...
    (musicErrorM - frontErrorM);
auditAlpha = alpha(rows);
gainMse = gain(rows);
baseSeed = trials.baseSeed(rows);
seedAudit = table(row, snrDb, baseSeed, frontErrorM, ...
    musicErrorM, selectedErrorM, auditAlpha, gainMse);
end

function summary = metricSummary(details, methods, snrs)
numRows = numel(methods) * numel(snrs);
method = strings(numRows, 1); snrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1); rangeRmseM = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1); row = 0;
for mi = 1:numel(methods)
    for si = 1:numel(snrs)
        row = row + 1;
        q = details.method == methods(mi) & details.snrDb == snrs(si);
        method(row) = methods(mi); snrDb(row) = snrs(si);
        angleRmseDeg(row) = sqrt(mean(details.angleErrorDeg(q).^2));
        rangeRmseM(row) = sqrt(mean(details.rangeErrorM(q).^2));
        meanAlpha(row) = mean(details.alpha(q));
    end
end
summary = table(method, snrDb, angleRmseDeg, rangeRmseM, meanAlpha);
end

function [statistics, pooled] = pairedSummary(details, snrs)
methodName = "Selected SNR release";
refs = ["Full-spectrum front"; "Zhang-style full MUSIC"];
method = repmat(methodName, numel(refs) * numel(snrs), 1);
reference = strings(size(method)); snrDb = zeros(size(method));
mseChange = zeros(size(method)); ci95Lower = zeros(size(method));
ci95Upper = zeros(size(method)); row = 0;
for ri = 1:numel(refs)
    for si = 1:numel(snrs)
        row = row + 1;
        a = details.rangeErrorM(details.method == methodName ...
            & details.snrDb == snrs(si));
        b = details.rangeErrorM(details.method == refs(ri) ...
            & details.snrDb == snrs(si));
        [mseChange(row), ci95Lower(row), ci95Upper(row)] = interval(a, b);
        reference(row) = refs(ri); snrDb(row) = snrs(si);
    end
end
statistics = table(method, reference, snrDb, mseChange, ...
    ci95Lower, ci95Upper);
method = repmat(methodName, numel(refs), 1); reference = refs;
mseChange = zeros(numel(refs), 1); ci95Lower = mseChange;
ci95Upper = mseChange;
for ri = 1:numel(refs)
    a = details.rangeErrorM(details.method == methodName);
    b = details.rangeErrorM(details.method == refs(ri));
    [mseChange(ri), ci95Lower(ri), ci95Upper(ri)] = interval(a, b);
end
pooled = table(method, reference, mseChange, ci95Lower, ci95Upper);
end

function [change, lower, upper] = interval(a, b)
z = a.^2 - b.^2; change = mean(z);
halfWidth = 1.96 * std(z) / sqrt(numel(z));
lower = change - halfWidth; upper = change + halfWidth;
end

function comparison = compareWithPublished(summary, snrs)
q = summary.method == "Selected SNR release";
snrDb = summary.snrDb(q); assert(isequal(snrDb, snrs));
analyticAngleRmseDeg = summary.angleRmseDeg(q);
analyticRangeRmseM = summary.rangeRmseM(q);
publishedAngleRmseDeg = [0.10222305; 0.026220697; 0.0077105099];
publishedRangeRmseM = [0.099998239; 0.039411058; 0.015372596];
angleRatioToPublished = analyticAngleRmseDeg ./ publishedAngleRmseDeg;
rangeRatioToPublished = analyticRangeRmseM ./ publishedRangeRmseM;
comparison = table(snrDb, analyticAngleRmseDeg, ...
    publishedAngleRmseDeg, angleRatioToPublished, analyticRangeRmseM, ...
    publishedRangeRmseM, rangeRatioToPublished);
end
