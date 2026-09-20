function run_round16_expanded_profile_large_mc
%RUN_ROUND16_EXPANDED_PROFILE_LARGE_MC Expand and validate range profiling.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round16");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 16 uses %d workers.\n", pool.NumWorkers);

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
truthThetaDeg = 15;
truthRangeM = 30;
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
snrValues = [-10; -5; 0];
halfWidthCandidatesM = [0.2; 0.3; 0.5; 1.0];
lambdaCandidates = (0:0.1:1).';
rangeSeedSpacingM = 0.1;

round15 = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round15", "profile_range_transfer.mat"), "validation");
development = round15.validation;
calibration = runExpandedCalibration(cfg, scan, truthResponse, ...
    signalPower, development, halfWidthCandidatesM, ...
    rangeSeedSpacingM, truthThetaDeg, truthRangeM, outputFolder);
[selected, calibrationScreen, windowSummary] = selectExpandedRule( ...
    calibration, snrValues, halfWidthCandidatesM, lambdaCandidates);
writetable(calibrationScreen, fullfile(outputFolder, ...
    "expanded_profile_calibration_screen.csv"));
writetable(windowSummary, fullfile(outputFolder, ...
    "expanded_profile_window_summary.csv"));
writetable(selected, fullfile(outputFolder, ...
    "expanded_profile_selected_rule.csv"));

round12 = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round12", "snr_release_large_validation.mat"), "combined");
locked = round12.combined;
sourceAudit = auditSources(development, locked, snrValues);
writetable(sourceAudit, fullfile(outputFolder, ...
    "expanded_profile_source_audit.csv"));
rule = readtable(fullfile(projectFolder, "results", "full_spectrum", ...
    "round13", "noharm_release_selected_rule.csv"));
validation = runLockedValidation(cfg, scan, truthResponse, signalPower, ...
    locked, selected.halfWidthM, selected.lambda, rangeSeedSpacingM, ...
    truthThetaDeg, truthRangeM, rule, outputFolder);
[details, methodSummary, pairedSummary, mechanismSummary, tailSummary] = ...
    summarizeValidation(validation, snrValues);
writetable(details, fullfile(outputFolder, ...
    "expanded_profile_validation_details.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "expanded_profile_method_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, ...
    "expanded_profile_paired_summary.csv"));
writetable(mechanismSummary, fullfile(outputFolder, ...
    "expanded_profile_mechanism_summary.csv"));
writetable(tailSummary, fullfile(outputFolder, ...
    "expanded_profile_tail_summary.csv"));
save(fullfile(outputFolder, "expanded_profile_large_mc.mat"), ...
    "calibration", "validation", "selected", ...
    "calibrationScreen", "windowSummary", "sourceAudit", ...
    "methodSummary", "pairedSummary", "mechanismSummary", ...
    "tailSummary", "snrValues", "halfWidthCandidatesM", ...
    "lambdaCandidates", "rangeSeedSpacingM", "rule", "cfg");
plotResults(methodSummary, windowSummary, fullfile(outputFolder, ...
    "expanded_profile_large_mc.png"));

disp(selected);
disp(sourceAudit);
disp(windowSummary);
disp(methodSummary);
disp(pairedSummary);
disp(mechanismSummary);
disp(tailSummary);
end

function calibration = runExpandedCalibration(cfg, scan, ...
    truthResponse, signalPower, development, halfWidthsM, seedSpacingM, ...
    truthThetaDeg, truthRangeM, outputFolder)
numRows = numel(development.snrDb);
numWidths = numel(halfWidthsM);
checkpointFile = fullfile(outputFolder, ...
    "expanded_profile_calibration_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    calibration = checkpoint.calibration;
    completedRows = checkpoint.completedRows;
else
    calibration.snrDb = development.snrDb;
    calibration.seed = development.seed;
    calibration.frontRangeErrorM = development.frontRangeErrorM;
    calibration.jointRangeErrorM = development.jointRangeErrorM;
    calibration.noHarmRangeErrorM = development.noHarmRangeErrorM;
    calibration.profileRangeErrorM = zeros(numRows, numWidths);
    calibration.profileShiftM = zeros(numRows, numWidths);
    calibration.profileBoundary = false(numRows, numWidths);
    completedRows = 0;
end
batchSize = 24;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    profileRangeErrorM = zeros(numel(rows), numWidths);
    profileShiftM = zeros(numel(rows), numWidths);
    profileBoundary = false(numel(rows), numWidths);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        observation = regenerateObservation(cfg, truthResponse, ...
            signalPower, development.snrDb(row), development.seed(row));
        thetaDeg = truthThetaDeg + development.jointAngleErrorDeg(row);
        centerM = truthRangeM + development.frontRangeErrorM(row);
        trialError = zeros(1, numWidths);
        trialShift = zeros(1, numWidths);
        trialBoundary = false(1, numWidths);
        for widthIndex = 1:numWidths
            rangeSeedsM = localRangeSeeds(cfg, centerM, ...
                halfWidthsM(widthIndex), seedSpacingM);
            profile = fsjad.profileRangeAtAngle(cfg, observation, ...
                thetaDeg, scan, rangeSeedsM);
            trialError(widthIndex) = profile.rangeM - truthRangeM;
            trialShift(widthIndex) = profile.rangeM - centerM;
            trialBoundary(widthIndex) = isProfileBoundary( ...
                profile.rangeM, rangeSeedsM, seedSpacingM);
        end
        profileRangeErrorM(batchIndex, :) = trialError;
        profileShiftM(batchIndex, :) = trialShift;
        profileBoundary(batchIndex, :) = trialBoundary;
    end
    calibration.profileRangeErrorM(rows, :) = profileRangeErrorM;
    calibration.profileShiftM(rows, :) = profileShiftM;
    calibration.profileBoundary(rows, :) = profileBoundary;
    completedRows = rows(end);
    save(checkpointFile, "calibration", "completedRows", ...
        "halfWidthsM", "seedSpacingM");
    fprintf("Round 16 calibration rows %d/%d complete.\n", ...
        completedRows, numRows);
end
end

function [selected, screen, windowSummary] = selectExpandedRule( ...
    calibration, snrValues, halfWidthsM, lambdaValues)
numRows = numel(halfWidthsM) * numel(lambdaValues);
halfWidthM = repelem(halfWidthsM, numel(lambdaValues));
lambda = repmat(lambdaValues, numel(halfWidthsM), 1);
meanRelativeMse = zeros(numRows, 1);
maximumRelativeMse = zeros(numRows, 1);
relativeMse = zeros(numRows, numel(snrValues));
boundaryRate = zeros(numRows, 1);
for row = 1:numRows
    widthIndex = find(halfWidthsM == halfWidthM(row), 1);
    methodError = calibration.frontRangeErrorM + lambda(row) ...
        * (calibration.profileRangeErrorM(:, widthIndex) ...
        - calibration.frontRangeErrorM);
    for snrIndex = 1:numel(snrValues)
        chosen = calibration.snrDb == snrValues(snrIndex);
        referenceMse = mean(calibration.noHarmRangeErrorM(chosen).^2);
        relativeMse(row, snrIndex) = ...
            mean(methodError(chosen).^2) / referenceMse;
    end
    meanRelativeMse(row) = mean(relativeMse(row, :));
    maximumRelativeMse(row) = max(relativeMse(row, :));
    boundaryRate(row) = mean(calibration.profileBoundary(:, widthIndex));
end
screen = table(halfWidthM, lambda, meanRelativeMse, ...
    maximumRelativeMse, boundaryRate);
for snrIndex = 1:numel(snrValues)
    screen.("relativeMseSnr" + string(snrIndex)) = ...
        relativeMse(:, snrIndex);
end
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

numSummaryRows = numel(halfWidthsM) * numel(snrValues);
windowHalfWidthM = repmat(halfWidthsM, numel(snrValues), 1);
snrDb = repelem(snrValues, numel(halfWidthsM));
rangeRmseM = zeros(numSummaryRows, 1);
profileBoundaryRate = zeros(numSummaryRows, 1);
meanAbsShiftM = zeros(numSummaryRows, 1);
for snrIndex = 1:numel(snrValues)
    chosen = calibration.snrDb == snrValues(snrIndex);
    for widthIndex = 1:numel(halfWidthsM)
        row = (snrIndex - 1) * numel(halfWidthsM) + widthIndex;
        rangeRmseM(row) = rms( ...
            calibration.profileRangeErrorM(chosen, widthIndex));
        profileBoundaryRate(row) = mean( ...
            calibration.profileBoundary(chosen, widthIndex));
        meanAbsShiftM(row) = mean(abs( ...
            calibration.profileShiftM(chosen, widthIndex)));
    end
end
windowSummary = table(windowHalfWidthM, snrDb, rangeRmseM, ...
    profileBoundaryRate, meanAbsShiftM);
end

function audit = auditSources(development, locked, snrValues)
developmentRows = numel(development.snrDb);
lockedRows = numel(locked.snrDb);
developmentUniqueSeeds = numel(unique(development.seed));
lockedUniqueSeeds = numel(unique(locked.baseSeed));
seedOverlap = numel(intersect(development.seed, locked.baseSeed));
lockedCountSnr1 = sum(locked.snrDb == snrValues(1));
lockedCountSnr2 = sum(locked.snrDb == snrValues(2));
lockedCountSnr3 = sum(locked.snrDb == snrValues(3));
allFinite = all(isfinite([locked.frontAngleErrorDeg; ...
    locked.frontRangeErrorM; locked.musicAngleErrorDeg; ...
    locked.musicRangeErrorM; locked.frontSnrDb; locked.snapshotSnrDb]));
assert(developmentRows == 540, "fsjad:Round16DevelopmentSize");
assert(lockedRows == 10002, "fsjad:Round16LockedSize");
assert(developmentUniqueSeeds == developmentRows, ...
    "fsjad:Round16DevelopmentSeeds");
assert(lockedUniqueSeeds == lockedRows, "fsjad:Round16LockedSeeds");
assert(seedOverlap == 0, "fsjad:Round16SeedOverlap");
assert(all([lockedCountSnr1, lockedCountSnr2, lockedCountSnr3] == 3334), ...
    "fsjad:Round16SnrBalance");
assert(allFinite, "fsjad:Round16NonfiniteSource");
audit = table(developmentRows, lockedRows, developmentUniqueSeeds, ...
    lockedUniqueSeeds, seedOverlap, lockedCountSnr1, lockedCountSnr2, ...
    lockedCountSnr3, allFinite);
end

function validation = runLockedValidation(cfg, scan, truthResponse, ...
    signalPower, locked, halfWidthM, lambda, seedSpacingM, ...
    truthThetaDeg, truthRangeM, rule, outputFolder)
numRows = numel(locked.snrDb);
checkpointFile = fullfile(outputFolder, ...
    "expanded_profile_validation_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    validation = checkpoint.validation;
    completedRows = checkpoint.completedRows;
    assert(abs(checkpoint.halfWidthM - halfWidthM) < eps, ...
        "fsjad:Round16CheckpointWidthMismatch");
    assert(abs(checkpoint.lambda - lambda) < eps, ...
        "fsjad:Round16CheckpointLambdaMismatch");
else
    validation.snrDb = locked.snrDb;
    validation.seed = locked.baseSeed;
    validation.frontAngleErrorDeg = locked.frontAngleErrorDeg;
    validation.frontRangeErrorM = locked.frontRangeErrorM;
    validation.jointAngleErrorDeg = locked.musicAngleErrorDeg;
    validation.jointRangeErrorM = locked.musicRangeErrorM;
    snrEstimateDb = (locked.frontSnrDb + locked.snapshotSnrDb) / 2;
    validation.alpha = fsjad.snrReleasedAlpha(snrEstimateDb, ...
        rule.thresholdDb, rule.slopeDb, rule.saturationDb);
    validation.noHarmRangeErrorM = validation.frontRangeErrorM ...
        + validation.alpha .* (validation.jointRangeErrorM ...
        - validation.frontRangeErrorM);
    validation.profileRangeErrorM = zeros(numRows, 1);
    validation.selectedRangeErrorM = zeros(numRows, 1);
    validation.profileShiftM = zeros(numRows, 1);
    validation.profileBoundary = false(numRows, 1);
    completedRows = 0;
end
batchSize = 48;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    profileRangeErrorM = zeros(numel(rows), 1);
    selectedRangeErrorM = zeros(numel(rows), 1);
    profileShiftM = zeros(numel(rows), 1);
    profileBoundary = false(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        observation = regenerateObservation(cfg, truthResponse, ...
            signalPower, locked.snrDb(row), locked.baseSeed(row));
        thetaDeg = truthThetaDeg + locked.musicAngleErrorDeg(row);
        centerM = truthRangeM + locked.frontRangeErrorM(row);
        rangeSeedsM = localRangeSeeds( ...
            cfg, centerM, halfWidthM, seedSpacingM);
        profile = fsjad.profileRangeAtAngle(cfg, observation, ...
            thetaDeg, scan, rangeSeedsM);
        profileError = profile.rangeM - truthRangeM;
        profileRangeErrorM(batchIndex) = profileError;
        selectedRangeErrorM(batchIndex) = locked.frontRangeErrorM(row) ...
            + lambda * (profileError - locked.frontRangeErrorM(row));
        profileShiftM(batchIndex) = profile.rangeM - centerM;
        profileBoundary(batchIndex) = isProfileBoundary( ...
            profile.rangeM, rangeSeedsM, seedSpacingM);
    end
    validation.profileRangeErrorM(rows) = profileRangeErrorM;
    validation.selectedRangeErrorM(rows) = selectedRangeErrorM;
    validation.profileShiftM(rows) = profileShiftM;
    validation.profileBoundary(rows) = profileBoundary;
    completedRows = rows(end);
    save(checkpointFile, "validation", "completedRows", ...
        "halfWidthM", "lambda", "seedSpacingM");
    fprintf("Round 16 locked validation rows %d/%d complete.\n", ...
        completedRows, numRows);
end
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

function rangeSeedsM = localRangeSeeds( ...
    cfg, centerM, halfWidthM, spacingM)
lowerM = max(cfg.rangeLimitsM(1), centerM - halfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerM + halfWidthM);
numIntervals = max(1, ceil((upperM - lowerM) / spacingM));
rangeSeedsM = linspace(lowerM, upperM, numIntervals + 1).';
end

function boundary = isProfileBoundary(rangeM, rangeSeedsM, spacingM)
toleranceM = max(1e-6, spacingM * 1e-3);
boundary = rangeM - rangeSeedsM(1) <= toleranceM ...
    || rangeSeedsM(end) - rangeM <= toleranceM;
end

function [details, methodSummary, pairedSummary, mechanismSummary, ...
    tailSummary] = summarizeValidation(validation, snrValues)
details = struct2table(validation);
methodNames = ["Enhanced full-spectrum front"; ...
    "Zhang-style joint 2-D MUSIC"; "No-harm SNR release"; ...
    "MUSIC-angle range profile"; "Selected profile rule"];
numMethods = numel(methodNames);
method = repmat(methodNames, numel(snrValues), 1);
snrDb = repelem(snrValues, numMethods);
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValues)
    chosen = validation.snrDb == snrValues(snrIndex);
    rows = (snrIndex - 1) * numMethods + (1:numMethods);
    angleRmseDeg(rows) = [rms(validation.frontAngleErrorDeg(chosen)); ...
        repmat(rms(validation.jointAngleErrorDeg(chosen)), 4, 1)];
    rangeRmseM(rows) = [rms(validation.frontRangeErrorM(chosen)); ...
        rms(validation.jointRangeErrorM(chosen)); ...
        rms(validation.noHarmRangeErrorM(chosen)); ...
        rms(validation.profileRangeErrorM(chosen)); ...
        rms(validation.selectedRangeErrorM(chosen))];
end
methodSummary = table(method, snrDb, angleRmseDeg, rangeRmseM);

comparisonNames = ["Selected minus Zhang-style MUSIC"; ...
    "Selected minus full-spectrum front"; ...
    "Selected minus no-harm"];
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
        validation.noHarmRangeErrorM(chosen)};
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
profileImproveRate = zeros(size(snrValues));
profileImproveGivenAngleImprove = zeros(size(snrValues));
profileBoundaryRate = zeros(size(snrValues));
meanAbsProfileShiftM = zeros(size(snrValues));
for snrIndex = 1:numel(snrValues)
    chosen = validation.snrDb == snrValues(snrIndex);
    angleImprove = validation.jointAngleErrorDeg(chosen).^2 ...
        < validation.frontAngleErrorDeg(chosen).^2;
    profileImprove = validation.selectedRangeErrorM(chosen).^2 ...
        < validation.frontRangeErrorM(chosen).^2;
    sampleCount(snrIndex) = sum(chosen);
    angleImproveRate(snrIndex) = mean(angleImprove);
    profileImproveRate(snrIndex) = mean(profileImprove);
    profileImproveGivenAngleImprove(snrIndex) = ...
        mean(profileImprove(angleImprove));
    profileBoundaryRate(snrIndex) = mean( ...
        validation.profileBoundary(chosen));
    meanAbsProfileShiftM(snrIndex) = mean(abs( ...
        validation.profileShiftM(chosen)));
end
mechanismSummary = table(snrValues, sampleCount, angleImproveRate, ...
    profileImproveRate, profileImproveGivenAngleImprove, ...
    profileBoundaryRate, meanAbsProfileShiftM);
mechanismSummary.Properties.VariableNames{1} = 'snrDb';

tailMethodNames = ["Zhang-style joint 2-D MUSIC"; ...
    "No-harm SNR release"; "Selected profile rule"];
tailMethod = repmat(tailMethodNames, numel(snrValues), 1);
tailSnrDb = repelem(snrValues, numel(tailMethodNames));
medianAbsErrorM = zeros(size(tailSnrDb));
q90AbsErrorM = zeros(size(tailSnrDb));
q99AbsErrorM = zeros(size(tailSnrDb));
maximumAbsErrorM = zeros(size(tailSnrDb));
for snrIndex = 1:numel(snrValues)
    chosen = validation.snrDb == snrValues(snrIndex);
    errorMatrix = abs([validation.jointRangeErrorM(chosen), ...
        validation.noHarmRangeErrorM(chosen), ...
        validation.selectedRangeErrorM(chosen)]);
    rows = (snrIndex - 1) * numel(tailMethodNames) ...
        + (1:numel(tailMethodNames));
    medianAbsErrorM(rows) = median(errorMatrix, 1).';
    q90AbsErrorM(rows) = prctile(errorMatrix, 90, 1).';
    q99AbsErrorM(rows) = prctile(errorMatrix, 99, 1).';
    maximumAbsErrorM(rows) = max(errorMatrix, [], 1).';
end
tailSummary = table(tailMethod, tailSnrDb, medianAbsErrorM, ...
    q90AbsErrorM, q99AbsErrorM, maximumAbsErrorM);
tailSummary.Properties.VariableNames(1:2) = {'method', 'snrDb'};
end

function [change, lower, upper] = interval(methodError, referenceError)
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
halfWidth = 1.96 * std(squaredChange) / sqrt(numel(squaredChange));
lower = change - halfWidth;
upper = change + halfWidth;
end

function plotResults(methodSummary, windowSummary, outputFile)
figureHandle = figure("Visible", "off", "Color", "w", ...
    "Position", [100, 100, 1080, 420]);
layout = tiledlayout(1, 2, "TileSpacing", "compact", ...
    "Padding", "compact");
axisHandle = nexttile(layout);
hold(axisHandle, "on");
methods = unique(methodSummary.method, "stable");
for methodIndex = 1:numel(methods)
    chosen = methodSummary.method == methods(methodIndex);
    semilogy(axisHandle, methodSummary.snrDb(chosen), ...
        methodSummary.rangeRmseM(chosen), "-o", "LineWidth", 1.1);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Range RMSE (m)");
legend(axisHandle, methods, "Location", "best");

axisHandle = nexttile(layout);
hold(axisHandle, "on");
snrValues = unique(windowSummary.snrDb, "stable");
for snrIndex = 1:numel(snrValues)
    chosen = windowSummary.snrDb == snrValues(snrIndex);
    plot(axisHandle, windowSummary.windowHalfWidthM(chosen), ...
        windowSummary.rangeRmseM(chosen), "-o", "LineWidth", 1.1);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "Calibration range half-width (m)");
ylabel(axisHandle, "Range RMSE (m)");
legend(axisHandle, string(snrValues) + " dB", "Location", "best");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
