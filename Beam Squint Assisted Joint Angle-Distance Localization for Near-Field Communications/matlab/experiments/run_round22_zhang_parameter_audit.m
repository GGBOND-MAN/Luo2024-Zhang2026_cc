function run_round22_zhang_parameter_audit
%RUN_ROUND22_ZHANG_PARAMETER_AUDIT Tune and validate the Zhang baseline.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
zhangFolder = fullfile(projectFolder, "algorithms", ...
    "zhang_reproduction");
compressedFolder = fullfile(projectFolder, "algorithms", "compressed");
addpath(projectFolder, zhangFolder, compressedFolder);
cleanupPath = onCleanup(@() rmpath( ...
    projectFolder, zhangFolder, compressedFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round22");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 22 uses %d workers.\n", pool.NumWorkers);

round21Folder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round21");
calibrationData = load(fullfile(round21Folder, ...
    "calibration_checkpoint.mat"));
validationData = load(fullfile(round21Folder, ...
    "validation_checkpoint.mat"));
cfg = calibrationData.cfg;
scan = fsjad.prepareScan(cfg);
snrValuesDb = [-10; 0; 20];
angleRmseRatioLimit = 1.15;

[screen, selected] = screenCalibration(calibrationData, ...
    snrValuesDb, angleRmseRatioLimit);
writetable(screen, fullfile(outputFolder, "calibration_screen.csv"));
writetable(selected, fullfile(outputFolder, ...
    "selected_configuration.csv"));

frozenAlgorithm = zhangEf513Config();
tunedAlgorithm = selectedAlgorithm(selected, frozenAlgorithm);
compressedAlgorithm = fsjadCompressedConfig();
assert(isequal(tunedAlgorithm, zhangEfR22TunedConfig()), ...
    "fsjad:Round22LockedConfigMismatch");
validation = runValidation(cfg, scan, validationData.design, ...
    tunedAlgorithm, frozenAlgorithm.fusionCarrierCount, outputFolder);
[summary, paired, seedAudit] = summarize(validationData.validation, ...
    validation, validationData.design, frozenAlgorithm, tunedAlgorithm, ...
    compressedAlgorithm, snrValuesDb);

protocol = table(numel(calibrationData.source.snrDb), ...
    height(validationData.design), height(screen) - 1, ...
    angleRmseRatioLimit, min(validationData.design.truthThetaDeg), ...
    max(validationData.design.truthThetaDeg), ...
    min(validationData.design.truthRangeM), ...
    max(validationData.design.truthRangeM), ...
    'VariableNames', {'calibrationSampleCount', ...
    'validationSampleCount', 'searchedCandidateCount', ...
    'angleRmseRatioLimit', 'observedAngleMinDeg', ...
    'observedAngleMaxDeg', 'observedRangeMinM', ...
    'observedRangeMaxM'});
writetable(protocol, fullfile(outputFolder, "protocol.csv"));
writetable(summary, fullfile(outputFolder, "comparison_summary.csv"));
writetable(paired, fullfile(outputFolder, "paired_summary.csv"));
writetable(seedAudit, fullfile(outputFolder, "seed_audit.csv"));
save(fullfile(outputFolder, "zhang_parameter_audit.mat"), ...
    "cfg", "screen", "selected", "frozenAlgorithm", ...
    "tunedAlgorithm", "compressedAlgorithm", "validation", ...
    "summary", "paired", "protocol", "seedAudit");
plotResults(summary, fullfile(outputFolder, ...
    "zhang_parameter_audit.png"));
disp(selected);
disp(summary);
disp(paired);
end

function [screen, selected] = screenCalibration(data, snrValuesDb, ...
    angleRmseRatioLimit)
source = data.source;
fusionCandidates = data.fusionCandidates;
gridCandidates = data.gridCandidates;
numCandidates = numel(fusionCandidates) * numel(gridCandidates);
method = strings(numCandidates + 1, 1);
fusionCarriers = zeros(numCandidates + 1, 1);
gridLevels = strings(numCandidates + 1, 1);
pooledRangeRmseM = zeros(numCandidates + 1, 1);
maximumAngleRmseRatio = zeros(numCandidates + 1, 1);
rangeRmseBySnr = zeros(numCandidates + 1, numel(snrValuesDb));
angleRmseBySnr = zeros(numCandidates + 1, numel(snrValuesDb));
baselineRangeError = source.jointRangeM - source.truthRangeM;
baselineAngleError = source.jointThetaDeg - source.truthThetaDeg;
baselineRangeRmse = groupedRmse( ...
    baselineRangeError, source.snrDb, snrValuesDb);
baselineAngleRmse = groupedRmse( ...
    baselineAngleError, source.snrDb, snrValuesDb);

row = 0;
configurationIndex = 0;
for fusionIndex = 1:numel(fusionCandidates)
    for gridIndex = 1:numel(gridCandidates)
        row = row + 1;
        configurationIndex = configurationIndex + 1;
        rangeError = data.calibration.musicRangeM(:, configurationIndex) ...
            - source.truthRangeM;
        angleError = data.calibration.musicThetaDeg(:, configurationIndex) ...
            - source.truthThetaDeg;
        method(row) = "searched";
        fusionCarriers(row) = fusionCandidates(fusionIndex);
        gridLevels(row) = strjoin(string(gridCandidates{gridIndex}), "/");
        pooledRangeRmseM(row) = rms(rangeError);
        rangeRmseBySnr(row, :) = groupedRmse( ...
            rangeError, source.snrDb, snrValuesDb);
        angleRmseBySnr(row, :) = groupedRmse( ...
            angleError, source.snrDb, snrValuesDb);
        maximumAngleRmseRatio(row) = max( ...
            angleRmseBySnr(row, :) ./ baselineAngleRmse);
    end
end
row = row + 1;
method(row) = "frozen reference";
fusionCarriers(row) = 513;
gridLevels(row) = "61/41/31";
pooledRangeRmseM(row) = rms(baselineRangeError);
rangeRmseBySnr(row, :) = baselineRangeRmse;
angleRmseBySnr(row, :) = baselineAngleRmse;
maximumAngleRmseRatio(row) = 1;
feasible = maximumAngleRmseRatio <= angleRmseRatioLimit;
screen = table(method, fusionCarriers, gridLevels, pooledRangeRmseM, ...
    maximumAngleRmseRatio, feasible, rangeRmseBySnr(:, 1), ...
    rangeRmseBySnr(:, 2), rangeRmseBySnr(:, 3), ...
    angleRmseBySnr(:, 1), angleRmseBySnr(:, 2), ...
    angleRmseBySnr(:, 3), 'VariableNames', {'method', ...
    'fusionCarriers', 'gridLevels', 'pooledRangeRmseM', ...
    'maximumAngleRmseRatio', 'feasible', 'rangeRmseNeg10', ...
    'rangeRmse0', 'rangeRmse20', 'angleRmseNeg10', ...
    'angleRmse0', 'angleRmse20'});
candidates = find(feasible);
[~, localIndex] = min(pooledRangeRmseM(candidates));
selected = screen(candidates(localIndex), :);
end

function values = groupedRmse(error, snrDb, snrValuesDb)
values = zeros(1, numel(snrValuesDb));
for snrIndex = 1:numel(snrValuesDb)
    values(snrIndex) = rms(error(snrDb == snrValuesDb(snrIndex)));
end
end

function algorithm = selectedAlgorithm(selected, frozen)
algorithm = frozen;
algorithm.version = "Zhang-EF-R22-tuned";
algorithm.fusionCarrierCount = selected.fusionCarriers;
algorithm.gridSizes = double(split(selected.gridLevels, "/")).';
end

function validation = runValidation(cfg, scan, design, algorithm, ...
    fullCarrierCount, outputFolder)
checkpointFile = fullfile(outputFolder, "validation_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.design, design) ...
        && isequal(checkpoint.algorithm, algorithm), ...
        "fsjad:Round22ValidationCheckpointMismatch");
    validation = checkpoint.validation;
    completedRows = checkpoint.completedRows;
else
    validation = initializeValidation(height(design));
    completedRows = 0;
end
batchSize = 5;
for batchStart = completedRows + 1:batchSize:height(design)
    rows = batchStart:min(batchStart + batchSize - 1, height(design));
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        batch{batchIndex} = simulateTrial(cfg, scan, design(row, :), ...
            algorithm, fullCarrierCount);
    end
    fields = string(fieldnames(validation));
    for batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        for field = fields.'
            validation.(field)(row) = batch{batchIndex}.(field);
        end
    end
    completedRows = rows(end);
    save(checkpointFile, "validation", "completedRows", "design", ...
        "algorithm", "cfg");
    fprintf("Round 22 validation rows %d/%d complete.\n", ...
        completedRows, height(design));
end
end

function validation = initializeValidation(count)
fields = ["thetaDeg", "rangeM", "runtimeMs"];
validation = struct();
for field = fields
    validation.(field) = nan(count, 1);
end
end

function result = simulateTrial(cfg, scan, designRow, algorithm, ...
    fullCarrierCount)
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(designRow.truthThetaDeg), designRow.truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
stream = RandStream("mt19937ar", Seed=designRow.seed);
noiseVariance = signalPower / 10^(designRow.snrDb / 10);
beta = exp(1i * 2 * pi * rand(stream));
noise = sqrt(noiseVariance / 2) * (randn(stream, ...
    cfg.numSubcarriers, 1) + 1i * randn(stream, ...
    cfg.numSubcarriers, 1));
observation = beta * truthResponse + noise;
[~, peakPosition] = max(abs(observation).^2);
fullCarrierIndex = fixedCountWindow(peakPosition - 1, ...
    fullCarrierCount, cfg.numSubcarriers);
fullSnapshots = jad.simulateSnapshots(cfg, designRow.truthThetaDeg, ...
    designRow.truthRangeM, designRow.snrDb, fullCarrierIndex, stream);
carrierIndex = fixedCountWindow(peakPosition - 1, ...
    algorithm.fusionCarrierCount, cfg.numSubcarriers);
positions = carrierIndex - fullCarrierIndex(1) + 1;
timer = tic;
estimate = zhangEfEstimate(cfg, observation, ...
    fullSnapshots(:, positions), carrierIndex, scan, algorithm);
result.thetaDeg = estimate.thetaDeg;
result.rangeM = estimate.rangeM;
result.runtimeMs = 1000 * toc(timer);
end

function [summary, paired, seedAudit] = summarize( ...
    reference, tuned, design, frozenAlgorithm, tunedAlgorithm, ...
    compressedAlgorithm, snrValuesDb)
currentAngleError = reference.zhangThetaDeg - design.truthThetaDeg;
currentRangeError = reference.zhangRangeM - design.truthRangeM;
tunedAngleError = tuned.thetaDeg - design.truthThetaDeg;
tunedRangeError = tuned.rangeM - design.truthRangeM;
oursAngleError = reference.compressedThetaDeg - design.truthThetaDeg;
oursRangeError = reference.compressedRangeM - design.truthRangeM;
methodNames = [frozenAlgorithm.version; tunedAlgorithm.version; ...
    compressedAlgorithm.version];
method = repmat(methodNames, numel(snrValuesDb), 1);
snrDb = repelem(snrValuesDb, numel(methodNames));
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = design.snrDb == snrValuesDb(snrIndex);
    rows = (snrIndex - 1) * numel(methodNames) + (1:numel(methodNames));
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(currentAngleError(chosen)); ...
        rms(tunedAngleError(chosen)); rms(oursAngleError(chosen))];
    rangeRmseM(rows) = [rms(currentRangeError(chosen)); ...
        rms(tunedRangeError(chosen)); rms(oursRangeError(chosen))];
end
summary = table(method, snrDb, sampleCount, angleRmseDeg, rangeRmseM);

comparisonNames = ["Tuned Zhang minus frozen Zhang"; ...
    "FSJAD compressed minus tuned Zhang"];
comparison = repmat(comparisonNames, numel(snrValuesDb), 1);
pairedSnrDb = repelem(snrValuesDb, numel(comparisonNames));
pairedCount = zeros(size(pairedSnrDb));
mseChangeM2 = zeros(size(pairedSnrDb));
ci95LowerM2 = zeros(size(pairedSnrDb));
ci95UpperM2 = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = design.snrDb == snrValuesDb(snrIndex);
    methodErrors = {tunedRangeError(chosen); oursRangeError(chosen)};
    referenceErrors = {currentRangeError(chosen); tunedRangeError(chosen)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) + comparisonIndex;
        pairedCount(row) = sum(chosen);
        [mseChangeM2(row), ci95LowerM2(row), ci95UpperM2(row)] = ...
            interval(methodErrors{comparisonIndex}, ...
            referenceErrors{comparisonIndex});
    end
end
paired = table(comparison, pairedSnrDb, pairedCount, mseChangeM2, ...
    ci95LowerM2, ci95UpperM2, 'VariableNames', {'comparison', ...
    'snrDb', 'sampleCount', 'mseChangeM2', 'ci95LowerM2', ...
    'ci95UpperM2'});

[~, bestIndex] = min(abs(tunedRangeError));
gainM2 = currentRangeError.^2 - tunedRangeError.^2;
[~, gainIndex] = max(gainM2);
auditIndex = [bestIndex; gainIndex];
auditType = ["Minimum tuned-Zhang absolute error"; ...
    "Maximum tuned-Zhang MSE gain"];
seed = design.seed(auditIndex);
auditSnrDb = design.snrDb(auditIndex);
truthThetaDeg = design.truthThetaDeg(auditIndex);
truthRangeM = design.truthRangeM(auditIndex);
tunedAbsErrorM = abs(tunedRangeError(auditIndex));
frozenAbsErrorM = abs(currentRangeError(auditIndex));
oursAbsErrorM = abs(oursRangeError(auditIndex));
seedAudit = table(auditType, seed, auditSnrDb, truthThetaDeg, ...
    truthRangeM, tunedAbsErrorM, frozenAbsErrorM, oursAbsErrorM);
seedAudit.Properties.VariableNames{3} = 'snrDb';
end

function [change, lower, upper] = interval(methodError, referenceError)
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
halfWidth = 1.96 * std(squaredChange) / sqrt(numel(squaredChange));
lower = change - halfWidth;
upper = change + halfWidth;
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function plotResults(summary, outputFile)
figureHandle = figure("Visible", "off", "Color", "w", ...
    "Position", [100, 100, 720, 460]);
axisHandle = axes(figureHandle);
axisHandle.YScale = "log";
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
title(axisHandle, "Round 22 Zhang parameter audit");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
