function run_round15_profile_range_transfer
%RUN_ROUND15_PROFILE_RANGE_TRANSFER Transfer MUSIC angle gain to range ML.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round15");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 15 uses %d workers.\n", pool.NumWorkers);

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
snrValues = [-10; -5; 0];
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
halfWidthCandidatesM = [0.005; 0.01; 0.02; 0.05; 0.1; 0.2];
lambdaCandidates = (0:0.1:1).';
calibrationCountPerSnr = 60;
validationCountPerSnr = 180;
rule = readtable(fullfile(projectFolder, "results", ...
    "full_spectrum", "round13", ...
    "noharm_release_selected_rule.csv"));

calibration = runCalibration(cfg, scan, snrValues, ...
    calibrationCountPerSnr, fusionCarriers, frontOffsetsDeg, ...
    halfWidthCandidatesM, rule, outputFolder);
[selected, calibrationScreen] = selectRule(calibration, snrValues, ...
    halfWidthCandidatesM, lambdaCandidates);
writetable(calibrationScreen, fullfile(outputFolder, ...
    "profile_range_calibration_screen.csv"));
writetable(selected, fullfile(outputFolder, ...
    "profile_range_selected_rule.csv"));

validation = runValidation(cfg, scan, snrValues, ...
    validationCountPerSnr, fusionCarriers, frontOffsetsDeg, ...
    selected.halfWidthM, selected.lambda, rule, outputFolder);
[details, methodSummary, pairedSummary, mechanismSummary] = ...
    summarizeValidation(validation, snrValues);
writetable(details, fullfile(outputFolder, ...
    "profile_range_validation_details.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "profile_range_method_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, ...
    "profile_range_paired_summary.csv"));
writetable(mechanismSummary, fullfile(outputFolder, ...
    "profile_range_mechanism_summary.csv"));
save(fullfile(outputFolder, "profile_range_transfer.mat"), ...
    "calibration", "validation", "selected", ...
    "calibrationScreen", "details", "methodSummary", ...
    "pairedSummary", "mechanismSummary", "snrValues", ...
    "fusionCarriers", "frontOffsetsDeg", "halfWidthCandidatesM", ...
    "lambdaCandidates", "calibrationCountPerSnr", ...
    "validationCountPerSnr", "rule", "cfg");
disp(selected);
disp(methodSummary);
disp(pairedSummary);
disp(mechanismSummary);
end

function calibration = runCalibration(cfg, scan, snrValues, ...
    countPerSnr, fusionCarriers, frontOffsetsDeg, halfWidthsM, rule, ...
    outputFolder)
snrDb = repelem(snrValues, countPerSnr);
seed = 20310000 + (1:numel(snrDb)).';
checkpointFile = fullfile(outputFolder, ...
    "profile_range_calibration_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    calibration = checkpoint.calibration;
    completedRows = checkpoint.completedRows;
else
    calibration = initializeCalibration(snrDb, seed, numel(halfWidthsM));
    completedRows = 0;
end
batchSize = 12;
for batchStart = completedRows + 1:batchSize:numel(snrDb)
    rows = batchStart:min(batchStart + batchSize - 1, numel(snrDb));
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        batch{batchIndex} = calibrationTrial(cfg, scan, snrDb(row), ...
            fusionCarriers, frontOffsetsDeg, seed(row), halfWidthsM, rule);
    end
    calibration = storeCalibration(calibration, rows, batch);
    completedRows = rows(end);
    save(checkpointFile, "calibration", "completedRows", ...
        "snrValues", "countPerSnr", "fusionCarriers", ...
        "frontOffsetsDeg", "halfWidthsM", "rule", "cfg");
    fprintf("Round 15 calibration rows %d/%d complete.\n", ...
        completedRows, numel(snrDb));
end
end

function calibration = initializeCalibration(snrDb, seed, numWidths)
numRows = numel(snrDb);
calibration.snrDb = snrDb;
calibration.seed = seed;
calibration.frontRangeErrorM = zeros(numRows, 1);
calibration.jointRangeErrorM = zeros(numRows, 1);
calibration.noHarmRangeErrorM = zeros(numRows, 1);
calibration.profileRangeErrorM = zeros(numRows, numWidths);
end

function calibration = storeCalibration(calibration, rows, batch)
for batchIndex = 1:numel(rows)
    row = rows(batchIndex);
    trial = batch{batchIndex};
    calibration.frontRangeErrorM(row) = trial.frontRangeErrorM;
    calibration.jointRangeErrorM(row) = trial.jointRangeErrorM;
    calibration.noHarmRangeErrorM(row) = trial.noHarmRangeErrorM;
    calibration.profileRangeErrorM(row, :) = trial.profileRangeErrorM;
end
end

function result = calibrationTrial(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, seed, halfWidthsM, rule)
base = simulateBase(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, seed);
numWidths = numel(halfWidthsM);
profileRangeErrorM = zeros(1, numWidths);
for widthIndex = 1:numWidths
    rangeSeedsM = localRangeSeeds(cfg, base.front.rangeM, ...
        halfWidthsM(widthIndex));
    profile = fsjad.profileRangeAtAngle(cfg, base.observation, ...
        base.joint.thetaDeg, scan, rangeSeedsM);
    profileRangeErrorM(widthIndex) = profile.rangeM - base.truthRangeM;
end
alpha = fsjad.snrReleasedAlpha(base.snrEstimateDb, ...
    rule.thresholdDb, rule.slopeDb, rule.saturationDb);
result.frontRangeErrorM = base.front.rangeM - base.truthRangeM;
result.jointRangeErrorM = base.joint.rangeM - base.truthRangeM;
result.noHarmRangeErrorM = result.frontRangeErrorM + alpha ...
    * (result.jointRangeErrorM - result.frontRangeErrorM);
result.profileRangeErrorM = profileRangeErrorM;
end

function [selected, screen] = selectRule(calibration, snrValues, ...
    halfWidthsM, lambdaValues)
numRows = numel(halfWidthsM) * numel(lambdaValues);
halfWidthM = repelem(halfWidthsM, numel(lambdaValues));
lambda = repmat(lambdaValues, numel(halfWidthsM), 1);
meanRelativeMse = zeros(numRows, 1);
maximumRelativeMse = zeros(numRows, 1);
relativeMseSnr1 = zeros(numRows, 1);
relativeMseSnr2 = zeros(numRows, 1);
relativeMseSnr3 = zeros(numRows, 1);
relativeColumns = {relativeMseSnr1, relativeMseSnr2, relativeMseSnr3};
for row = 1:numRows
    widthIndex = find(halfWidthsM == halfWidthM(row), 1);
    methodError = calibration.frontRangeErrorM + lambda(row) ...
        * (calibration.profileRangeErrorM(:, widthIndex) ...
        - calibration.frontRangeErrorM);
    relative = zeros(numel(snrValues), 1);
    for snrIndex = 1:numel(snrValues)
        chosen = calibration.snrDb == snrValues(snrIndex);
        referenceMse = mean(calibration.noHarmRangeErrorM(chosen).^2);
        relative(snrIndex) = mean(methodError(chosen).^2) / referenceMse;
        relativeColumns{snrIndex}(row) = relative(snrIndex);
    end
    meanRelativeMse(row) = mean(relative);
    maximumRelativeMse(row) = max(relative);
end
relativeMseSnr1 = relativeColumns{1};
relativeMseSnr2 = relativeColumns{2};
relativeMseSnr3 = relativeColumns{3};
screen = table(halfWidthM, lambda, meanRelativeMse, ...
    maximumRelativeMse, relativeMseSnr1, relativeMseSnr2, ...
    relativeMseSnr3);
feasible = screen.maximumRelativeMse <= 1.02;
if any(feasible)
    candidates = find(feasible);
    [~, localBest] = min(screen.meanRelativeMse(candidates));
    bestRow = candidates(localBest);
else
    [~, order] = sortrows([screen.maximumRelativeMse, ...
        screen.meanRelativeMse], [1, 2]);
    bestRow = order(1);
end
selected = screen(bestRow, :);
end

function validation = runValidation(cfg, scan, snrValues, ...
    countPerSnr, fusionCarriers, frontOffsetsDeg, halfWidthM, lambda, ...
    rule, outputFolder)
snrDb = repelem(snrValues, countPerSnr);
seed = 20320000 + (1:numel(snrDb)).';
checkpointFile = fullfile(outputFolder, ...
    "profile_range_validation_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    validation = checkpoint.validation;
    completedRows = checkpoint.completedRows;
else
    validation = initializeValidation(snrDb, seed);
    completedRows = 0;
end
batchSize = 12;
for batchStart = completedRows + 1:batchSize:numel(snrDb)
    rows = batchStart:min(batchStart + batchSize - 1, numel(snrDb));
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        batch{batchIndex} = validationTrial(cfg, scan, snrDb(row), ...
            fusionCarriers, frontOffsetsDeg, seed(row), ...
            halfWidthM, lambda, rule);
    end
    validation = storeValidation(validation, rows, batch);
    completedRows = rows(end);
    save(checkpointFile, "validation", "completedRows", ...
        "snrValues", "countPerSnr", "fusionCarriers", ...
        "frontOffsetsDeg", "halfWidthM", "lambda", "rule", "cfg");
    fprintf("Round 15 validation rows %d/%d complete.\n", ...
        completedRows, numel(snrDb));
end
end

function validation = initializeValidation(snrDb, seed)
numRows = numel(snrDb);
validation.snrDb = snrDb;
validation.seed = seed;
fields = ["frontAngleErrorDeg", "frontRangeErrorM", ...
    "jointAngleErrorDeg", "jointRangeErrorM", ...
    "noHarmRangeErrorM", "profileRangeErrorM", ...
    "selectedRangeErrorM", "frontAngleProfileRangeErrorM", ...
    "oracleProfileRangeErrorM", "snrEstimateDb", "alpha"];
for field = fields
    validation.(field) = zeros(numRows, 1);
end
end

function validation = storeValidation(validation, rows, batch)
fields = setdiff(string(fieldnames(validation)), ["snrDb", "seed"], ...
    "stable");
for batchIndex = 1:numel(rows)
    row = rows(batchIndex);
    trial = batch{batchIndex};
    for field = fields.'
        validation.(field)(row) = trial.(field);
    end
end
end

function result = validationTrial(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, seed, halfWidthM, lambda, rule)
base = simulateBase(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, seed);
rangeSeedsM = localRangeSeeds(cfg, base.front.rangeM, halfWidthM);
profile = fsjad.profileRangeAtAngle(cfg, base.observation, ...
    base.joint.thetaDeg, scan, rangeSeedsM);
frontAngleProfile = fsjad.profileRangeAtAngle(cfg, base.observation, ...
    base.front.thetaDeg, scan, rangeSeedsM);
oracleProfile = fsjad.profileRangeAtAngle(cfg, base.observation, ...
    base.truthThetaDeg, scan, rangeSeedsM);
frontRangeErrorM = base.front.rangeM - base.truthRangeM;
jointRangeErrorM = base.joint.rangeM - base.truthRangeM;
profileRangeErrorM = profile.rangeM - base.truthRangeM;
alpha = fsjad.snrReleasedAlpha(base.snrEstimateDb, ...
    rule.thresholdDb, rule.slopeDb, rule.saturationDb);
result.frontAngleErrorDeg = base.front.thetaDeg - base.truthThetaDeg;
result.frontRangeErrorM = frontRangeErrorM;
result.jointAngleErrorDeg = base.joint.thetaDeg - base.truthThetaDeg;
result.jointRangeErrorM = jointRangeErrorM;
result.noHarmRangeErrorM = frontRangeErrorM + alpha ...
    * (jointRangeErrorM - frontRangeErrorM);
result.profileRangeErrorM = profileRangeErrorM;
result.selectedRangeErrorM = frontRangeErrorM + lambda ...
    * (profileRangeErrorM - frontRangeErrorM);
result.frontAngleProfileRangeErrorM = ...
    frontAngleProfile.rangeM - base.truthRangeM;
result.oracleProfileRangeErrorM = oracleProfile.rangeM - base.truthRangeM;
result.snrEstimateDb = base.snrEstimateDb;
result.alpha = alpha;
end

function base = simulateBase(cfg, scan, snrDb, fusionCarriers, ...
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
front = fsjad.angleMultistartProfileEstimate( ...
    cfg, observation, scan, frontOffsetsDeg);
snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, truthRangeM, ...
    snrDb, carrierIndex, stream);
joint = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);
diagnostics = fsjad.fittedSnrDiagnostics(cfg, observation, ...
    snapshots, carrierIndex, front, joint, scan);
base.truthThetaDeg = truthThetaDeg;
base.truthRangeM = truthRangeM;
base.observation = observation;
base.front = front;
base.joint = joint;
base.snrEstimateDb = ...
    (diagnostics.frontSnrDb + diagnostics.snapshotSnrDb) / 2;
end

function rangeSeedsM = localRangeSeeds(cfg, centerM, halfWidthM)
lowerM = max(cfg.rangeLimitsM(1), centerM - halfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerM + halfWidthM);
rangeSeedsM = linspace(lowerM, upperM, 5).';
end

function [details, methodSummary, pairedSummary, mechanismSummary] = ...
    summarizeValidation(validation, snrValues)
details = struct2table(validation);
methodNames = ["Enhanced full-spectrum front"; ...
    "Front-angle range profile"; "Zhang-style joint 2-D MUSIC"; ...
    "No-harm SNR release"; "MUSIC-angle range profile"; ...
    "Selected profile shrinkage"; "Oracle-angle range profile"];
numMethods = numel(methodNames);
method = repmat(methodNames, numel(snrValues), 1);
snrDb = repelem(snrValues, numMethods);
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValues)
    chosen = validation.snrDb == snrValues(snrIndex);
    rows = (snrIndex - 1) * numMethods + (1:numMethods);
    angleRmseDeg(rows) = [repmat( ...
        rms(validation.frontAngleErrorDeg(chosen)), 2, 1); ...
        repmat(rms(validation.jointAngleErrorDeg(chosen)), 5, 1)];
    rangeRmseM(rows) = [rms(validation.frontRangeErrorM(chosen)); ...
        rms(validation.frontAngleProfileRangeErrorM(chosen)); ...
        rms(validation.jointRangeErrorM(chosen)); ...
        rms(validation.noHarmRangeErrorM(chosen)); ...
        rms(validation.profileRangeErrorM(chosen)); ...
        rms(validation.selectedRangeErrorM(chosen)); ...
        rms(validation.oracleProfileRangeErrorM(chosen))];
end
methodSummary = table(method, snrDb, angleRmseDeg, rangeRmseM);

comparisonNames = ["Selected minus Zhang-style MUSIC"; ...
    "Selected minus full-spectrum front"; ...
    "Selected minus no-harm"; ...
    "MUSIC-angle profile minus front-angle profile"; ...
    "MUSIC-angle profile minus oracle-angle profile"; ...
    "Front-angle profile minus front"];
comparison = repmat(comparisonNames, numel(snrValues), 1);
pairedSnrDb = repelem(snrValues, numel(comparisonNames));
mseChange = zeros(size(pairedSnrDb));
ci95Lower = zeros(size(pairedSnrDb));
ci95Upper = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValues)
    chosen = validation.snrDb == snrValues(snrIndex);
    pairs = {validation.selectedRangeErrorM(chosen), ...
        validation.jointRangeErrorM(chosen); ...
        validation.selectedRangeErrorM(chosen), ...
        validation.frontRangeErrorM(chosen); ...
        validation.selectedRangeErrorM(chosen), ...
        validation.noHarmRangeErrorM(chosen); ...
        validation.profileRangeErrorM(chosen), ...
        validation.frontAngleProfileRangeErrorM(chosen); ...
        validation.profileRangeErrorM(chosen), ...
        validation.oracleProfileRangeErrorM(chosen); ...
        validation.frontAngleProfileRangeErrorM(chosen), ...
        validation.frontRangeErrorM(chosen)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) + comparisonIndex;
        [mseChange(row), ci95Lower(row), ci95Upper(row)] = ...
            interval(pairs{comparisonIndex, 1}, ...
            pairs{comparisonIndex, 2});
    end
end
pairedSummary = table(comparison, pairedSnrDb, mseChange, ...
    ci95Lower, ci95Upper);
pairedSummary.Properties.VariableNames{2} = 'snrDb';

sampleCount = zeros(size(snrValues));
angleImproveRate = zeros(size(snrValues));
profileRangeImproveGivenAngleImprove = zeros(size(snrValues));
selectedRangeImproveGivenAngleImprove = zeros(size(snrValues));
profileOracleErrorCorrelation = zeros(size(snrValues));
frontProfileConsistencyRmseM = zeros(size(snrValues));
for snrIndex = 1:numel(snrValues)
    chosen = validation.snrDb == snrValues(snrIndex);
    angleImprove = validation.jointAngleErrorDeg(chosen).^2 ...
        < validation.frontAngleErrorDeg(chosen).^2;
    profileImprove = validation.profileRangeErrorM(chosen).^2 ...
        < validation.frontRangeErrorM(chosen).^2;
    selectedImprove = validation.selectedRangeErrorM(chosen).^2 ...
        < validation.frontRangeErrorM(chosen).^2;
    sampleCount(snrIndex) = sum(chosen);
    angleImproveRate(snrIndex) = mean(angleImprove);
    profileRangeImproveGivenAngleImprove(snrIndex) = ...
        mean(profileImprove(angleImprove));
    selectedRangeImproveGivenAngleImprove(snrIndex) = ...
        mean(selectedImprove(angleImprove));
    profileOracleErrorCorrelation(snrIndex) = corr( ...
        validation.profileRangeErrorM(chosen), ...
        validation.oracleProfileRangeErrorM(chosen));
    frontProfileConsistencyRmseM(snrIndex) = rms( ...
        validation.frontAngleProfileRangeErrorM(chosen) ...
        - validation.frontRangeErrorM(chosen));
end
mechanismSummary = table(snrValues, sampleCount, angleImproveRate, ...
    profileRangeImproveGivenAngleImprove, ...
    selectedRangeImproveGivenAngleImprove, ...
    profileOracleErrorCorrelation, frontProfileConsistencyRmseM);
mechanismSummary.Properties.VariableNames{1} = 'snrDb';
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
