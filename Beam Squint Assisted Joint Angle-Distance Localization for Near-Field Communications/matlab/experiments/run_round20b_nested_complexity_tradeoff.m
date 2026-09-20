function run_round20b_nested_complexity_tradeoff
%RUN_ROUND20B_NESTED_COMPLEXITY_TRADEOFF Lock a nested-noise candidate.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round20");
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 20b uses %d workers.\n", pool.NumWorkers);

source = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round19", "random_miss_fallback_complexity.mat"), ...
    "validation", "cfg");
cfg = source.cfg;
scan = fsjad.prepareScan(cfg);
snrValuesDb = [-10; 0; 20];
calibrationRows = splitRows(source.validation.snrDb, snrValuesDb, 1, 50);
validationRows = splitRows(source.validation.snrDb, snrValuesDb, 51, 100);
calibrationSource = subsetStruct(source.validation, calibrationRows);
validationSource = subsetStruct(source.validation, validationRows);

fusionCarriers = [129; 257; 257; 513; 513];
gridSizes = {[61, 41, 31]; [61, 41, 31]; [41, 31, 21]; ...
    [41, 31, 21]; [31, 21, 15]};
configuration = ["K129-full"; "K257-full"; "K257-medium"; ...
    "K513-medium"; "K513-compact"];
profileSpacingM = 0.25;
profileHalfWidthM = 1;
profileLambda = 0.9;
rangeMseRatioLimit = 1.05;
angleMseRatioLimit = 1.10;

calibration = runConfigurations(cfg, scan, calibrationSource, ...
    fusionCarriers, gridSizes, profileSpacingM, profileHalfWidthM, ...
    outputFolder, "nested_calibration");
[screen, selected] = selectConfiguration(cfg, calibrationSource, ...
    calibration, configuration, fusionCarriers, gridSizes, ...
    profileLambda, snrValuesDb, rangeMseRatioLimit, ...
    angleMseRatioLimit);
selectedIndex = find(configuration == selected.configuration, 1);
validation = runConfigurations(cfg, scan, validationSource, ...
    fusionCarriers(selectedIndex), gridSizes(selectedIndex), ...
    profileSpacingM, profileHalfWidthM, outputFolder, ...
    "nested_validation");
[methodSummary, pairedSummary, complexitySummary, tailSummary, ...
    seedAudit] = summarizeValidation(cfg, validationSource, validation, ...
    selected, gridSizes{selectedIndex}, profileLambda, snrValuesDb);

diagnosticSpacingM = 0.1;
diagnosticCalibration = runConfigurations(cfg, scan, calibrationSource, ...
    fusionCarriers(selectedIndex), gridSizes(selectedIndex), ...
    diagnosticSpacingM, profileHalfWidthM, outputFolder, ...
    "nested01_calibration");
[diagnosticScreen, diagnosticSelected] = selectConfiguration( ...
    cfg, calibrationSource, diagnosticCalibration, ...
    configuration(selectedIndex), fusionCarriers(selectedIndex), ...
    gridSizes(selectedIndex), profileLambda, snrValuesDb, ...
    rangeMseRatioLimit, angleMseRatioLimit);
diagnosticValidation = runConfigurations(cfg, scan, validationSource, ...
    fusionCarriers(selectedIndex), gridSizes(selectedIndex), ...
    diagnosticSpacingM, profileHalfWidthM, outputFolder, ...
    "nested01_validation");
[diagnosticMethodSummary, diagnosticPairedSummary, ...
    diagnosticComplexitySummary, diagnosticTailSummary, ...
    diagnosticSeedAudit] = summarizeValidation(cfg, validationSource, ...
    diagnosticValidation, diagnosticSelected, gridSizes{selectedIndex}, ...
    profileLambda, snrValuesDb);

writetable(screen, fullfile(outputFolder, ...
    "nested_calibration_screen.csv"));
writetable(selected, fullfile(outputFolder, ...
    "nested_selected_configuration.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "nested_method_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, ...
    "nested_paired_summary.csv"));
writetable(complexitySummary, fullfile(outputFolder, ...
    "nested_complexity_summary.csv"));
writetable(tailSummary, fullfile(outputFolder, ...
    "nested_tail_summary.csv"));
writetable(seedAudit, fullfile(outputFolder, ...
    "nested_seed_audit.csv"));
writetable(diagnosticScreen, fullfile(outputFolder, ...
    "nested01_diagnostic_screen.csv"));
writetable(diagnosticMethodSummary, fullfile(outputFolder, ...
    "nested01_method_summary.csv"));
writetable(diagnosticPairedSummary, fullfile(outputFolder, ...
    "nested01_paired_summary.csv"));
writetable(diagnosticComplexitySummary, fullfile(outputFolder, ...
    "nested01_complexity_summary.csv"));
writetable(diagnosticTailSummary, fullfile(outputFolder, ...
    "nested01_tail_summary.csv"));
writetable(diagnosticSeedAudit, fullfile(outputFolder, ...
    "nested01_seed_audit.csv"));
save(fullfile(outputFolder, "nested_complexity_tradeoff.mat"), ...
    "cfg", "calibrationRows", "validationRows", ...
    "calibrationSource", "validationSource", "configuration", ...
    "fusionCarriers", "gridSizes", "calibration", "validation", ...
    "screen", "selected", "methodSummary", "pairedSummary", ...
    "complexitySummary", "tailSummary", "seedAudit", ...
    "diagnosticSpacingM", "diagnosticCalibration", ...
    "diagnosticScreen", "diagnosticSelected", ...
    "diagnosticValidation", "diagnosticMethodSummary", ...
    "diagnosticPairedSummary", "diagnosticComplexitySummary", ...
    "diagnosticTailSummary", "diagnosticSeedAudit");
plotResults(methodSummary, complexitySummary, fullfile(outputFolder, ...
    "nested_complexity_tradeoff.png"));
plotResults(diagnosticMethodSummary, diagnosticComplexitySummary, ...
    fullfile(outputFolder, "nested01_complexity_tradeoff.png"));

disp(selected);
disp(methodSummary);
disp(pairedSummary);
disp(complexitySummary);
disp(tailSummary);
disp(seedAudit);
disp(diagnosticScreen);
disp(diagnosticMethodSummary);
disp(diagnosticPairedSummary);
disp(diagnosticComplexitySummary);
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

function trials = runConfigurations(cfg, scan, source, fusionCarriers, ...
    gridSizes, profileSpacingM, profileHalfWidthM, outputFolder, label)
checkpointFile = fullfile(outputFolder, label + "_checkpoint.mat");
numRows = numel(source.seed);
numConfigurations = numel(fusionCarriers);
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.source.seed, source.seed) ...
        && isequal(checkpoint.fusionCarriers, fusionCarriers) ...
        && isequal(checkpoint.gridSizes, gridSizes), ...
        "fsjad:Round20bCheckpointMismatch");
    trials = checkpoint.trials;
    completedRows = checkpoint.completedRows;
else
    trials.musicThetaDeg = nan(numRows, numConfigurations);
    trials.musicRangeM = nan(numRows, numConfigurations);
    trials.musicRuntimeMs = nan(numRows, numConfigurations);
    trials.profileRangeM = nan(numRows, numConfigurations);
    trials.profileRuntimeMs = nan(numRows, numConfigurations);
    trials.profileResponseEvaluations = nan(numRows, numConfigurations);
    completedRows = 0;
end
batchSize = 5;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        [observation, snapshots, carrierIndex, peakCarrierIndex] = ...
            regenerateTrial(cfg, scan, source, row);
        batch{batchIndex} = evaluateTrial(cfg, scan, observation, ...
            snapshots, carrierIndex, peakCarrierIndex, ...
            source.frontThetaDeg(row), source.frontRangeM(row), ...
            fusionCarriers, gridSizes, profileSpacingM, ...
            profileHalfWidthM);
    end
    for batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        trials.musicThetaDeg(row, :) = batch{batchIndex}.musicThetaDeg;
        trials.musicRangeM(row, :) = batch{batchIndex}.musicRangeM;
        trials.musicRuntimeMs(row, :) = batch{batchIndex}.musicRuntimeMs;
        trials.profileRangeM(row, :) = batch{batchIndex}.profileRangeM;
        trials.profileRuntimeMs(row, :) = batch{batchIndex}.profileRuntimeMs;
        trials.profileResponseEvaluations(row, :) = ...
            batch{batchIndex}.profileResponseEvaluations;
    end
    completedRows = rows(end);
    save(checkpointFile, "trials", "completedRows", "source", ...
        "fusionCarriers", "gridSizes", "profileSpacingM", ...
        "profileHalfWidthM", "cfg");
    fprintf("Round 20b %s rows %d/%d complete.\n", ...
        label, completedRows, numRows);
end
end

function [observation, snapshots, carrierIndex, peakCarrierIndex] = ...
    regenerateTrial(cfg, scan, source, row)
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
carrierIndex = fixedCountWindow(peakCarrierIndex, 513, ...
    cfg.numSubcarriers);
snapshots = jad.simulateSnapshots(cfg, source.truthThetaDeg(row), ...
    source.truthRangeM(row), source.snrDb(row), carrierIndex, stream);
end

function result = evaluateTrial(cfg, scan, observation, snapshots, ...
    fullCarrierIndex, peakCarrierIndex, frontThetaDeg, frontRangeM, ...
    fusionCarriers, gridSizes, profileSpacingM, profileHalfWidthM)
numConfigurations = numel(fusionCarriers);
result.musicThetaDeg = zeros(1, numConfigurations);
result.musicRangeM = zeros(1, numConfigurations);
result.musicRuntimeMs = zeros(1, numConfigurations);
result.profileRangeM = zeros(1, numConfigurations);
result.profileRuntimeMs = zeros(1, numConfigurations);
result.profileResponseEvaluations = zeros(1, numConfigurations);
for configurationIndex = 1:numConfigurations
    carrierIndex = fixedCountWindow(peakCarrierIndex, ...
        fusionCarriers(configurationIndex), cfg.numSubcarriers);
    positions = carrierIndex - fullCarrierIndex(1) + 1;
    assert(all(positions >= 1 & positions <= numel(fullCarrierIndex)), ...
        "fsjad:Round20bCarrierSubsetMismatch");
    candidateCfg = cfg;
    candidateCfg.gridSizes = gridSizes{configurationIndex};
    timer = tic;
    music = jad.localMusicEstimate(candidateCfg, ...
        snapshots(:, positions), carrierIndex, frontThetaDeg, frontRangeM);
    result.musicRuntimeMs(configurationIndex) = 1000 * toc(timer);
    result.musicThetaDeg(configurationIndex) = music.thetaDeg;
    result.musicRangeM(configurationIndex) = music.rangeM;
    seedsM = localRangeSeeds(cfg, frontRangeM, ...
        profileHalfWidthM, profileSpacingM);
    timer = tic;
    profile = fsjad.profileRangeAtAngle(cfg, observation, ...
        music.thetaDeg, scan, seedsM);
    result.profileRuntimeMs(configurationIndex) = 1000 * toc(timer);
    result.profileRangeM(configurationIndex) = profile.rangeM;
    result.profileResponseEvaluations(configurationIndex) = ...
        profile.responseEvaluations;
end
end

function [screen, selected] = selectConfiguration(cfg, source, trials, ...
    configuration, fusionCarriers, gridSizes, lambda, snrValuesDb, ...
    rangeRatioLimit, angleRatioLimit)
numConfigurations = numel(configuration);
rangeRmseM = zeros(numConfigurations, 1);
angleRmseDeg = zeros(numConfigurations, 1);
maximumRangeMseRatio = zeros(numConfigurations, 1);
maximumAngleMseRatio = zeros(numConfigurations, 1);
medianRuntimeMs = zeros(numConfigurations, 1);
operationProxy = zeros(numConfigurations, 1);
referenceRangeError = source.frontRangeM + lambda ...
    * (source.profile1RangeM - source.frontRangeM) - source.truthRangeM;
referenceAngleError = source.jointThetaDeg - source.truthThetaDeg;
frontEvaluations = mean(source.frontResponseEvaluations);
for configurationIndex = 1:numConfigurations
    rangeEstimate = source.frontRangeM + lambda ...
        * (trials.profileRangeM(:, configurationIndex) ...
        - source.frontRangeM);
    rangeError = rangeEstimate - source.truthRangeM;
    angleError = trials.musicThetaDeg(:, configurationIndex) ...
        - source.truthThetaDeg;
    rangeRatio = zeros(size(snrValuesDb));
    angleRatio = zeros(size(snrValuesDb));
    for snrIndex = 1:numel(snrValuesDb)
        chosen = source.snrDb == snrValuesDb(snrIndex);
        rangeRatio(snrIndex) = mean(rangeError(chosen).^2) ...
            / mean(referenceRangeError(chosen).^2);
        angleRatio(snrIndex) = mean(angleError(chosen).^2) ...
            / mean(referenceAngleError(chosen).^2);
    end
    rangeRmseM(configurationIndex) = rms(rangeError);
    angleRmseDeg(configurationIndex) = rms(angleError);
    maximumRangeMseRatio(configurationIndex) = max(rangeRatio);
    maximumAngleMseRatio(configurationIndex) = max(angleRatio);
    medianRuntimeMs(configurationIndex) = median(source.frontRuntimeMs ...
        + trials.musicRuntimeMs(:, configurationIndex) ...
        + trials.profileRuntimeMs(:, configurationIndex));
    operationProxy(configurationIndex) = complexityProxy(cfg, ...
        fusionCarriers(configurationIndex), ...
        gridSizes{configurationIndex}, frontEvaluations, ...
        mean(trials.profileResponseEvaluations(:, configurationIndex)));
end
feasible = maximumRangeMseRatio <= rangeRatioLimit ...
    & maximumAngleMseRatio <= angleRatioLimit;
gridLevels = strings(numConfigurations, 1);
for configurationIndex = 1:numConfigurations
    gridLevels(configurationIndex) = ...
        strjoin(string(gridSizes{configurationIndex}), "/");
end
screen = table(configuration, fusionCarriers, gridLevels, ...
    rangeRmseM, angleRmseDeg, maximumRangeMseRatio, ...
    maximumAngleMseRatio, feasible, medianRuntimeMs, operationProxy);
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
selected.rangeMseRatioLimit = rangeRatioLimit;
selected.angleMseRatioLimit = angleRatioLimit;
end

function value = complexityProxy(cfg, fusionCarriers, gridSizes, ...
    frontResponseEvaluations, profileResponseEvaluations)
responseCost = cfg.numAntennas * cfg.numSubcarriers;
musicCost = fusionCarriers * (cfg.numSubarrays * cfg.subarraySize^2 ...
    + cfg.subarraySize^3 + sum(gridSizes.^2) * cfg.subarraySize);
value = musicCost + (frontResponseEvaluations ...
    + profileResponseEvaluations) * responseCost;
end

function [methodSummary, pairedSummary, complexitySummary, ...
    tailSummary, seedAudit] = summarizeValidation(cfg, source, trials, ...
    selected, selectedGridSizes, lambda, snrValuesDb)
lowAngleError = trials.musicThetaDeg(:, 1) - source.truthThetaDeg;
lowRangeEstimate = source.frontRangeM + lambda ...
    * (trials.profileRangeM(:, 1) - source.frontRangeM);
lowRangeError = lowRangeEstimate - source.truthRangeM;
currentAngleError = source.jointThetaDeg - source.truthThetaDeg;
currentRangeEstimate = source.frontRangeM + lambda ...
    * (source.profile1RangeM - source.frontRangeM);
currentRangeError = currentRangeEstimate - source.truthRangeM;
zhangRangeError = source.jointRangeM - source.truthRangeM;
methodNames = ["Zhang-EF-513-v1"; "Current 513 profile"; ...
    "Locked reduced-complexity profile"];
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

comparisonNames = ["Reduced complexity minus Zhang"; ...
    "Reduced complexity minus current"];
comparison = repmat(comparisonNames, numel(snrValuesDb), 1);
pairedSnrDb = repelem(snrValuesDb, numel(comparisonNames));
sampleCount = zeros(size(pairedSnrDb));
mseChangeM2 = zeros(size(pairedSnrDb));
ci95LowerM2 = zeros(size(pairedSnrDb));
ci95UpperM2 = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = source.snrDb == snrValuesDb(snrIndex);
    references = {zhangRangeError(chosen); currentRangeError(chosen)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) + comparisonIndex;
        sampleCount(row) = sum(chosen);
        [mseChangeM2(row), ci95LowerM2(row), ci95UpperM2(row)] = ...
            interval(lowRangeError(chosen), references{comparisonIndex});
    end
end
pairedSummary = table(comparison, pairedSnrDb, sampleCount, ...
    mseChangeM2, ci95LowerM2, ci95UpperM2);
pairedSummary.Properties.VariableNames{2} = 'snrDb';

currentGridSizes = [61, 41, 31];
frontEvaluations = mean(source.frontResponseEvaluations);
currentProfileEvaluations = mean(source.profile1ResponseEvaluations);
lowProfileEvaluations = mean(trials.profileResponseEvaluations(:, 1));
currentProxy = complexityProxy(cfg, 513, currentGridSizes, ...
    frontEvaluations, currentProfileEvaluations);
lowProxy = complexityProxy(cfg, selected.fusionCarriers, ...
    selectedGridSizes, frontEvaluations, lowProfileEvaluations);
complexityMethod = methodNames;
medianRuntimeMs = [median(source.frontRuntimeMs + source.musicRuntimeMs); ...
    median(source.frontRuntimeMs + source.musicRuntimeMs ...
    + source.profile1RuntimeMs); median(source.frontRuntimeMs ...
    + trials.musicRuntimeMs(:, 1) + trials.profileRuntimeMs(:, 1))];
candidateCarrierEvaluations = [513 * sum(currentGridSizes.^2); ...
    513 * sum(currentGridSizes.^2); ...
    selected.fusionCarriers * sum(selectedGridSizes.^2)];
eigendecompositionCount = [513; 513; selected.fusionCarriers];
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

tailMethod = repmat(methodNames, numel(snrValuesDb), 1);
tailSnrDb = repelem(snrValuesDb, numel(methodNames));
p95AbsErrorM = zeros(size(tailSnrDb));
maximumAbsErrorM = zeros(size(tailSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = source.snrDb == snrValuesDb(snrIndex);
    errors = {zhangRangeError(chosen); currentRangeError(chosen); ...
        lowRangeError(chosen)};
    for methodIndex = 1:numel(methodNames)
        row = (snrIndex - 1) * numel(methodNames) + methodIndex;
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
title(layout, "Round 20b nested-noise complexity tradeoff");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
