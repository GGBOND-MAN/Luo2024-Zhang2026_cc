function run_round19_random_miss_fallback_complexity
%RUN_ROUND19_RANDOM_MISS_FALLBACK_COMPLEXITY Audit low-SNR misses and cost.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round19");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 19 uses %d workers.\n", pool.NumWorkers);

cfg = configuredZhangBaseline();
scan = fsjad.prepareScan(cfg);
angleLimitsDeg = [-55, 55];
rangeLimitsM = [17, 48];
snrValuesDb = [-10; 0; 20];
numCalibration = 100;
numValidationPerSnr = 100;
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
profileLambda = 0.9;
localHalfWidthsM = [1; 2];
localSpacingM = 0.1;
globalSpacingM = 0.25;
poolShiftThresholdM = 0.5;
poolDisagreementThresholdM = 0.05;

calibrationDesign = randomDesign(numCalibration, -10, 21900000, ...
    angleLimitsDeg, rangeLimitsM);
calibration = runDataset(cfg, scan, calibrationDesign, ...
    fusionCarriers, frontOffsetsDeg, localHalfWidthsM, localSpacingM, ...
    globalSpacingM, poolShiftThresholdM, ...
    poolDisagreementThresholdM, table(), outputFolder, "calibration");
[selected, detectorScreen] = calibrateRule(calibration, profileLambda);

validationDesign = table();
for snrIndex = 1:numel(snrValuesDb)
    block = randomDesign(numValidationPerSnr, snrValuesDb(snrIndex), ...
        22000000 + 100000 * snrIndex, angleLimitsDeg, rangeLimitsM);
    validationDesign = [validationDesign; block]; %#ok<AGROW>
end
validation = runDataset(cfg, scan, validationDesign, ...
    fusionCarriers, frontOffsetsDeg, localHalfWidthsM, localSpacingM, ...
    globalSpacingM, poolShiftThresholdM, ...
    poolDisagreementThresholdM, selected, outputFolder, "validation");

[methodSummary, pairedSummary, detectorSummary, tailSummary, ...
    complexitySummary, seedAudit] = summarizeValidation( ...
    validation, selected, profileLambda, snrValuesDb, cfg, ...
    fusionCarriers);
protocol = table(angleLimitsDeg(1), angleLimitsDeg(2), ...
    rangeLimitsM(1), rangeLimitsM(2), numCalibration, ...
    numValidationPerSnr, localHalfWidthsM(1), localHalfWidthsM(2), ...
    localSpacingM, globalSpacingM, fusionCarriers);
protocol.Properties.VariableNames = ["angleMinDeg", "angleMaxDeg", ...
    "rangeMinM", "rangeMaxM", "calibrationCount", ...
    "validationCountPerSnr", "localHalfWidth1M", ...
    "localHalfWidth2M", "localSpacingM", "globalSpacingM", ...
    "fusionCarrierCount"];

writetable(protocol, fullfile(outputFolder, "random_protocol.csv"));
writetable(calibrationDesign, fullfile(outputFolder, ...
    "calibration_design.csv"));
writetable(validationDesign, fullfile(outputFolder, ...
    "validation_design.csv"));
writetable(struct2table(calibration), fullfile(outputFolder, ...
    "calibration_details.csv"));
writetable(detectorScreen, fullfile(outputFolder, ...
    "detector_calibration_screen.csv"));
writetable(selected, fullfile(outputFolder, ...
    "selected_detector.csv"));
writetable(struct2table(validation), fullfile(outputFolder, ...
    "validation_details.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "method_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, ...
    "paired_summary.csv"));
writetable(detectorSummary, fullfile(outputFolder, ...
    "detector_summary.csv"));
writetable(tailSummary, fullfile(outputFolder, "tail_summary.csv"));
writetable(complexitySummary, fullfile(outputFolder, ...
    "complexity_summary.csv"));
writetable(seedAudit, fullfile(outputFolder, "seed_audit.csv"));
save(fullfile(outputFolder, "random_miss_fallback_complexity.mat"), ...
    "cfg", "calibrationDesign", "calibration", "selected", ...
    "detectorScreen", "validationDesign", "validation", ...
    "methodSummary", "pairedSummary", "detectorSummary", ...
    "tailSummary", "complexitySummary", "seedAudit", "protocol");
plotResults(methodSummary, detectorSummary, fullfile(outputFolder, ...
    "random_miss_fallback_complexity.png"));

disp(selected);
disp(methodSummary);
disp(pairedSummary);
disp(detectorSummary);
disp(tailSummary);
disp(complexitySummary);
disp(seedAudit);
end

function cfg = configuredZhangBaseline
cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
end

function design = randomDesign(count, snrDbValue, seedBase, ...
    angleLimitsDeg, rangeLimitsM)
stream = RandStream("mt19937ar", Seed=seedBase);
truthThetaDeg = angleLimitsDeg(1) + diff(angleLimitsDeg) ...
    * rand(stream, count, 1);
truthRangeM = rangeLimitsM(1) + diff(rangeLimitsM) ...
    * rand(stream, count, 1);
snrDb = repmat(snrDbValue, count, 1);
seed = seedBase + (1:count).';
design = table(seed, truthThetaDeg, truthRangeM, snrDb);
end

function trials = runDataset(cfg, scan, design, fusionCarriers, ...
    frontOffsetsDeg, localWidthsM, localSpacingM, globalSpacingM, ...
    poolShiftThresholdM, poolDisagreementThresholdM, selected, ...
    outputFolder, label)
checkpointFile = fullfile(outputFolder, label + "_checkpoint.mat");
numRows = height(design);
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.design, design), ...
        "fsjad:Round19CheckpointDesignMismatch");
    trials = checkpoint.trials;
    completedRows = checkpoint.completedRows;
else
    trials = initializeTrials(numRows);
    completedRows = 0;
end
batchSize = 10;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        batch{batchIndex} = simulateTrial(cfg, scan, design(row, :), ...
            fusionCarriers, frontOffsetsDeg, localWidthsM, ...
            localSpacingM, globalSpacingM, poolShiftThresholdM, ...
            poolDisagreementThresholdM, selected);
    end
    trials = insertBatch(trials, batch, rows);
    completedRows = rows(end);
    save(checkpointFile, "trials", "completedRows", "design", ...
        "fusionCarriers", "frontOffsetsDeg", "localWidthsM", ...
        "localSpacingM", "globalSpacingM", ...
        "poolShiftThresholdM", "poolDisagreementThresholdM", ...
        "selected", "cfg");
    fprintf("Round 19 %s rows %d/%d complete.\n", ...
        label, completedRows, numRows);
end
end

function result = simulateTrial(cfg, scan, designRow, fusionCarriers, ...
    frontOffsetsDeg, localWidthsM, localSpacingM, globalSpacingM, ...
    poolShiftThresholdM, poolDisagreementThresholdM, selected)
truthThetaDeg = designRow.truthThetaDeg;
truthRangeM = designRow.truthRangeM;
snrDb = designRow.snrDb;
seed = designRow.seed;
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
stream = RandStream("mt19937ar", Seed=seed);
noiseVariance = signalPower / 10^(snrDb / 10);
beta = exp(1i * 2 * pi * rand(stream));
noise = sqrt(noiseVariance / 2) * (randn(stream, ...
    cfg.numSubcarriers, 1) + 1i * randn(stream, ...
    cfg.numSubcarriers, 1));
observation = beta * truthResponse + noise;
[~, peakPosition] = max(abs(observation).^2);
carrierIndex = fixedCountWindow(peakPosition - 1, fusionCarriers, ...
    cfg.numSubcarriers);

timer = tic;
front = fsjad.angleMultistartProfileEstimate( ...
    cfg, observation, scan, frontOffsetsDeg);
frontRuntimeMs = 1000 * toc(timer);
snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, truthRangeM, ...
    snrDb, carrierIndex, stream);
timer = tic;
joint = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);
musicRuntimeMs = 1000 * toc(timer);

profiles = cell(numel(localWidthsM), 1);
profileRuntimeMs = zeros(numel(localWidthsM), 1);
for widthIndex = 1:numel(localWidthsM)
    seedsM = localRangeSeeds(cfg, front.rangeM, ...
        localWidthsM(widthIndex), localSpacingM);
    timer = tic;
    profiles{widthIndex} = fsjad.profileRangeAtAngle( ...
        cfg, observation, joint.thetaDeg, scan, seedsM);
    profileRuntimeMs(widthIndex) = 1000 * toc(timer);
end
localShiftM = abs(profiles{1}.rangeM - front.rangeM);
localDisagreementM = abs(profiles{2}.rangeM - profiles{1}.rangeM);
localBoundary = isProfileBoundary(profiles{1}.rangeM, ...
    profiles{1}.rangeSeedsM, localSpacingM);

if isempty(selected)
    trigger = localBoundary || localShiftM >= poolShiftThresholdM ...
        || localDisagreementM >= poolDisagreementThresholdM;
else
    trigger = applyRule(localShiftM, localDisagreementM, ...
        localBoundary, selected);
end
globalEstimate = struct("rangeM", NaN, "score", NaN, ...
    "responseEvaluations", 0);
globalRuntimeMs = 0;
if trigger
    globalSeedsM = globalRangeSeeds(cfg, globalSpacingM);
    timer = tic;
    globalEstimate = fsjad.profileRangeAtAngle(cfg, observation, ...
        joint.thetaDeg, scan, globalSeedsM);
    globalRuntimeMs = 1000 * toc(timer);
end

result.seed = seed;
result.truthThetaDeg = truthThetaDeg;
result.truthRangeM = truthRangeM;
result.snrDb = snrDb;
result.frontThetaDeg = front.thetaDeg;
result.frontRangeM = front.rangeM;
result.jointThetaDeg = joint.thetaDeg;
result.jointRangeM = joint.rangeM;
result.profile1RangeM = profiles{1}.rangeM;
result.profile2RangeM = profiles{2}.rangeM;
result.globalRangeM = globalEstimate.rangeM;
result.frontScore = front.score;
result.frontScoreGap = front.scoreGap;
result.frontConverged = front.converged;
result.localShiftM = localShiftM;
result.localDisagreementM = localDisagreementM;
result.localBoundary = localBoundary;
result.globalEvaluated = trigger;
result.frontResponseEvaluations = front.totalResponseEvaluations;
result.profile1ResponseEvaluations = profiles{1}.responseEvaluations;
result.profile2ResponseEvaluations = profiles{2}.responseEvaluations;
result.globalResponseEvaluations = globalEstimate.responseEvaluations;
result.frontRuntimeMs = frontRuntimeMs;
result.musicRuntimeMs = musicRuntimeMs;
result.profile1RuntimeMs = profileRuntimeMs(1);
result.profile2RuntimeMs = profileRuntimeMs(2);
result.globalRuntimeMs = globalRuntimeMs;
end

function trials = initializeTrials(count)
numericFields = ["seed", "truthThetaDeg", "truthRangeM", "snrDb", ...
    "frontThetaDeg", "frontRangeM", "jointThetaDeg", "jointRangeM", ...
    "profile1RangeM", "profile2RangeM", "globalRangeM", ...
    "frontScore", "frontScoreGap", "localShiftM", ...
    "localDisagreementM", "frontResponseEvaluations", ...
    "profile1ResponseEvaluations", "profile2ResponseEvaluations", ...
    "globalResponseEvaluations", "frontRuntimeMs", "musicRuntimeMs", ...
    "profile1RuntimeMs", "profile2RuntimeMs", "globalRuntimeMs"];
trials = struct();
for field = numericFields
    trials.(field) = nan(count, 1);
end
trials.frontConverged = false(count, 1);
trials.localBoundary = false(count, 1);
trials.globalEvaluated = false(count, 1);
end

function trials = insertBatch(trials, batch, rows)
fields = string(fieldnames(trials));
for batchIndex = 1:numel(batch)
    row = rows(batchIndex);
    for field = fields.'
        trials.(field)(row) = batch{batchIndex}.(field);
    end
end
end

function [selected, screen] = calibrateRule(trials, profileLambda)
shiftThresholdsM = (0.5:0.05:0.95).';
disagreementThresholdsM = [0.05; 0.1; 0.2; Inf];
fallbackLambdas = [0.75; 0.9; 1];
numRows = numel(shiftThresholdsM) * numel(disagreementThresholdsM) ...
    * numel(fallbackLambdas);
shiftThresholdM = zeros(numRows, 1);
disagreementThresholdM = zeros(numRows, 1);
fallbackLambda = zeros(numRows, 1);
fallbackRate = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
coarseMissRecall = zeros(numRows, 1);
coarseMissFalseAlarmRate = zeros(numRows, 1);
fixedRangeM = trials.frontRangeM + profileLambda ...
    * (trials.profile1RangeM - trials.frontRangeM);
coarseMiss = abs(trials.frontRangeM - trials.truthRangeM) > 1;
row = 0;
for shiftIndex = 1:numel(shiftThresholdsM)
    for disagreementIndex = 1:numel(disagreementThresholdsM)
        trigger = trials.localBoundary ...
            | trials.localShiftM >= shiftThresholdsM(shiftIndex) ...
            | trials.localDisagreementM ...
            >= disagreementThresholdsM(disagreementIndex);
        assert(all(~trigger | trials.globalEvaluated), ...
            "fsjad:Round19MissingCalibrationFallback");
        for lambdaIndex = 1:numel(fallbackLambdas)
            row = row + 1;
            estimateM = fixedRangeM;
            estimateM(trigger) = trials.frontRangeM(trigger) ...
                + fallbackLambdas(lambdaIndex) ...
                * (trials.globalRangeM(trigger) ...
                - trials.frontRangeM(trigger));
            shiftThresholdM(row) = shiftThresholdsM(shiftIndex);
            disagreementThresholdM(row) = ...
                disagreementThresholdsM(disagreementIndex);
            fallbackLambda(row) = fallbackLambdas(lambdaIndex);
            fallbackRate(row) = mean(trigger);
            rangeRmseM(row) = rms(estimateM - trials.truthRangeM);
            coarseMissRecall(row) = conditionalMean(trigger, coarseMiss);
            coarseMissFalseAlarmRate(row) = ...
                conditionalMean(trigger, ~coarseMiss);
        end
    end
end
screen = table(shiftThresholdM, disagreementThresholdM, ...
    fallbackLambda, fallbackRate, rangeRmseM, coarseMissRecall, ...
    coarseMissFalseAlarmRate);
if any(coarseMiss)
    [~, order] = sortrows([screen.rangeRmseM, screen.fallbackRate], ...
        [1, 2]);
    selected = screen(order(1), :);
    selected.identified = true;
else
    placeholder = screen.shiftThresholdM == max(shiftThresholdsM) ...
        & isinf(screen.disagreementThresholdM) ...
        & screen.fallbackLambda == 0.9;
    selected = screen(find(placeholder, 1), :);
    selected.identified = false;
end
selected.calibrationCoarseMissCount = sum(coarseMiss);
end

function value = conditionalMean(event, condition)
if any(condition)
    value = mean(event(condition));
else
    value = NaN;
end
end

function trigger = applyRule(shiftM, disagreementM, boundary, selected)
trigger = boundary || shiftM >= selected.shiftThresholdM ...
    || disagreementM >= selected.disagreementThresholdM;
end

function [methodSummary, pairedSummary, detectorSummary, tailSummary, ...
    complexitySummary, seedAudit] = summarizeValidation( ...
    trials, selected, profileLambda, snrValuesDb, cfg, fusionCarriers)
frontErrorM = trials.frontRangeM - trials.truthRangeM;
zhangErrorM = trials.jointRangeM - trials.truthRangeM;
fixedRangeM = trials.frontRangeM + profileLambda ...
    * (trials.profile1RangeM - trials.frontRangeM);
fixedErrorM = fixedRangeM - trials.truthRangeM;
trigger = trials.globalEvaluated;
fallbackRangeM = fixedRangeM;
fallbackRangeM(trigger) = trials.frontRangeM(trigger) ...
    + selected.fallbackLambda ...
    * (trials.globalRangeM(trigger) - trials.frontRangeM(trigger));
fallbackErrorM = fallbackRangeM - trials.truthRangeM;
frontAngleErrorDeg = trials.frontThetaDeg - trials.truthThetaDeg;
jointAngleErrorDeg = trials.jointThetaDeg - trials.truthThetaDeg;

methodNames = ["Enhanced full-spectrum front"; ...
    "Zhang-EF-513-v1"; "Fixed 0.9 profile, 1 m"; ...
    "Truth-free detected global fallback"];
method = repmat(methodNames, numel(snrValuesDb), 1);
snrDb = repelem(snrValuesDb, numel(methodNames));
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = trials.snrDb == snrValuesDb(snrIndex);
    rows = (snrIndex - 1) * numel(methodNames) + (1:numel(methodNames));
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(frontAngleErrorDeg(chosen)); ...
        repmat(rms(jointAngleErrorDeg(chosen)), 3, 1)];
    rangeRmseM(rows) = [rms(frontErrorM(chosen)); ...
        rms(zhangErrorM(chosen)); rms(fixedErrorM(chosen)); ...
        rms(fallbackErrorM(chosen))];
end
methodSummary = table(method, snrDb, sampleCount, ...
    angleRmseDeg, rangeRmseM);

comparisonNames = ["Fixed 1 m minus Zhang"; ...
    "Detected fallback minus Zhang"; ...
    "Detected fallback minus fixed 1 m"];
comparison = repmat(comparisonNames, numel(snrValuesDb), 1);
pairedSnrDb = repelem(snrValuesDb, numel(comparisonNames));
pairedCount = zeros(size(pairedSnrDb));
mseChangeM2 = zeros(size(pairedSnrDb));
ci95LowerM2 = zeros(size(pairedSnrDb));
ci95UpperM2 = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = trials.snrDb == snrValuesDb(snrIndex);
    pairs = {fixedErrorM(chosen), zhangErrorM(chosen); ...
        fallbackErrorM(chosen), zhangErrorM(chosen); ...
        fallbackErrorM(chosen), fixedErrorM(chosen)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) + comparisonIndex;
        pairedCount(row) = sum(chosen);
        [mseChangeM2(row), ci95LowerM2(row), ci95UpperM2(row)] = ...
            interval(pairs{comparisonIndex, 1}, ...
            pairs{comparisonIndex, 2});
    end
end
pairedSummary = table(comparison, pairedSnrDb, pairedCount, ...
    mseChangeM2, ci95LowerM2, ci95UpperM2);
pairedSummary.Properties.VariableNames(2:3) = ["snrDb", "sampleCount"];

detectorSnrDb = snrValuesDb;
detectorSampleCount = zeros(size(snrValuesDb));
fallbackRate = zeros(size(snrValuesDb));
coarseMissRate = zeros(size(snrValuesDb));
coarseMissRecall = zeros(size(snrValuesDb));
falseAlarmRate = zeros(size(snrValuesDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = trials.snrDb == snrValuesDb(snrIndex);
    miss = abs(frontErrorM) > 1;
    detectorSampleCount(snrIndex) = sum(chosen);
    fallbackRate(snrIndex) = mean(trigger(chosen));
    coarseMissRate(snrIndex) = mean(miss(chosen));
    coarseMissRecall(snrIndex) = conditionalMean( ...
        trigger(chosen), miss(chosen));
    falseAlarmRate(snrIndex) = conditionalMean( ...
        trigger(chosen), ~miss(chosen));
end
detectorSummary = table(detectorSnrDb, detectorSampleCount, ...
    fallbackRate, coarseMissRate, coarseMissRecall, falseAlarmRate);
detectorSummary.Properties.VariableNames(1:2) = ["snrDb", "sampleCount"];

tailMethodNames = ["Zhang-EF-513-v1"; "Fixed 0.9 profile, 1 m"; ...
    "Truth-free detected global fallback"];
tailMethod = repmat(tailMethodNames, numel(snrValuesDb), 1);
tailSnrDb = repelem(snrValuesDb, numel(tailMethodNames));
p90AbsErrorM = zeros(size(tailSnrDb));
p95AbsErrorM = zeros(size(tailSnrDb));
maximumAbsErrorM = zeros(size(tailSnrDb));
outlierRateAbove1M = zeros(size(tailSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = trials.snrDb == snrValuesDb(snrIndex);
    errors = {zhangErrorM(chosen); fixedErrorM(chosen); ...
        fallbackErrorM(chosen)};
    for methodIndex = 1:numel(tailMethodNames)
        row = (snrIndex - 1) * numel(tailMethodNames) + methodIndex;
        absoluteError = abs(errors{methodIndex});
        p90AbsErrorM(row) = prctile(absoluteError, 90);
        p95AbsErrorM(row) = prctile(absoluteError, 95);
        maximumAbsErrorM(row) = max(absoluteError);
        outlierRateAbove1M(row) = mean(absoluteError > 1);
    end
end
tailSummary = table(tailMethod, tailSnrDb, p90AbsErrorM, ...
    p95AbsErrorM, maximumAbsErrorM, outlierRateAbove1M);
tailSummary.Properties.VariableNames(1:2) = ["method", "snrDb"];

gridPoints = sum(cfg.gridSizes.^2);
musicCandidateCarrierEvaluations = fusionCarriers * gridPoints;
method = methodNames(2:4);
medianRuntimeMs = [median(trials.frontRuntimeMs + trials.musicRuntimeMs); ...
    median(trials.frontRuntimeMs + trials.musicRuntimeMs ...
    + trials.profile1RuntimeMs); ...
    median(trials.frontRuntimeMs + trials.musicRuntimeMs ...
    + trials.profile1RuntimeMs + trials.profile2RuntimeMs ...
    + trials.globalRuntimeMs)];
medianExactResponseEvaluations = [median(trials.frontResponseEvaluations); ...
    median(trials.frontResponseEvaluations ...
    + trials.profile1ResponseEvaluations); ...
    median(trials.frontResponseEvaluations ...
    + trials.profile1ResponseEvaluations ...
    + trials.profile2ResponseEvaluations ...
    + trials.globalResponseEvaluations)];
meanExactResponseEvaluations = [mean(trials.frontResponseEvaluations); ...
    mean(trials.frontResponseEvaluations ...
    + trials.profile1ResponseEvaluations); ...
    mean(trials.frontResponseEvaluations ...
    + trials.profile1ResponseEvaluations ...
    + trials.profile2ResponseEvaluations ...
    + trials.globalResponseEvaluations)];
candidateCarrierEvaluations = repmat( ...
    musicCandidateCarrierEvaluations, 3, 1);
eigendecompositionCount = repmat(fusionCarriers, 3, 1);
complexitySummary = table(method, medianRuntimeMs, ...
    medianExactResponseEvaluations, meanExactResponseEvaluations, ...
    candidateCarrierEvaluations, eigendecompositionCount);

[~, minimumIndex] = min(abs(fallbackErrorM));
gainM2 = zhangErrorM.^2 - fallbackErrorM.^2;
[~, gainIndex] = max(gainM2);
auditIndex = [minimumIndex; gainIndex];
auditType = ["Minimum absolute error"; "Maximum MSE gain over Zhang"];
seed = trials.seed(auditIndex);
auditSnrDb = trials.snrDb(auditIndex);
truthThetaDeg = trials.truthThetaDeg(auditIndex);
truthRangeM = trials.truthRangeM(auditIndex);
oursAbsErrorM = abs(fallbackErrorM(auditIndex));
zhangAbsErrorM = abs(zhangErrorM(auditIndex));
fixedAbsErrorM = abs(fixedErrorM(auditIndex));
fallbackTriggered = trigger(auditIndex);
seedAudit = table(auditType, seed, auditSnrDb, truthThetaDeg, ...
    truthRangeM, oursAbsErrorM, zhangAbsErrorM, fixedAbsErrorM, ...
    fallbackTriggered);
seedAudit.Properties.VariableNames{3} = 'snrDb';
end

function [change, lower, upper] = interval(methodError, referenceError)
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
halfWidth = 1.96 * std(squaredChange) / sqrt(numel(squaredChange));
lower = change - halfWidth;
upper = change + halfWidth;
end

function seedsM = localRangeSeeds(cfg, centerM, halfWidthM, spacingM)
lowerM = max(cfg.rangeLimitsM(1), centerM - halfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerM + halfWidthM);
numIntervals = max(1, ceil((upperM - lowerM) / spacingM));
seedsM = linspace(lowerM, upperM, numIntervals + 1).';
end

function seedsM = globalRangeSeeds(cfg, spacingM)
numIntervals = ceil(diff(cfg.rangeLimitsM) / spacingM);
seedsM = linspace(cfg.rangeLimitsM(1), cfg.rangeLimitsM(2), ...
    numIntervals + 1).';
end

function boundary = isProfileBoundary(rangeM, seedsM, spacingM)
toleranceM = max(1e-6, spacingM * 1e-3);
boundary = rangeM - seedsM(1) <= toleranceM ...
    || seedsM(end) - rangeM <= toleranceM;
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function plotResults(summary, detector, outputFile)
figureHandle = figure("Visible", "off", "Color", "w", ...
    "Position", [100, 100, 1080, 420]);
layout = tiledlayout(1, 2, "TileSpacing", "compact", ...
    "Padding", "compact");
axisHandle = nexttile(layout);
hold(axisHandle, "on");
methods = unique(summary.method, "stable");
for methodIndex = 1:numel(methods)
    chosen = summary.method == methods(methodIndex);
    semilogy(axisHandle, summary.snrDb(chosen), ...
        summary.rangeRmseM(chosen), "-o", "LineWidth", 1.2);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Range RMSE (m)");
legend(axisHandle, methods, "Location", "best");

axisHandle = nexttile(layout);
plot(axisHandle, detector.snrDb, detector.coarseMissRate, "-o", ...
    detector.snrDb, detector.fallbackRate, "-s", ...
    detector.snrDb, detector.coarseMissRecall, "-^", ...
    "LineWidth", 1.2);
grid(axisHandle, "on");
ylim(axisHandle, [0, 1]);
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Rate");
legend(axisHandle, "Coarse miss", "Fallback", "Miss recall", ...
    "Location", "best");
title(layout, "Round 19 random-location miss fallback and complexity");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
