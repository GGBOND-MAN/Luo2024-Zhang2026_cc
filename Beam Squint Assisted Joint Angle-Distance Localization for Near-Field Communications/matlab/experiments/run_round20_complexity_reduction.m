function run_round20_complexity_reduction
%RUN_ROUND20_COMPLEXITY_REDUCTION Reduce cost under noninferiority limits.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round20");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 20 uses %d workers.\n", pool.NumWorkers);

sourceFile = fullfile(projectFolder, "results", "full_spectrum", ...
    "round19", "random_miss_fallback_complexity.mat");
source = load(sourceFile, "validation", "cfg");
cfg = source.cfg;
scan = fsjad.prepareScan(cfg);
snrValuesDb = [-10; 0; 20];
calibrationPerSnr = 50;
validationPerSnr = 50;
calibrationRows = splitRows(source.validation.snrDb, snrValuesDb, ...
    1, calibrationPerSnr);
validationRows = splitRows(source.validation.snrDb, snrValuesDb, ...
    calibrationPerSnr + 1, calibrationPerSnr + validationPerSnr);
calibrationSource = subsetStruct(source.validation, calibrationRows);
validationSource = subsetStruct(source.validation, validationRows);

fusionCarrierCandidates = [17; 33; 65; 129; 257];
compactGridSizes = [31, 21, 15];
profileSpacingCandidatesM = [0.1; 0.25];
profileHalfWidthM = 1;
profileLambda = 0.9;
rangeNoninferiorityRatio = 1.05;
angleNoninferiorityRatio = 1.10;

reproductionAudit = auditReferenceReproduction( ...
    cfg, scan, calibrationSource, 513);
calibration = runCandidates(cfg, scan, calibrationSource, ...
    fusionCarrierCandidates, compactGridSizes, ...
    profileSpacingCandidatesM, profileHalfWidthM, outputFolder, ...
    "calibration");
[screen, selected] = selectConfiguration(cfg, calibrationSource, ...
    calibration, fusionCarrierCandidates, compactGridSizes, ...
    profileSpacingCandidatesM, profileLambda, snrValuesDb, ...
    rangeNoninferiorityRatio, angleNoninferiorityRatio);

lockedFusionCarriers = selected.fusionCarrierCount;
lockedProfileSpacingM = selected.profileSpacingM;
validation = runCandidates(cfg, scan, validationSource, ...
    lockedFusionCarriers, compactGridSizes, lockedProfileSpacingM, ...
    profileHalfWidthM, outputFolder, "validation");
[methodSummary, pairedSummary, complexitySummary, tailSummary, ...
    seedAudit] = summarizeValidation(cfg, validationSource, validation, ...
    selected, compactGridSizes, profileLambda, snrValuesDb);

protocol = table(calibrationPerSnr, validationPerSnr, ...
    rangeNoninferiorityRatio, angleNoninferiorityRatio, ...
    profileHalfWidthM, profileLambda, ...
    strjoin(string(compactGridSizes), "/"));
protocol.Properties.VariableNames = ["calibrationPerSnr", ...
    "validationPerSnr", "rangeMseRatioLimit", ...
    "angleMseRatioLimit", "profileHalfWidthM", ...
    "profileLambda", "compactGridSizes"];

writetable(protocol, fullfile(outputFolder, "protocol.csv"));
writetable(reproductionAudit, fullfile(outputFolder, ...
    "reference_reproduction_audit.csv"));
writetable(screen, fullfile(outputFolder, ...
    "complexity_calibration_screen.csv"));
writetable(selected, fullfile(outputFolder, ...
    "selected_configuration.csv"));
writetable(methodSummary, fullfile(outputFolder, "method_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, "paired_summary.csv"));
writetable(complexitySummary, fullfile(outputFolder, ...
    "complexity_summary.csv"));
writetable(tailSummary, fullfile(outputFolder, "tail_summary.csv"));
writetable(seedAudit, fullfile(outputFolder, "seed_audit.csv"));
save(fullfile(outputFolder, "complexity_reduction.mat"), ...
    "cfg", "calibrationRows", "validationRows", ...
    "calibrationSource", "validationSource", "calibration", ...
    "validation", "screen", "selected", "methodSummary", ...
    "pairedSummary", "complexitySummary", "tailSummary", ...
    "seedAudit", "protocol", "reproductionAudit");
plotResults(methodSummary, complexitySummary, fullfile(outputFolder, ...
    "complexity_reduction.png"));

disp(reproductionAudit);
disp(selected);
disp(methodSummary);
disp(pairedSummary);
disp(complexitySummary);
disp(tailSummary);
disp(seedAudit);
end

function rows = splitRows(snrDb, snrValuesDb, firstIndex, lastIndex)
rows = zeros(numel(snrValuesDb) * (lastIndex - firstIndex + 1), 1);
writeIndex = 0;
for snrIndex = 1:numel(snrValuesDb)
    candidates = find(snrDb == snrValuesDb(snrIndex));
    chosen = candidates(firstIndex:lastIndex);
    rows(writeIndex + (1:numel(chosen))) = chosen;
    writeIndex = writeIndex + numel(chosen);
end
end

function output = subsetStruct(input, rows)
output = struct();
fields = string(fieldnames(input));
for field = fields.'
    output.(field) = input.(field)(rows, :);
end
end

function audit = auditReferenceReproduction(cfg, scan, source, ...
    fusionCarriers)
[observation, snapshots, carrierIndex] = regenerateTrial( ...
    cfg, scan, source, 1, fusionCarriers);
frontThetaDeg = source.frontThetaDeg(1);
frontRangeM = source.frontRangeM(1);
result = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    frontThetaDeg, frontRangeM);
thetaDifferenceDeg = result.thetaDeg - source.jointThetaDeg(1);
rangeDifferenceM = result.rangeM - source.jointRangeM(1);
observationFinite = all(isfinite(observation));
passed = abs(thetaDifferenceDeg) <= 1e-12 ...
    && abs(rangeDifferenceM) <= 1e-12 && observationFinite;
assert(passed, "fsjad:Round20ReferenceReproductionMismatch");
seed = source.seed(1);
audit = table(seed, thetaDifferenceDeg, rangeDifferenceM, ...
    observationFinite, passed);
end

function trials = runCandidates(cfg, scan, source, fusionCarriers, ...
    gridSizes, profileSpacingsM, profileHalfWidthM, outputFolder, label)
checkpointFile = fullfile(outputFolder, label + "_checkpoint.mat");
numRows = numel(source.seed);
numFusion = numel(fusionCarriers);
numSpacing = numel(profileSpacingsM);
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.source.seed, source.seed) ...
        && isequal(checkpoint.fusionCarriers, fusionCarriers) ...
        && isequal(checkpoint.profileSpacingsM, profileSpacingsM), ...
        "fsjad:Round20CheckpointMismatch");
    trials = checkpoint.trials;
    completedRows = checkpoint.completedRows;
else
    trials.musicThetaDeg = nan(numRows, numFusion);
    trials.musicRangeM = nan(numRows, numFusion);
    trials.musicRuntimeMs = nan(numRows, numFusion);
    trials.profileRangeM = nan(numRows, numFusion, numSpacing);
    trials.profileRuntimeMs = nan(numRows, numFusion, numSpacing);
    trials.profileResponseEvaluations = ...
        nan(numRows, numFusion, numSpacing);
    completedRows = 0;
end
candidateCfg = cfg;
candidateCfg.gridSizes = gridSizes;
batchSize = 5;
maximumFusionCarriers = max(fusionCarriers);
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        [observation, fullSnapshots, fullCarrierIndex, peakCarrierIndex] = ...
            regenerateTrial(cfg, scan, source, row, ...
            maximumFusionCarriers);
        batch{batchIndex} = evaluateTrial(candidateCfg, scan, ...
            observation, fullSnapshots, fullCarrierIndex, ...
            peakCarrierIndex, ...
            source.frontThetaDeg(row), source.frontRangeM(row), ...
            fusionCarriers, profileSpacingsM, profileHalfWidthM);
    end
    for batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        trials.musicThetaDeg(row, :) = batch{batchIndex}.musicThetaDeg;
        trials.musicRangeM(row, :) = batch{batchIndex}.musicRangeM;
        trials.musicRuntimeMs(row, :) = batch{batchIndex}.musicRuntimeMs;
        trials.profileRangeM(row, :, :) = ...
            batch{batchIndex}.profileRangeM;
        trials.profileRuntimeMs(row, :, :) = ...
            batch{batchIndex}.profileRuntimeMs;
        trials.profileResponseEvaluations(row, :, :) = ...
            batch{batchIndex}.profileResponseEvaluations;
    end
    completedRows = rows(end);
    save(checkpointFile, "trials", "completedRows", "source", ...
        "fusionCarriers", "gridSizes", "profileSpacingsM", ...
        "profileHalfWidthM", "cfg");
    fprintf("Round 20 %s rows %d/%d complete.\n", ...
        label, completedRows, numRows);
end
end

function [observation, snapshots, carrierIndex, peakCarrierIndex] = ...
    regenerateTrial( ...
    cfg, scan, source, row, fusionCarriers)
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(source.truthThetaDeg(row)), source.truthRangeM(row), scan);
signalPower = mean(abs(truthResponse).^2);
stream = RandStream("mt19937ar", Seed=source.seed(row));
noiseVariance = signalPower / 10^(source.snrDb(row) / 10);
beta = exp(1i * 2 * pi * rand(stream));
noise = sqrt(noiseVariance / 2) * (randn(stream, ...
    cfg.numSubcarriers, 1) + 1i * randn(stream, ...
    cfg.numSubcarriers, 1));
observation = beta * truthResponse + noise;
[~, peakPosition] = max(abs(observation).^2);
peakCarrierIndex = peakPosition - 1;
carrierIndex = fixedCountWindow(peakCarrierIndex, fusionCarriers, ...
    cfg.numSubcarriers);
snapshots = jad.simulateSnapshots(cfg, source.truthThetaDeg(row), ...
    source.truthRangeM(row), source.snrDb(row), carrierIndex, stream);
end

function result = evaluateTrial(cfg, scan, observation, fullSnapshots, ...
    fullCarrierIndex, peakCarrierIndex, frontThetaDeg, frontRangeM, ...
    fusionCarriers, ...
    profileSpacingsM, profileHalfWidthM)
numFusion = numel(fusionCarriers);
numSpacing = numel(profileSpacingsM);
result.musicThetaDeg = zeros(1, numFusion);
result.musicRangeM = zeros(1, numFusion);
result.musicRuntimeMs = zeros(1, numFusion);
result.profileRangeM = zeros(1, numFusion, numSpacing);
result.profileRuntimeMs = zeros(1, numFusion, numSpacing);
result.profileResponseEvaluations = zeros(1, numFusion, numSpacing);
for fusionIndex = 1:numFusion
    carrierIndex = fixedCountWindow(peakCarrierIndex, ...
        fusionCarriers(fusionIndex), ...
        cfg.numSubcarriers);
    positions = carrierIndex - fullCarrierIndex(1) + 1;
    assert(all(positions >= 1 & positions <= numel(fullCarrierIndex)), ...
        "fsjad:Round20CarrierSubsetMismatch");
    timer = tic;
    music = jad.localMusicEstimate(cfg, ...
        fullSnapshots(:, positions), carrierIndex, ...
        frontThetaDeg, frontRangeM);
    result.musicRuntimeMs(fusionIndex) = 1000 * toc(timer);
    result.musicThetaDeg(fusionIndex) = music.thetaDeg;
    result.musicRangeM(fusionIndex) = music.rangeM;
    for spacingIndex = 1:numSpacing
        seedsM = localRangeSeeds(cfg, frontRangeM, ...
            profileHalfWidthM, profileSpacingsM(spacingIndex));
        timer = tic;
        profile = fsjad.profileRangeAtAngle(cfg, observation, ...
            music.thetaDeg, scan, seedsM);
        result.profileRuntimeMs(1, fusionIndex, spacingIndex) = ...
            1000 * toc(timer);
        result.profileRangeM(1, fusionIndex, spacingIndex) = ...
            profile.rangeM;
        result.profileResponseEvaluations(1, fusionIndex, spacingIndex) = ...
            profile.responseEvaluations;
    end
end
end

function [screen, selected] = selectConfiguration(cfg, source, trials, ...
    fusionCarriers, gridSizes, profileSpacingsM, lambda, snrValuesDb, ...
    rangeRatioLimit, angleRatioLimit)
numRows = numel(fusionCarriers) * numel(profileSpacingsM);
fusionCarrierCount = repelem(fusionCarriers, numel(profileSpacingsM));
profileSpacingM = repmat(profileSpacingsM, numel(fusionCarriers), 1);
rangeRmseM = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
maximumRangeMseRatio = zeros(numRows, 1);
maximumAngleMseRatio = zeros(numRows, 1);
medianRuntimeMs = zeros(numRows, 1);
meanProfileResponseEvaluations = zeros(numRows, 1);
operationProxy = zeros(numRows, 1);
referenceRangeError = source.frontRangeM + lambda ...
    * (source.profile1RangeM - source.frontRangeM) - source.truthRangeM;
referenceAngleError = source.jointThetaDeg - source.truthThetaDeg;
frontEvaluations = mean(source.frontResponseEvaluations);
row = 0;
for fusionIndex = 1:numel(fusionCarriers)
    for spacingIndex = 1:numel(profileSpacingsM)
        row = row + 1;
        estimateRangeM = source.frontRangeM + lambda ...
            * (trials.profileRangeM(:, fusionIndex, spacingIndex) ...
            - source.frontRangeM);
        rangeError = estimateRangeM - source.truthRangeM;
        angleError = trials.musicThetaDeg(:, fusionIndex) ...
            - source.truthThetaDeg;
        rangeRatios = zeros(size(snrValuesDb));
        angleRatios = zeros(size(snrValuesDb));
        for snrIndex = 1:numel(snrValuesDb)
            chosen = source.snrDb == snrValuesDb(snrIndex);
            rangeRatios(snrIndex) = mean(rangeError(chosen).^2) ...
                / mean(referenceRangeError(chosen).^2);
            angleRatios(snrIndex) = mean(angleError(chosen).^2) ...
                / mean(referenceAngleError(chosen).^2);
        end
        rangeRmseM(row) = rms(rangeError);
        angleRmseDeg(row) = rms(angleError);
        maximumRangeMseRatio(row) = max(rangeRatios);
        maximumAngleMseRatio(row) = max(angleRatios);
        profileRuntime = trials.profileRuntimeMs( ...
            :, fusionIndex, spacingIndex);
        medianRuntimeMs(row) = median(source.frontRuntimeMs ...
            + trials.musicRuntimeMs(:, fusionIndex) + profileRuntime);
        profileEvaluations = trials.profileResponseEvaluations( ...
            :, fusionIndex, spacingIndex);
        meanProfileResponseEvaluations(row) = mean(profileEvaluations);
        operationProxy(row) = complexityProxy(cfg, ...
            fusionCarriers(fusionIndex), gridSizes, ...
            frontEvaluations, mean(profileEvaluations));
    end
end
feasible = maximumRangeMseRatio <= rangeRatioLimit ...
    & maximumAngleMseRatio <= angleRatioLimit;
screen = table(fusionCarrierCount, profileSpacingM, rangeRmseM, ...
    angleRmseDeg, maximumRangeMseRatio, maximumAngleMseRatio, ...
    feasible, medianRuntimeMs, meanProfileResponseEvaluations, ...
    operationProxy);
if any(feasible)
    candidates = find(feasible);
    [~, localIndex] = min(operationProxy(candidates));
    selectedRow = candidates(localIndex);
else
    penalty = max(maximumRangeMseRatio / rangeRatioLimit, ...
        maximumAngleMseRatio / angleRatioLimit);
    [~, selectedRow] = min(penalty);
end
selected = screen(selectedRow, :);
selected.gridSizes = strjoin(string(gridSizes), "/");
selected.rangeMseRatioLimit = rangeRatioLimit;
selected.angleMseRatioLimit = angleRatioLimit;
end

function value = complexityProxy(cfg, fusionCarriers, gridSizes, ...
    frontResponseEvaluations, profileResponseEvaluations)
numSubarrays = cfg.numSubarrays;
subarraySize = cfg.subarraySize;
responseCost = cfg.numAntennas * cfg.numSubcarriers;
musicCost = fusionCarriers * (numSubarrays * subarraySize^2 ...
    + subarraySize^3 + sum(gridSizes.^2) * subarraySize);
value = musicCost + (frontResponseEvaluations ...
    + profileResponseEvaluations) * responseCost;
end

function [methodSummary, pairedSummary, complexitySummary, ...
    tailSummary, seedAudit] = summarizeValidation(cfg, source, trials, ...
    selected, gridSizes, lambda, snrValuesDb)
lowAngleError = trials.musicThetaDeg(:, 1) - source.truthThetaDeg;
lowRangeEstimate = source.frontRangeM + lambda ...
    * (trials.profileRangeM(:, 1, 1) - source.frontRangeM);
lowRangeError = lowRangeEstimate - source.truthRangeM;
currentAngleError = source.jointThetaDeg - source.truthThetaDeg;
currentRangeEstimate = source.frontRangeM + lambda ...
    * (source.profile1RangeM - source.frontRangeM);
currentRangeError = currentRangeEstimate - source.truthRangeM;
zhangRangeError = source.jointRangeM - source.truthRangeM;

methodNames = ["Zhang-EF-513-v1"; "Current 513 profile"; ...
    "Locked low-complexity profile"];
method = repmat(methodNames, numel(snrValuesDb), 1);
snrDb = repelem(snrValuesDb, numel(methodNames));
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = source.snrDb == snrValuesDb(snrIndex);
    rows = (snrIndex - 1) * numel(methodNames) + (1:numel(methodNames));
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(currentAngleError(chosen)); ...
        rms(currentAngleError(chosen)); rms(lowAngleError(chosen))];
    rangeRmseM(rows) = [rms(zhangRangeError(chosen)); ...
        rms(currentRangeError(chosen)); rms(lowRangeError(chosen))];
end
methodSummary = table(method, snrDb, sampleCount, ...
    angleRmseDeg, rangeRmseM);

comparisonNames = ["Low complexity minus Zhang"; ...
    "Low complexity minus current"];
comparison = repmat(comparisonNames, numel(snrValuesDb), 1);
pairedSnrDb = repelem(snrValuesDb, numel(comparisonNames));
pairedCount = zeros(size(pairedSnrDb));
mseChangeM2 = zeros(size(pairedSnrDb));
ci95LowerM2 = zeros(size(pairedSnrDb));
ci95UpperM2 = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = source.snrDb == snrValuesDb(snrIndex);
    references = {zhangRangeError(chosen); currentRangeError(chosen)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) + comparisonIndex;
        pairedCount(row) = sum(chosen);
        [mseChangeM2(row), ci95LowerM2(row), ci95UpperM2(row)] = ...
            interval(lowRangeError(chosen), references{comparisonIndex});
    end
end
pairedSummary = table(comparison, pairedSnrDb, pairedCount, ...
    mseChangeM2, ci95LowerM2, ci95UpperM2);
pairedSummary.Properties.VariableNames(2:3) = ["snrDb", "sampleCount"];

currentGridSizes = [61, 41, 31];
frontEvaluations = mean(source.frontResponseEvaluations);
currentProfileEvaluations = mean(source.profile1ResponseEvaluations);
lowProfileEvaluations = mean(trials.profileResponseEvaluations(:, 1, 1));
currentProxy = complexityProxy(cfg, 513, currentGridSizes, ...
    frontEvaluations, currentProfileEvaluations);
lowProxy = complexityProxy(cfg, selected.fusionCarrierCount, gridSizes, ...
    frontEvaluations, lowProfileEvaluations);
complexityMethod = methodNames;
medianRuntimeMs = [median(source.frontRuntimeMs + source.musicRuntimeMs); ...
    median(source.frontRuntimeMs + source.musicRuntimeMs ...
    + source.profile1RuntimeMs); ...
    median(source.frontRuntimeMs + trials.musicRuntimeMs(:, 1) ...
    + trials.profileRuntimeMs(:, 1, 1))];
candidateCarrierEvaluations = [513 * sum(currentGridSizes.^2); ...
    513 * sum(currentGridSizes.^2); ...
    selected.fusionCarrierCount * sum(gridSizes.^2)];
eigendecompositionCount = [513; 513; selected.fusionCarrierCount];
meanExactResponseEvaluations = [frontEvaluations; ...
    frontEvaluations + currentProfileEvaluations; ...
    frontEvaluations + lowProfileEvaluations];
operationProxy = [complexityProxy(cfg, 513, currentGridSizes, ...
    frontEvaluations, 0); currentProxy; lowProxy];
operationProxyRatioToCurrent = operationProxy / currentProxy;
complexitySummary = table(complexityMethod, medianRuntimeMs, ...
    candidateCarrierEvaluations, eigendecompositionCount, ...
    meanExactResponseEvaluations, operationProxy, ...
    operationProxyRatioToCurrent);
complexitySummary.Properties.VariableNames{1} = 'method';

tailMethodNames = methodNames(1:3);
tailMethod = repmat(tailMethodNames, numel(snrValuesDb), 1);
tailSnrDb = repelem(snrValuesDb, numel(tailMethodNames));
p95AbsErrorM = zeros(size(tailSnrDb));
maximumAbsErrorM = zeros(size(tailSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = source.snrDb == snrValuesDb(snrIndex);
    errors = {zhangRangeError(chosen); currentRangeError(chosen); ...
        lowRangeError(chosen)};
    for methodIndex = 1:numel(tailMethodNames)
        row = (snrIndex - 1) * numel(tailMethodNames) + methodIndex;
        absoluteError = abs(errors{methodIndex});
        p95AbsErrorM(row) = prctile(absoluteError, 95);
        maximumAbsErrorM(row) = max(absoluteError);
    end
end
tailSummary = table(tailMethod, tailSnrDb, p95AbsErrorM, ...
    maximumAbsErrorM);
tailSummary.Properties.VariableNames(1:2) = ["method", "snrDb"];

[~, minimumIndex] = min(abs(lowRangeError));
gainM2 = zhangRangeError.^2 - lowRangeError.^2;
[~, gainIndex] = max(gainM2);
auditIndex = [minimumIndex; gainIndex];
auditType = ["Minimum absolute error"; "Maximum MSE gain over Zhang"];
seed = source.seed(auditIndex);
auditSnrDb = source.snrDb(auditIndex);
truthThetaDeg = source.truthThetaDeg(auditIndex);
truthRangeM = source.truthRangeM(auditIndex);
lowAbsErrorM = abs(lowRangeError(auditIndex));
currentAbsErrorM = abs(currentRangeError(auditIndex));
zhangAbsErrorM = abs(zhangRangeError(auditIndex));
seedAudit = table(auditType, seed, auditSnrDb, truthThetaDeg, ...
    truthRangeM, lowAbsErrorM, currentAbsErrorM, zhangAbsErrorM);
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

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function plotResults(summary, complexity, outputFile)
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
bar(axisHandle, categorical(complexity.method), ...
    complexity.operationProxyRatioToCurrent);
grid(axisHandle, "on");
ylabel(axisHandle, "Operation proxy / current method");
title(layout, "Round 20 locked complexity reduction");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
