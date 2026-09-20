function run_parametric_bootstrap_alpha
%RUN_PARAMETRIC_BOOTSTRAP_ALPHA Validate truth-free bootstrap shrinkage.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round11");
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
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
alphaTypes = ["raw"; "conservative"; "independent"; ...
    "scaledRaw"; "scaledIndependent"];

pilotCarrierCounts = [33, 65, 129];
pilotBootstrapCount = 8;
numPilotPerSnr = 8;
pilot = runPilot(cfg, scan, snrValues, numPilotPerSnr, ...
    fusionCarriers, frontOffsetsDeg, pilotCarrierCounts, ...
    pilotBootstrapCount, alphaTypes, cfg.randomSeed + 3101, ...
    fullfile(outputFolder, "bootstrap_alpha_pilot_checkpoint.mat"));
[pilotScores, selectedPilot] = selectPilot(pilot, ...
    pilotCarrierCounts, alphaTypes);

bootstrapCounts = [4, 8, 16];
numCalibrationPerSnr = 30;
calibration = runCalibration(cfg, scan, snrValues, ...
    numCalibrationPerSnr, fusionCarriers, frontOffsetsDeg, ...
    selectedPilot.bootstrapCarrierCount, bootstrapCounts, alphaTypes, ...
    cfg.randomSeed + 3301, fullfile(outputFolder, ...
    "bootstrap_alpha_calibration_checkpoint.mat"));
[calibrationScores, selectedRule] = selectCalibration(calibration, ...
    bootstrapCounts, alphaTypes, selectedPilot.bootstrapCarrierCount);
[balancedCalibrationScores, selectedBalancedMean, ...
    selectedBalancedMinimax] = evaluateBalancedCalibration(calibration, ...
    bootstrapCounts, alphaTypes, selectedPilot.bootstrapCarrierCount, ...
    snrValues);

numValidationPerSnr = 100;
validation = runValidation(cfg, scan, snrValues, ...
    numValidationPerSnr, fusionCarriers, frontOffsetsDeg, ...
    selectedRule.bootstrapCarrierCount, selectedRule.bootstrapCount, ...
    alphaTypes, cfg.randomSeed + 3501, fullfile(outputFolder, ...
    "bootstrap_alpha_validation_checkpoint.mat"));
[validationDetails, validationSummary, pairwiseStatistics, ...
    pooledStatistics] = summarizeValidation(validation, selectedRule, ...
    alphaTypes, snrValues);
allPairwiseStatistics = compareAllMethods(validationDetails, snrValues);
paperComparison = compareWithPublished(validationSummary, snrValues);

writetable(pilotScores, fullfile(outputFolder, ...
    "bootstrap_alpha_pilot_scores.csv"));
writetable(selectedPilot, fullfile(outputFolder, ...
    "bootstrap_alpha_selected_pilot.csv"));
writetable(calibrationScores, fullfile(outputFolder, ...
    "bootstrap_alpha_calibration_scores.csv"));
writetable(selectedRule, fullfile(outputFolder, ...
    "bootstrap_alpha_selected_rule.csv"));
writetable(balancedCalibrationScores, fullfile(outputFolder, ...
    "bootstrap_alpha_calibration_balanced_scores.csv"));
writetable(selectedBalancedMean, fullfile(outputFolder, ...
    "bootstrap_alpha_selected_balanced_mean.csv"));
writetable(selectedBalancedMinimax, fullfile(outputFolder, ...
    "bootstrap_alpha_selected_balanced_minimax.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "bootstrap_alpha_validation_details.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "bootstrap_alpha_validation_summary.csv"));
writetable(pairwiseStatistics, fullfile(outputFolder, ...
    "bootstrap_alpha_pairwise_statistics.csv"));
writetable(pooledStatistics, fullfile(outputFolder, ...
    "bootstrap_alpha_pooled_statistics.csv"));
writetable(allPairwiseStatistics, fullfile(outputFolder, ...
    "bootstrap_alpha_all_pairwise_statistics.csv"));
writetable(paperComparison, fullfile(outputFolder, ...
    "bootstrap_alpha_paper_comparison.csv"));
save(fullfile(outputFolder, "bootstrap_alpha_experiment.mat"), ...
    "cfg", "snrValues", "fusionCarriers", "frontOffsetsDeg", ...
    "alphaTypes", "pilotCarrierCounts", "pilotBootstrapCount", ...
    "numPilotPerSnr", "pilot", "pilotScores", "selectedPilot", ...
    "bootstrapCounts", "numCalibrationPerSnr", "calibration", ...
    "calibrationScores", "selectedRule", "balancedCalibrationScores", ...
    "selectedBalancedMean", "selectedBalancedMinimax", ...
    "numValidationPerSnr", ...
    "validation", "validationDetails", "validationSummary", ...
    "pairwiseStatistics", "pooledStatistics", ...
    "allPairwiseStatistics", "paperComparison");
plotResults(validationSummary, paperComparison, fullfile(outputFolder, ...
    "bootstrap_alpha_validation.png"));

disp(pilotScores);
disp(selectedPilot);
disp(calibrationScores);
disp(selectedRule);
disp(selectedBalancedMean);
disp(selectedBalancedMinimax);
disp(validationSummary);
disp(pairwiseStatistics);
disp(pooledStatistics);
disp(paperComparison);
end

function [scores, selectedMean, selectedMinimax] = ...
    evaluateBalancedCalibration(calibration, bootstrapCounts, ...
    alphaTypes, bootstrapCarrierCountValue, snrValues)
numRows = numel(bootstrapCounts) * numel(alphaTypes);
bootstrapCarrierCount = repmat(bootstrapCarrierCountValue, numRows, 1);
bootstrapCount = zeros(numRows, 1);
alphaType = strings(numRows, 1);
meanRelativeMse = zeros(numRows, 1);
maximumRelativeMse = zeros(numRows, 1);
relativeMseBySnr = zeros(numRows, numel(snrValues));
delta = calibration.musicRangeErrorM - calibration.frontRangeErrorM;
row = 0;
for countIndex = 1:numel(bootstrapCounts)
    for typeIndex = 1:numel(alphaTypes)
        row = row + 1;
        bootstrapCount(row) = bootstrapCounts(countIndex);
        alphaType(row) = alphaTypes(typeIndex);
        alpha = calibration.alpha(:, countIndex, typeIndex);
        for snrIndex = 1:numel(snrValues)
            rows = calibration.snrDb == snrValues(snrIndex);
            fusedError = calibration.frontRangeErrorM(rows) ...
                + alpha(rows) .* delta(rows);
            relativeMseBySnr(row, snrIndex) = mean(fusedError.^2) ...
                / mean(calibration.frontRangeErrorM(rows).^2);
        end
        meanRelativeMse(row) = mean(relativeMseBySnr(row, :));
        maximumRelativeMse(row) = max(relativeMseBySnr(row, :));
    end
end
scores = table(bootstrapCarrierCount, bootstrapCount, alphaType, ...
    meanRelativeMse, maximumRelativeMse);
for snrIndex = 1:numel(snrValues)
    variableName = "relativeMseSnr" + string(snrIndex);
    scores.(variableName) = relativeMseBySnr(:, snrIndex);
end
meanRanking = sortrows(scores, ...
    ["meanRelativeMse", "maximumRelativeMse"], ...
    ["ascend", "ascend"]);
minimaxRanking = sortrows(scores, ...
    ["maximumRelativeMse", "meanRelativeMse"], ...
    ["ascend", "ascend"]);
selectedMean = meanRanking(1, :);
selectedMinimax = minimaxRanking(1, :);
end

function pilot = runPilot(cfg, scan, snrValues, numPerSnr, ...
    fusionCarriers, frontOffsetsDeg, carrierCounts, bootstrapCount, ...
    alphaTypes, seedBase, checkpointFile)
numRows = numel(snrValues) * numPerSnr;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    pilot = checkpoint.pilot;
    completedRows = checkpoint.completedRows;
else
    pilot = initializeBaseTrials(snrValues, numPerSnr);
    pilot.alpha = zeros(numRows, numel(carrierCounts), numel(alphaTypes));
    completedRows = 0;
end
for row = completedRows + 1:numRows
    snrDb = pilot.snrDb(row);
    trial = simulateBaseTrial(cfg, scan, snrDb, fusionCarriers, ...
        frontOffsetsDeg, seedBase + row);
    pilot = storeBaseTrial(pilot, row, trial);
    for carrierIndex = 1:numel(carrierCounts)
        stream = RandStream("mt19937ar", Seed=seedBase + 100000 ...
            + 100 * row + carrierIndex);
        diagnostics = fsjad.parametricBootstrapShrinkage(cfg, ...
            trial.observation, trial.snapshots, trial.carrierIndex, ...
            trial.front, trial.music, scan, bootstrapCount, ...
            carrierCounts(carrierIndex), stream);
        pilot.alpha(row, carrierIndex, :) = reshape( ...
            alphaVector(diagnostics), 1, 1, []);
    end
    completedRows = row;
    save(checkpointFile, "pilot", "completedRows");
    fprintf("Bootstrap pilot row %d/%d complete.\n", row, numRows);
end
end

function [scores, selected] = selectPilot(pilot, carrierCounts, alphaTypes)
numRows = numel(carrierCounts) * numel(alphaTypes);
bootstrapCarrierCount = zeros(numRows, 1);
alphaType = strings(numRows, 1);
rangeRmseM = zeros(numRows, 1);
rangeMseChange = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1);
delta = pilot.musicRangeErrorM - pilot.frontRangeErrorM;
row = 0;
for carrierIndex = 1:numel(carrierCounts)
    for typeIndex = 1:numel(alphaTypes)
        row = row + 1;
        alpha = pilot.alpha(:, carrierIndex, typeIndex);
        fusedError = pilot.frontRangeErrorM + alpha .* delta;
        bootstrapCarrierCount(row) = carrierCounts(carrierIndex);
        alphaType(row) = alphaTypes(typeIndex);
        rangeRmseM(row) = sqrt(mean(fusedError.^2));
        rangeMseChange(row) = mean(fusedError.^2 ...
            - pilot.frontRangeErrorM.^2);
        meanAlpha(row) = mean(alpha);
    end
end
scores = table(bootstrapCarrierCount, alphaType, rangeRmseM, ...
    rangeMseChange, meanAlpha);
ranking = sortrows(scores, ["rangeRmseM", "bootstrapCarrierCount"], ...
    ["ascend", "ascend"]);
selected = ranking(1, :);
end

function calibration = runCalibration(cfg, scan, snrValues, numPerSnr, ...
    fusionCarriers, frontOffsetsDeg, bootstrapCarrierCount, ...
    bootstrapCounts, alphaTypes, seedBase, checkpointFile)
numRows = numel(snrValues) * numPerSnr;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    calibration = checkpoint.calibration;
    completedRows = checkpoint.completedRows;
else
    calibration = initializeBaseTrials(snrValues, numPerSnr);
    calibration.alpha = zeros(numRows, numel(bootstrapCounts), ...
        numel(alphaTypes));
    completedRows = 0;
end
maximumBootstrapCount = max(bootstrapCounts);
for row = completedRows + 1:numRows
    snrDb = calibration.snrDb(row);
    trial = simulateBaseTrial(cfg, scan, snrDb, fusionCarriers, ...
        frontOffsetsDeg, seedBase + row);
    calibration = storeBaseTrial(calibration, row, trial);
    stream = RandStream("mt19937ar", Seed=seedBase + 100000 + row);
    diagnostics = fsjad.parametricBootstrapShrinkage(cfg, ...
        trial.observation, trial.snapshots, trial.carrierIndex, ...
        trial.front, trial.music, scan, maximumBootstrapCount, ...
        bootstrapCarrierCount, stream);
    for countIndex = 1:numel(bootstrapCounts)
        calibration.alpha(row, countIndex, :) = reshape( ...
            alphaFromReplicates(diagnostics, ...
            bootstrapCounts(countIndex)), 1, 1, []);
    end
    completedRows = row;
    save(checkpointFile, "calibration", "completedRows");
    fprintf("Bootstrap calibration row %d/%d complete.\n", row, numRows);
end
end

function [scores, selected] = selectCalibration(calibration, ...
    bootstrapCounts, alphaTypes, bootstrapCarrierCountValue)
numRows = numel(bootstrapCounts) * numel(alphaTypes);
bootstrapCarrierCount = repmat(bootstrapCarrierCountValue, numRows, 1);
bootstrapCount = zeros(numRows, 1);
alphaType = strings(numRows, 1);
rangeRmseM = zeros(numRows, 1);
rangeMseChange = zeros(numRows, 1);
meanAlpha = zeros(numRows, 1);
delta = calibration.musicRangeErrorM - calibration.frontRangeErrorM;
row = 0;
for countIndex = 1:numel(bootstrapCounts)
    for typeIndex = 1:numel(alphaTypes)
        row = row + 1;
        alpha = calibration.alpha(:, countIndex, typeIndex);
        fusedError = calibration.frontRangeErrorM + alpha .* delta;
        bootstrapCount(row) = bootstrapCounts(countIndex);
        alphaType(row) = alphaTypes(typeIndex);
        rangeRmseM(row) = sqrt(mean(fusedError.^2));
        rangeMseChange(row) = mean(fusedError.^2 ...
            - calibration.frontRangeErrorM.^2);
        meanAlpha(row) = mean(alpha);
    end
end
scores = table(bootstrapCarrierCount, bootstrapCount, alphaType, ...
    rangeRmseM, rangeMseChange, meanAlpha);
ranking = sortrows(scores, ["rangeRmseM", "bootstrapCount"], ...
    ["ascend", "ascend"]);
selected = ranking(1, :);
end

function validation = runValidation(cfg, scan, snrValues, numPerSnr, ...
    fusionCarriers, frontOffsetsDeg, bootstrapCarrierCount, ...
    bootstrapCount, alphaTypes, seedBase, checkpointFile)
numRows = numel(snrValues) * numPerSnr;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    validation = checkpoint.validation;
    completedRows = checkpoint.completedRows;
else
    validation = initializeBaseTrials(snrValues, numPerSnr);
    validation.alpha = zeros(numRows, numel(alphaTypes));
    completedRows = 0;
end
for row = completedRows + 1:numRows
    snrDb = validation.snrDb(row);
    trial = simulateBaseTrial(cfg, scan, snrDb, fusionCarriers, ...
        frontOffsetsDeg, seedBase + row);
    validation = storeBaseTrial(validation, row, trial);
    stream = RandStream("mt19937ar", Seed=seedBase + 100000 + row);
    diagnostics = fsjad.parametricBootstrapShrinkage(cfg, ...
        trial.observation, trial.snapshots, trial.carrierIndex, ...
        trial.front, trial.music, scan, bootstrapCount, ...
        bootstrapCarrierCount, stream);
    validation.alpha(row, :) = alphaVector(diagnostics).';
    completedRows = row;
    save(checkpointFile, "validation", "completedRows");
    fprintf("Bootstrap validation row %d/%d complete.\n", row, numRows);
end
end

function trial = simulateBaseTrial(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, seed)
truthThetaDeg = 15;
truthRangeM = 30;
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
noiseVariance = signalPower / 10^(snrDb / 10);
stream = RandStream("mt19937ar", Seed=seed);
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
trial.observation = observation;
trial.snapshots = snapshots;
trial.carrierIndex = carrierIndex;
trial.front = front;
trial.music = music;
trial.frontAngleErrorDeg = front.thetaDeg - truthThetaDeg;
trial.frontRangeErrorM = front.rangeM - truthRangeM;
trial.musicAngleErrorDeg = music.thetaDeg - truthThetaDeg;
trial.musicRangeErrorM = music.rangeM - truthRangeM;
end

function trials = initializeBaseTrials(snrValues, numPerSnr)
trials.snrDb = repelem(snrValues, numPerSnr);
numRows = numel(trials.snrDb);
trials.frontAngleErrorDeg = zeros(numRows, 1);
trials.frontRangeErrorM = zeros(numRows, 1);
trials.musicAngleErrorDeg = zeros(numRows, 1);
trials.musicRangeErrorM = zeros(numRows, 1);
end

function trials = storeBaseTrial(trials, row, trial)
trials.frontAngleErrorDeg(row) = trial.frontAngleErrorDeg;
trials.frontRangeErrorM(row) = trial.frontRangeErrorM;
trials.musicAngleErrorDeg(row) = trial.musicAngleErrorDeg;
trials.musicRangeErrorM(row) = trial.musicRangeErrorM;
end

function alpha = alphaFromReplicates(diagnostics, bootstrapCount)
front = diagnostics.frontRangeReplicateM(1:bootstrapCount);
music = diagnostics.musicRangeReplicateM(1:bootstrapCount);
base = fsjad.covarianceRangeShrinkage(front, music);
carrierFraction = diagnostics.bootstrapCarrierCount ...
    / diagnostics.fullCarrierCount;
[scaledRaw, scaledIndependent] = scaledAlpha(front, music, carrierFraction);
alpha = [base.rawAlpha; base.conservativeAlpha; ...
    base.independentAlpha; scaledRaw; scaledIndependent];
end

function alpha = alphaVector(diagnostics)
alpha = [diagnostics.rawAlpha; diagnostics.conservativeAlpha; ...
    diagnostics.independentAlpha; diagnostics.scaledRawAlpha; ...
    diagnostics.scaledIndependentAlpha];
end

function [rawAlpha, independentAlpha] = scaledAlpha( ...
    frontRangeM, musicRangeM, carrierFraction)
frontCentered = frontRangeM - mean(frontRangeM);
musicCentered = musicRangeM - mean(musicRangeM);
frontVariance = mean(frontCentered.^2);
if frontVariance <= eps
    rawAlpha = 0;
    independentAlpha = 0;
    return;
end
transfer = mean(frontCentered .* musicCentered) / frontVariance;
innovation = musicCentered - transfer * frontCentered;
innovationVariance = carrierFraction * mean(innovation.^2);
musicVariance = transfer^2 * frontVariance + innovationVariance;
rawNumerator = frontVariance * (1 - transfer);
rawDenominator = frontVariance * (1 - transfer)^2 ...
    + innovationVariance;
rawAlpha = min(max(rawNumerator / max(rawDenominator, eps), 0), 1);
independentAlpha = min(max(frontVariance / ...
    max(frontVariance + musicVariance, eps), 0), 1);
end

function [details, summary, pairwise, pooled] = summarizeValidation( ...
    validation, selectedRule, alphaTypes, snrValues)
selectedTypeIndex = find(alphaTypes == selectedRule.alphaType, 1);
selectedAlpha = validation.alpha(:, selectedTypeIndex);
delta = validation.musicRangeErrorM - validation.frontRangeErrorM;
oracleAlpha = fsjad.oracleRangeShrinkage( ...
    validation.frontRangeErrorM, delta);
methodNames = ["Full-spectrum front"; "Zhang-style full MUSIC"; ...
    "Bootstrap raw"; "Bootstrap conservative"; ...
    "Bootstrap independent"; "Bootstrap scaled raw"; ...
    "Bootstrap scaled independent"; "Selected bootstrap analytic"; ...
    "Oracle shrinkage"];
alphaMatrix = [zeros(size(delta)).'; ones(size(delta)).'; ...
    validation.alpha.'; selectedAlpha.'; oracleAlpha.'];
errorMatrix = validation.frontRangeErrorM.' + alphaMatrix .* delta.';
angleMatrix = [validation.frontAngleErrorDeg.'; repmat( ...
    validation.musicAngleErrorDeg.', numel(methodNames) - 1, 1)];
numTrials = numel(delta);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(validation.snrDb, numel(methodNames));
details = table(method, snrDb, angleMatrix(:), errorMatrix(:), ...
    alphaMatrix(:), VariableNames=["method", "snrDb", ...
    "angleErrorDeg", "rangeErrorM", "alpha"]);
summary = groupMetrics(details, methodNames, snrValues);
[pairwise, pooled] = compareSelected(details, snrValues);
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
methodName = "Selected bootstrap analytic";
referenceNames = ["Full-spectrum front"; "Zhang-style full MUSIC"];
numRows = numel(referenceNames) * numel(snrValues);
reference = strings(numRows, 1);
snrDb = zeros(numRows, 1);
methodRangeRmseM = zeros(numRows, 1);
referenceRangeRmseM = zeros(numRows, 1);
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
        methodError = details.rangeErrorM(methodRows);
        referenceError = details.rangeErrorM(referenceRows);
        [change, lower, upper] = pairedMseInterval( ...
            methodError, referenceError);
        reference(row) = referenceNames(referenceIndex);
        snrDb(row) = snrValues(snrIndex);
        methodRangeRmseM(row) = sqrt(mean(methodError.^2));
        referenceRangeRmseM(row) = sqrt(mean(referenceError.^2));
        mseChange(row) = change;
        ci95LowerMseChange(row) = lower;
        ci95UpperMseChange(row) = upper;
    end
end
method = repmat(methodName, numRows, 1);
statistics = table(method, reference, snrDb, methodRangeRmseM, ...
    referenceRangeRmseM, mseChange, ci95LowerMseChange, ...
    ci95UpperMseChange);

method = repmat(methodName, numel(referenceNames), 1);
reference = referenceNames;
methodRangeRmseM = zeros(numel(referenceNames), 1);
referenceRangeRmseM = zeros(numel(referenceNames), 1);
mseChange = zeros(numel(referenceNames), 1);
ci95LowerMseChange = zeros(numel(referenceNames), 1);
ci95UpperMseChange = zeros(numel(referenceNames), 1);
for referenceIndex = 1:numel(referenceNames)
    methodError = details.rangeErrorM(details.method == methodName);
    referenceError = details.rangeErrorM( ...
        details.method == referenceNames(referenceIndex));
    [change, lower, upper] = pairedMseInterval( ...
        methodError, referenceError);
    methodRangeRmseM(referenceIndex) = sqrt(mean(methodError.^2));
    referenceRangeRmseM(referenceIndex) = sqrt(mean(referenceError.^2));
    mseChange(referenceIndex) = change;
    ci95LowerMseChange(referenceIndex) = lower;
    ci95UpperMseChange(referenceIndex) = upper;
end
pooled = table(method, reference, methodRangeRmseM, ...
    referenceRangeRmseM, mseChange, ci95LowerMseChange, ...
    ci95UpperMseChange);
end

function [change, lower, upper] = pairedMseInterval( ...
    methodError, referenceError)
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
standardError = std(squaredChange) / sqrt(numel(squaredChange));
lower = change - 1.96 * standardError;
upper = change + 1.96 * standardError;
end

function statistics = compareAllMethods(details, snrValues)
methodNames = unique(details.method, "stable");
methodNames = methodNames(3:end - 1);
referenceNames = ["Full-spectrum front"; "Zhang-style full MUSIC"];
numRows = numel(methodNames) * numel(referenceNames) ...
    * (numel(snrValues) + 1);
method = strings(numRows, 1);
reference = strings(numRows, 1);
snrDb = nan(numRows, 1);
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
            [change, lower, upper] = pairedMseInterval( ...
                details.rangeErrorM(methodRows), ...
                details.rangeErrorM(referenceRows));
            method(row) = methodNames(methodIndex);
            reference(row) = referenceNames(referenceIndex);
            snrDb(row) = snrValues(snrIndex);
            mseChange(row) = change;
            ci95LowerMseChange(row) = lower;
            ci95UpperMseChange(row) = upper;
        end
        row = row + 1;
        methodRows = details.method == methodNames(methodIndex);
        referenceRows = details.method == referenceNames(referenceIndex);
        [change, lower, upper] = pairedMseInterval( ...
            details.rangeErrorM(methodRows), ...
            details.rangeErrorM(referenceRows));
        method(row) = methodNames(methodIndex);
        reference(row) = referenceNames(referenceIndex);
        mseChange(row) = change;
        ci95LowerMseChange(row) = lower;
        ci95UpperMseChange(row) = upper;
    end
end
statistics = table(method, reference, snrDb, mseChange, ...
    ci95LowerMseChange, ci95UpperMseChange);
end

function comparison = compareWithPublished(summary, snrValues)
rows = summary.method == "Selected bootstrap analytic";
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
title(layout, "Parametric-bootstrap shrinkage validation");
exportgraphics(figureHandle, outputFile, Resolution=180);
close(figureHandle);
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end
