function run_round17_extended_snr_adaptive_profile
%RUN_ROUND17_EXTENDED_SNR_ADAPTIVE_PROFILE Validate from -10 to 20 dB.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round17");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 17 uses %d workers.\n", pool.NumWorkers);

cfg = configuredModel();
scan = fsjad.prepareScan(cfg);
truthThetaDeg = 15;
truthRangeM = 30;
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
rangeSeedSpacingM = 0.1;
snrValues = (-10:5:20).';
developmentSnrValues = [-10; -5; 0];
highSnrValues = [5; 10; 15; 20];
numHighPerSnr = 300;
halfWidthCandidatesM = [0.5; 1; 1.5; 2; 3];
lowLambdaCandidates = (0.75:0.025:1).';
thresholdCandidatesDb = (-8:1:0).';
slopeCandidatesDb = [0.5; 1; 2; 3];

round15 = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round15", "profile_range_transfer.mat"), "validation");
round16 = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round16", "expanded_profile_large_mc.mat"), "calibration");
development = prepareDevelopment(cfg, scan, truthResponse, signalPower, ...
    round15.validation, round16.calibration, halfWidthCandidatesM, ...
    rangeSeedSpacingM, truthThetaDeg, truthRangeM, outputFolder);
[selected, calibrationScreen] = calibrateAdaptiveRule(development, ...
    developmentSnrValues, halfWidthCandidatesM, lowLambdaCandidates, ...
    thresholdCandidatesDb, slopeCandidatesDb);
stability = crossValidatedStability(development, developmentSnrValues, ...
    halfWidthCandidatesM, lowLambdaCandidates, thresholdCandidatesDb, ...
    slopeCandidatesDb);
nearOptimal = summarizeNearOptimal(calibrationScreen, selected);
writetable(calibrationScreen, fullfile(outputFolder, ...
    "adaptive_profile_calibration_screen.csv"));
writetable(selected, fullfile(outputFolder, ...
    "adaptive_profile_selected_rule.csv"));
writetable(stability, fullfile(outputFolder, ...
    "adaptive_profile_parameter_stability.csv"));
writetable(nearOptimal, fullfile(outputFolder, ...
    "adaptive_profile_near_optimal.csv"));

round12 = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round12", "snr_release_large_validation.mat"), "combined");
round16Locked = load(fullfile(projectFolder, "results", ...
    "full_spectrum", "round16", ...
    "expanded_profile_large_mc.mat"), "validation");
low = prepareLockedLow(cfg, scan, truthResponse, signalPower, ...
    round12.combined, round16Locked.validation, selected, ...
    rangeSeedSpacingM, truthThetaDeg, truthRangeM, outputFolder);
high = runHighSnrTrials(cfg, scan, truthResponse, signalPower, ...
    highSnrValues, numHighPerSnr, fusionCarriers, frontOffsetsDeg, ...
    selected, rangeSeedSpacingM, truthThetaDeg, truthRangeM, ...
    projectFolder, outputFolder);
combined = concatenateTrials(low, high);
[details, methodSummary, pairwise, mechanism, seedAudit] = ...
    summarizeResults(combined, snrValues);
writetable(details, fullfile(outputFolder, ...
    "extended_snr_validation_details.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "extended_snr_method_summary.csv"));
writetable(pairwise, fullfile(outputFolder, ...
    "extended_snr_pairwise.csv"));
writetable(mechanism, fullfile(outputFolder, ...
    "extended_snr_mechanism_summary.csv"));
writetable(seedAudit, fullfile(outputFolder, ...
    "extended_snr_seed_audit.csv"));
save(fullfile(outputFolder, "extended_snr_adaptive_profile.mat"), ...
    "development", "selected", "calibrationScreen", "stability", ...
    "nearOptimal", "low", "high", "combined", "details", ...
    "methodSummary", "pairwise", "mechanism", "seedAudit", ...
    "snrValues", "numHighPerSnr", "halfWidthCandidatesM", ...
    "lowLambdaCandidates", "thresholdCandidatesDb", ...
    "slopeCandidatesDb", "rangeSeedSpacingM", "cfg");
plotResults(methodSummary, mechanism, fullfile(outputFolder, ...
    "extended_snr_adaptive_profile.png"));

disp(selected);
disp(stability);
disp(nearOptimal);
disp(methodSummary);
disp(pairwise);
disp(mechanism);
disp(seedAudit);
end

function cfg = configuredModel
cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
end

function development = prepareDevelopment(cfg, scan, truthResponse, ...
    signalPower, round15, round16, halfWidthsM, seedSpacingM, ...
    truthThetaDeg, truthRangeM, outputFolder)
development = struct();
development.snrDb = round15.snrDb;
development.seed = round15.seed;
development.snrEstimateDb = round15.snrEstimateDb;
development.frontRangeErrorM = round15.frontRangeErrorM;
development.jointRangeErrorM = round15.jointRangeErrorM;
development.noHarmRangeErrorM = round15.noHarmRangeErrorM;
numRows = numel(development.snrDb);
numWidths = numel(halfWidthsM);
checkpointFile = fullfile(outputFolder, ...
    "adaptive_profile_development_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    development.profileRangeErrorM = checkpoint.profileRangeErrorM;
    development.profileBoundary = checkpoint.profileBoundary;
    completedRows = checkpoint.completedRows;
else
    profileRangeErrorM = zeros(numRows, numWidths);
    profileBoundary = false(numRows, numWidths);
    profileRangeErrorM(:, 1:2) = round16.profileRangeErrorM(:, 3:4);
    profileBoundary(:, 1:2) = round16.profileBoundary(:, 3:4);
    development.profileRangeErrorM = profileRangeErrorM;
    development.profileBoundary = profileBoundary;
    completedRows = 0;
end
batchSize = 24;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    newError = zeros(numel(rows), numWidths - 2);
    newBoundary = false(numel(rows), numWidths - 2);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        observation = regenerateObservation(cfg, truthResponse, ...
            signalPower, development.snrDb(row), development.seed(row));
        thetaDeg = truthThetaDeg + round15.jointAngleErrorDeg(row);
        centerM = truthRangeM + development.frontRangeErrorM(row);
        trialError = zeros(1, numWidths - 2);
        trialBoundary = false(1, numWidths - 2);
        for newIndex = 1:numWidths - 2
            widthIndex = newIndex + 2;
            seedsM = localRangeSeeds(cfg, centerM, ...
                halfWidthsM(widthIndex), seedSpacingM);
            profile = fsjad.profileRangeAtAngle( ...
                cfg, observation, thetaDeg, scan, seedsM);
            trialError(newIndex) = profile.rangeM - truthRangeM;
            trialBoundary(newIndex) = isProfileBoundary( ...
                profile.rangeM, seedsM, seedSpacingM);
        end
        newError(batchIndex, :) = trialError;
        newBoundary(batchIndex, :) = trialBoundary;
    end
    development.profileRangeErrorM(rows, 3:end) = newError;
    development.profileBoundary(rows, 3:end) = newBoundary;
    completedRows = rows(end);
    profileRangeErrorM = development.profileRangeErrorM; %#ok<NASGU>
    profileBoundary = development.profileBoundary; %#ok<NASGU>
    save(checkpointFile, "profileRangeErrorM", "profileBoundary", ...
        "completedRows", "halfWidthsM", "seedSpacingM");
    fprintf("Round 17 development rows %d/%d complete.\n", ...
        completedRows, numRows);
end
end

function [selected, screen] = calibrateAdaptiveRule(development, ...
    snrValues, halfWidthsM, lowValues, thresholdValues, slopeValues)
numCandidates = numel(halfWidthsM) * numel(lowValues) ...
    * numel(thresholdValues) * numel(slopeValues);
halfWidthM = zeros(numCandidates, 1);
lowLambda = zeros(numCandidates, 1);
thresholdDb = zeros(numCandidates, 1);
slopeDb = zeros(numCandidates, 1);
meanRelativeMse = zeros(numCandidates, 1);
maximumRelativeMse = zeros(numCandidates, 1);
meanLambda = zeros(numCandidates, 1);
relativeMse = zeros(numCandidates, numel(snrValues));
row = 0;
for widthIndex = 1:numel(halfWidthsM)
    delta = development.profileRangeErrorM(:, widthIndex) ...
        - development.frontRangeErrorM;
    for lowIndex = 1:numel(lowValues)
        for thresholdIndex = 1:numel(thresholdValues)
            for slopeIndex = 1:numel(slopeValues)
                row = row + 1;
                lambda = fsjad.profileSnrLambda( ...
                    development.snrEstimateDb, lowValues(lowIndex), ...
                    thresholdValues(thresholdIndex), ...
                    slopeValues(slopeIndex));
                errorM = development.frontRangeErrorM + lambda .* delta;
                for snrIndex = 1:numel(snrValues)
                    chosen = development.snrDb == snrValues(snrIndex);
                    referenceMse = mean( ...
                        development.noHarmRangeErrorM(chosen).^2);
                    relativeMse(row, snrIndex) = ...
                        mean(errorM(chosen).^2) / referenceMse;
                end
                halfWidthM(row) = halfWidthsM(widthIndex);
                lowLambda(row) = lowValues(lowIndex);
                thresholdDb(row) = thresholdValues(thresholdIndex);
                slopeDb(row) = slopeValues(slopeIndex);
                meanRelativeMse(row) = mean(relativeMse(row, :));
                maximumRelativeMse(row) = max(relativeMse(row, :));
                meanLambda(row) = mean(lambda);
            end
        end
    end
end
screen = table(halfWidthM, lowLambda, thresholdDb, slopeDb, ...
    meanRelativeMse, maximumRelativeMse, meanLambda);
for snrIndex = 1:numel(snrValues)
    screen.("relativeMseSnr" + string(snrIndex)) = ...
        relativeMse(:, snrIndex);
end
feasible = screen.maximumRelativeMse <= 1.02;
ranking = sortrows(screen(feasible, :), ...
    ["meanRelativeMse", "maximumRelativeMse", "halfWidthM"], ...
    ["ascend", "ascend", "ascend"]);
selected = ranking(1, :);
end

function stability = crossValidatedStability(development, snrValues, ...
    halfWidthsM, lowValues, thresholdValues, slopeValues)
numFolds = 5;
fold = (1:numFolds).';
halfWidthM = zeros(numFolds, 1);
lowLambda = zeros(numFolds, 1);
thresholdDb = zeros(numFolds, 1);
slopeDb = zeros(numFolds, 1);
meanRelativeMse = zeros(numFolds, 1);
maximumRelativeMse = zeros(numFolds, 1);
foldIndex = mod((0:numel(development.snrDb) - 1).', numFolds) + 1;
for foldNumber = 1:numFolds
    chosen = foldIndex ~= foldNumber;
    train = subsetStruct(development, chosen);
    [selected, ~] = calibrateAdaptiveRule(train, snrValues, ...
        halfWidthsM, lowValues, thresholdValues, slopeValues);
    halfWidthM(foldNumber) = selected.halfWidthM;
    lowLambda(foldNumber) = selected.lowLambda;
    thresholdDb(foldNumber) = selected.thresholdDb;
    slopeDb(foldNumber) = selected.slopeDb;
    meanRelativeMse(foldNumber) = selected.meanRelativeMse;
    maximumRelativeMse(foldNumber) = selected.maximumRelativeMse;
end
stability = table(fold, halfWidthM, lowLambda, thresholdDb, ...
    slopeDb, meanRelativeMse, maximumRelativeMse);
end

function subset = subsetStruct(source, chosen)
subset = source;
fields = string(fieldnames(source));
for field = fields.'
    value = source.(field);
    if size(value, 1) == numel(chosen)
        subset.(field) = value(chosen, :);
    end
end
end

function summary = summarizeNearOptimal(screen, selected)
eligible = screen.maximumRelativeMse <= 1.02 ...
    & screen.meanRelativeMse <= 1.01 * selected.meanRelativeMse;
near = screen(eligible, :);
candidateCount = height(near);
minimumHalfWidthM = min(near.halfWidthM);
maximumHalfWidthM = max(near.halfWidthM);
minimumLowLambda = min(near.lowLambda);
maximumLowLambda = max(near.lowLambda);
minimumThresholdDb = min(near.thresholdDb);
maximumThresholdDb = max(near.thresholdDb);
minimumSlopeDb = min(near.slopeDb);
maximumSlopeDb = max(near.slopeDb);
summary = table(candidateCount, minimumHalfWidthM, maximumHalfWidthM, ...
    minimumLowLambda, maximumLowLambda, minimumThresholdDb, ...
    maximumThresholdDb, minimumSlopeDb, maximumSlopeDb);
end

function low = prepareLockedLow(cfg, scan, truthResponse, signalPower, ...
    locked, round16, selected, seedSpacingM, truthThetaDeg, ...
    truthRangeM, outputFolder)
low = round16;
low.seed = locked.baseSeed;
low.snrEstimateDb = (locked.frontSnrDb + locked.snapshotSnrDb) / 2;
low.profileRangeErrorM = recomputeLockedProfilesIfNeeded( ...
    cfg, scan, truthResponse, signalPower, locked, round16, ...
    selected.halfWidthM, seedSpacingM, truthThetaDeg, truthRangeM, ...
    outputFolder);
lambda = fsjad.profileSnrLambda(low.snrEstimateDb, ...
    selected.lowLambda, selected.thresholdDb, selected.slopeDb);
low.lambda = lambda;
low.selectedRangeErrorM = low.frontRangeErrorM + lambda ...
    .* (low.profileRangeErrorM - low.frontRangeErrorM);
low.profileBoundary = false(size(low.snrDb));
end

function profileError = recomputeLockedProfilesIfNeeded( ...
    cfg, scan, truthResponse, signalPower, locked, round16, ...
    halfWidthM, seedSpacingM, truthThetaDeg, truthRangeM, outputFolder)
if abs(halfWidthM - 1) < eps
    profileError = round16.profileRangeErrorM;
    return;
end
numRows = numel(locked.snrDb);
checkpointFile = fullfile(outputFolder, ...
    "adaptive_profile_low_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    profileError = checkpoint.profileError;
    completedRows = checkpoint.completedRows;
    assert(abs(checkpoint.halfWidthM - halfWidthM) < eps, ...
        "fsjad:Round17LowWidthMismatch");
else
    profileError = zeros(numRows, 1);
    completedRows = 0;
end
batchSize = 48;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batchError = zeros(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        observation = regenerateObservation(cfg, truthResponse, ...
            signalPower, locked.snrDb(row), locked.baseSeed(row));
        centerM = truthRangeM + locked.frontRangeErrorM(row);
        seedsM = localRangeSeeds(cfg, centerM, halfWidthM, seedSpacingM);
        profile = fsjad.profileRangeAtAngle(cfg, observation, ...
            truthThetaDeg + locked.musicAngleErrorDeg(row), scan, seedsM);
        batchError(batchIndex) = profile.rangeM - truthRangeM;
    end
    profileError(rows) = batchError;
    completedRows = rows(end);
    save(checkpointFile, "profileError", "completedRows", ...
        "halfWidthM", "seedSpacingM");
    fprintf("Round 17 locked low rows %d/%d complete.\n", ...
        completedRows, numRows);
end
end

function high = runHighSnrTrials(cfg, scan, truthResponse, signalPower, ...
    snrValues, numPerSnr, fusionCarriers, frontOffsetsDeg, selected, ...
    seedSpacingM, truthThetaDeg, truthRangeM, projectFolder, outputFolder)
high.snrDb = repelem(snrValues, numPerSnr);
numRows = numel(high.snrDb);
high.seed = 20360000 + (1:numRows).';
fields = ["frontAngleErrorDeg", "frontRangeErrorM", ...
    "jointAngleErrorDeg", "jointRangeErrorM", ...
    "noHarmRangeErrorM", "profileRangeErrorM", ...
    "selectedRangeErrorM", "snrEstimateDb", "lambda"];
checkpointFile = fullfile(outputFolder, ...
    "adaptive_profile_high_300_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    high = checkpoint.high;
    completedRows = checkpoint.completedRows;
else
    for field = fields
        high.(field) = zeros(numRows, 1);
    end
    high.profileBoundary = false(numRows, 1);
    completedRows = 0;
end
rule = readtable(fullfile(projectFolder, "results", "full_spectrum", ...
    "round13", "noharm_release_selected_rule.csv"));
batchSize = 24;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        batch{batchIndex} = simulateTrial(cfg, scan, truthResponse, ...
            signalPower, high.snrDb(row), high.seed(row), ...
            fusionCarriers, frontOffsetsDeg, selected, seedSpacingM, ...
            truthThetaDeg, truthRangeM, rule);
    end
    for batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        for field = fields
            high.(field)(row) = batch{batchIndex}.(field);
        end
        high.profileBoundary(row) = batch{batchIndex}.profileBoundary;
    end
    completedRows = rows(end);
    save(checkpointFile, "high", "completedRows", "selected", ...
        "snrValues", "numPerSnr", "seedSpacingM");
    fprintf("Round 17 high-SNR rows %d/%d complete.\n", ...
        completedRows, numRows);
end
end

function result = simulateTrial(cfg, scan, truthResponse, signalPower, ...
    snrDb, seed, fusionCarriers, frontOffsetsDeg, selected, ...
    seedSpacingM, truthThetaDeg, truthRangeM, rule)
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
front = fsjad.angleMultistartProfileEstimate( ...
    cfg, observation, scan, frontOffsetsDeg);
snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, truthRangeM, ...
    snrDb, carrierIndex, stream);
joint = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);
diagnostics = fsjad.fittedSnrDiagnostics(cfg, observation, ...
    snapshots, carrierIndex, front, joint, scan);
snrEstimateDb = (diagnostics.frontSnrDb + diagnostics.snapshotSnrDb) / 2;
alpha = fsjad.snrReleasedAlpha(snrEstimateDb, rule.thresholdDb, ...
    rule.slopeDb, rule.saturationDb);
frontError = front.rangeM - truthRangeM;
jointError = joint.rangeM - truthRangeM;
seedsM = localRangeSeeds( ...
    cfg, front.rangeM, selected.halfWidthM, seedSpacingM);
profile = fsjad.profileRangeAtAngle( ...
    cfg, observation, joint.thetaDeg, scan, seedsM);
profileError = profile.rangeM - truthRangeM;
lambda = fsjad.profileSnrLambda(snrEstimateDb, selected.lowLambda, ...
    selected.thresholdDb, selected.slopeDb);
result.frontAngleErrorDeg = front.thetaDeg - truthThetaDeg;
result.frontRangeErrorM = frontError;
result.jointAngleErrorDeg = joint.thetaDeg - truthThetaDeg;
result.jointRangeErrorM = jointError;
result.noHarmRangeErrorM = frontError + alpha * (jointError - frontError);
result.profileRangeErrorM = profileError;
result.selectedRangeErrorM = frontError + lambda * (profileError - frontError);
result.snrEstimateDb = snrEstimateDb;
result.lambda = lambda;
result.profileBoundary = isProfileBoundary( ...
    profile.rangeM, seedsM, seedSpacingM);
end

function combined = concatenateTrials(low, high)
fields = string(fieldnames(high));
combined = struct();
for field = fields.'
    combined.(field) = [low.(field); high.(field)];
end
end

function [details, methodSummary, pairwise, mechanism, seedAudit] = ...
    summarizeResults(trials, snrValues)
details = struct2table(trials);
methodNames = ["Enhanced full-spectrum front"; ...
    "Zhang-style joint 2-D MUSIC"; "No-harm SNR release"; ...
    "Fixed 0.9 profile"; "Direct MUSIC-angle profile"; ...
    "Adaptive profile rule"];
numMethods = numel(methodNames);
method = repmat(methodNames, numel(snrValues), 1);
snrDb = repelem(snrValues, numMethods);
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValues)
    chosen = trials.snrDb == snrValues(snrIndex);
    rows = (snrIndex - 1) * numMethods + (1:numMethods);
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(trials.frontAngleErrorDeg(chosen)); ...
        repmat(rms(trials.jointAngleErrorDeg(chosen)), 5, 1)];
    fixedError = trials.frontRangeErrorM(chosen) + 0.9 ...
        * (trials.profileRangeErrorM(chosen) ...
        - trials.frontRangeErrorM(chosen));
    rangeRmseM(rows) = [rms(trials.frontRangeErrorM(chosen)); ...
        rms(trials.jointRangeErrorM(chosen)); ...
        rms(trials.noHarmRangeErrorM(chosen)); ...
        rms(fixedError); ...
        rms(trials.profileRangeErrorM(chosen)); ...
        rms(trials.selectedRangeErrorM(chosen))];
end
methodSummary = table(method, snrDb, sampleCount, ...
    angleRmseDeg, rangeRmseM);

referenceNames = ["Zhang-style joint 2-D MUSIC"; ...
    "Enhanced full-spectrum front"; "No-harm SNR release"; ...
    "Fixed 0.9 profile"];
comparisonNames = ["Adaptive profile minus " + referenceNames; ...
    "Fixed 0.9 profile minus Zhang-style joint 2-D MUSIC"];
comparison = repmat(comparisonNames, numel(snrValues), 1);
numComparisons = numel(comparisonNames);
pairedSnrDb = repelem(snrValues, numComparisons);
mseChange = zeros(size(pairedSnrDb));
ci95Lower = zeros(size(pairedSnrDb));
ci95Upper = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValues)
    chosen = trials.snrDb == snrValues(snrIndex);
    references = {trials.jointRangeErrorM(chosen); ...
        trials.frontRangeErrorM(chosen); ...
        trials.noHarmRangeErrorM(chosen); ...
        trials.frontRangeErrorM(chosen) + 0.9 ...
        * (trials.profileRangeErrorM(chosen) ...
        - trials.frontRangeErrorM(chosen))};
    for referenceIndex = 1:numel(referenceNames)
        row = (snrIndex - 1) * numComparisons + referenceIndex;
        [mseChange(row), ci95Lower(row), ci95Upper(row)] = interval( ...
            trials.selectedRangeErrorM(chosen), ...
            references{referenceIndex});
    end
    row = snrIndex * numComparisons;
    [mseChange(row), ci95Lower(row), ci95Upper(row)] = interval( ...
        references{4}, references{1});
end
pairwise = table(comparison, pairedSnrDb, mseChange, ...
    ci95Lower, ci95Upper);
pairwise.Properties.VariableNames{2} = 'snrDb';

mechanismSnrDb = snrValues;
mechanismSampleCount = zeros(size(snrValues));
meanLambda = zeros(size(snrValues));
profileBoundaryRate = zeros(size(snrValues));
improveVsZhangRate = zeros(size(snrValues));
improveVsFrontRate = zeros(size(snrValues));
for snrIndex = 1:numel(snrValues)
    chosen = trials.snrDb == snrValues(snrIndex);
    mechanismSampleCount(snrIndex) = sum(chosen);
    meanLambda(snrIndex) = mean(trials.lambda(chosen));
    profileBoundaryRate(snrIndex) = mean(trials.profileBoundary(chosen));
    improveVsZhangRate(snrIndex) = mean( ...
        trials.selectedRangeErrorM(chosen).^2 ...
        < trials.jointRangeErrorM(chosen).^2);
    improveVsFrontRate(snrIndex) = mean( ...
        trials.selectedRangeErrorM(chosen).^2 ...
        < trials.frontRangeErrorM(chosen).^2);
end
mechanism = table(mechanismSnrDb, mechanismSampleCount, meanLambda, ...
    profileBoundaryRate, improveVsZhangRate, improveVsFrontRate);
mechanism.Properties.VariableNames(1:2) = {'snrDb', 'sampleCount'};
fixedError = trials.frontRangeErrorM + 0.9 ...
    * (trials.profileRangeErrorM - trials.frontRangeErrorM);
adaptiveAudit = favorableSeedAudit(trials, snrValues, ...
    trials.selectedRangeErrorM, trials.lambda, "Adaptive profile");
fixedAudit = favorableSeedAudit( ...
    trials, snrValues, fixedError, ...
    0.9 * ones(size(fixedError)), "Fixed 0.9 profile");
seedAudit = [fixedAudit; adaptiveAudit];
end

function audit = favorableSeedAudit( ...
    trials, snrValues, methodErrorM, methodLambda, methodName)
auditTypeNames = ["Minimum absolute error"; "Maximum gain over Zhang"];
numRows = numel(snrValues) * numel(auditTypeNames) + 2;
method = repmat(methodName, numRows, 1);
scope = strings(numRows, 1);
auditType = strings(numRows, 1);
snrDb = zeros(numRows, 1);
seed = zeros(numRows, 1);
oursAbsErrorM = zeros(numRows, 1);
frontAbsErrorM = zeros(numRows, 1);
zhangAbsErrorM = zeros(numRows, 1);
gainOverZhangMse = zeros(numRows, 1);
lambda = zeros(numRows, 1);
row = 0;
for snrIndex = 1:numel(snrValues)
    chosenRows = find(trials.snrDb == snrValues(snrIndex));
    [~, minimumIndex] = min(abs(methodErrorM(chosenRows)));
    gain = trials.jointRangeErrorM(chosenRows).^2 ...
        - methodErrorM(chosenRows).^2;
    [~, gainIndex] = max(gain);
    indices = [chosenRows(minimumIndex); chosenRows(gainIndex)];
    for typeIndex = 1:2
        row = row + 1;
        [scope(row), auditType(row), snrDb(row), seed(row), ...
            oursAbsErrorM(row), frontAbsErrorM(row), ...
            zhangAbsErrorM(row), gainOverZhangMse(row), lambda(row)] = ...
            seedRow("Per SNR", auditTypeNames(typeIndex), ...
            trials, methodErrorM, methodLambda, indices(typeIndex));
    end
end
[~, minimumIndex] = min(abs(methodErrorM));
gain = trials.jointRangeErrorM.^2 - methodErrorM.^2;
[~, gainIndex] = max(gain);
indices = [minimumIndex; gainIndex];
for typeIndex = 1:2
    row = row + 1;
    [scope(row), auditType(row), snrDb(row), seed(row), ...
        oursAbsErrorM(row), frontAbsErrorM(row), ...
        zhangAbsErrorM(row), gainOverZhangMse(row), lambda(row)] = ...
        seedRow("All SNR", auditTypeNames(typeIndex), ...
        trials, methodErrorM, methodLambda, indices(typeIndex));
end
audit = table(method, scope, auditType, snrDb, seed, oursAbsErrorM, ...
    frontAbsErrorM, zhangAbsErrorM, gainOverZhangMse, lambda);
end

function [scope, auditType, snrDb, seed, oursAbsErrorM, ...
    frontAbsErrorM, zhangAbsErrorM, gainMse, lambda] = ...
    seedRow(scopeValue, typeValue, trials, methodErrorM, ...
    methodLambda, index)
scope = scopeValue;
auditType = typeValue;
snrDb = trials.snrDb(index);
seed = trials.seed(index);
oursAbsErrorM = abs(methodErrorM(index));
frontAbsErrorM = abs(trials.frontRangeErrorM(index));
zhangAbsErrorM = abs(trials.jointRangeErrorM(index));
gainMse = trials.jointRangeErrorM(index)^2 - methodErrorM(index)^2;
lambda = methodLambda(index);
end

function observation = regenerateObservation( ...
    cfg, truthResponse, signalPower, snrDb, seed)
noiseVariance = signalPower / 10^(snrDb / 10);
stream = RandStream("mt19937ar", Seed=seed);
beta = exp(1i * 2 * pi * rand(stream));
noise = sqrt(noiseVariance / 2) * (randn(stream, ...
    cfg.numSubcarriers, 1) + 1i * randn(stream, ...
    cfg.numSubcarriers, 1));
observation = beta * truthResponse + noise;
end

function seedsM = localRangeSeeds(cfg, centerM, halfWidthM, spacingM)
lowerM = max(cfg.rangeLimitsM(1), centerM - halfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerM + halfWidthM);
numIntervals = max(1, ceil((upperM - lowerM) / spacingM));
seedsM = linspace(lowerM, upperM, numIntervals + 1).';
end

function boundary = isProfileBoundary(rangeM, seedsM, spacingM)
toleranceM = max(1e-6, spacingM * 1e-3);
boundary = rangeM - seedsM(1) <= toleranceM ...
    || seedsM(end) - rangeM <= toleranceM;
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

function plotResults(summary, mechanism, outputFile)
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
        summary.rangeRmseM(chosen), "-o", "LineWidth", 1.1);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Range RMSE (m)");
legend(axisHandle, methods, "Location", "best");

axisHandle = nexttile(layout);
yyaxis(axisHandle, "left");
plot(axisHandle, mechanism.snrDb, mechanism.meanLambda, ...
    "-o", "LineWidth", 1.2);
ylabel(axisHandle, "Mean adaptive lambda");
ylim(axisHandle, [0.7, 1.02]);
yyaxis(axisHandle, "right");
plot(axisHandle, mechanism.snrDb, mechanism.improveVsZhangRate, ...
    "-s", "LineWidth", 1.2);
ylabel(axisHandle, "Improvement rate vs Zhang");
ylim(axisHandle, [0, 1]);
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
