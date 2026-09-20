function run_round13_reproduction_calibration
%RUN_ROUND13_REPRODUCTION_CALIBRATION Freeze executable comparison methods.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
repositoryFolder = fileparts(projectFolder);
workspaceFolder = fileparts(repositoryFolder);
luoFolder = fullfile(workspaceFolder, "repro_paper2");
addpath(projectFolder, luoFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder, luoFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round13");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 13 calibration uses %d workers.\n", pool.NumWorkers);

calibrateNoHarmRelease(projectFolder, outputFolder);
auditZhangCoarseGeometry(outputFolder);
calibrateLuoReproduction(outputFolder);
end

function calibrateNoHarmRelease(projectFolder, outputFolder)
round12 = fullfile(projectFolder, "results", "full_spectrum", ...
    "round12");
loaded = load(fullfile(round12, "snr_release_calibration.mat"), ...
    "calibration");
trials = loaded.calibration;
snrValues = [-10; -5; 0];
snrEstimateDb = (trials.frontSnrDb + trials.snapshotSnrDb) / 2;
thresholdValuesDb = (-7:0.5:-1).';
slopeValuesDb = [0.5; 1; 1.5; 2];
saturationValuesDb = [-Inf; (-8:0.5:-2).'];
numRules = numel(thresholdValuesDb) * numel(slopeValuesDb) ...
    * numel(saturationValuesDb);
thresholdDb = zeros(numRules, 1);
slopeDb = zeros(numRules, 1);
saturationDb = zeros(numRules, 1);
meanRelativeMse = zeros(numRules, 1);
maximumRelativeMse = zeros(numRules, 1);
relativeMse = zeros(numRules, numel(snrValues));
delta = trials.musicRangeErrorM - trials.frontRangeErrorM;
row = 0;
for threshold = thresholdValuesDb.'
    for slope = slopeValuesDb.'
        for saturation = saturationValuesDb.'
            row = row + 1;
            alpha = fsjad.snrReleasedAlpha(snrEstimateDb, ...
                threshold, slope, saturation);
            for snrIndex = 1:numel(snrValues)
                selected = trials.snrDb == snrValues(snrIndex);
                fusedError = trials.frontRangeErrorM(selected) ...
                    + alpha(selected) .* delta(selected);
                endpointMse = min(mean( ...
                    trials.frontRangeErrorM(selected).^2), mean( ...
                    trials.musicRangeErrorM(selected).^2));
                relativeMse(row, snrIndex) = ...
                    mean(fusedError.^2) / endpointMse;
            end
            thresholdDb(row) = threshold;
            slopeDb(row) = slope;
            saturationDb(row) = saturation;
            meanRelativeMse(row) = mean(relativeMse(row, :));
            maximumRelativeMse(row) = max(relativeMse(row, :));
        end
    end
end
scores = table(thresholdDb, slopeDb, saturationDb, ...
    meanRelativeMse, maximumRelativeMse);
for snrIndex = 1:numel(snrValues)
    scores.("relativeMseSnr" + string(snrIndex)) = ...
        relativeMse(:, snrIndex);
end
scores = sortrows(scores, ["maximumRelativeMse", ...
    "meanRelativeMse"], ["ascend", "ascend"]);
selectedRule = scores(1, :);
writetable(scores, fullfile(outputFolder, ...
    "noharm_release_calibration_scores.csv"));
writetable(selectedRule, fullfile(outputFolder, ...
    "noharm_release_selected_rule.csv"));
save(fullfile(outputFolder, "noharm_release_calibration.mat"), ...
    "snrValues", "thresholdValuesDb", "slopeValuesDb", ...
    "saturationValuesDb", "scores", "selectedRule");
disp(selectedRule);
end

function auditZhangCoarseGeometry(outputFolder)
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
thetaValuesDeg = linspace(-55, 55, 23);
rangeValuesM = linspace(15, 50, 15);
[thetaTruthDeg, rangeTruthM] = ndgrid(thetaValuesDeg, rangeValuesM);
thetaTruthDeg = thetaTruthDeg(:);
rangeTruthM = rangeTruthM(:);
numPoints = numel(thetaTruthDeg);
coarseThetaDeg = zeros(numPoints, 1);
coarseRangeM = zeros(numPoints, 1);
peakCarrierIndex = zeros(numPoints, 1);
for point = 1:numPoints
    response = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(thetaTruthDeg(point)), rangeTruthM(point), scan);
    [~, peak] = max(abs(response).^2);
    coarseThetaDeg(point) = scan.focusThetaDeg(peak);
    coarseRangeM(point) = scan.focusRangeM(peak);
    peakCarrierIndex(point) = peak - 1;
end
thetaErrorDeg = coarseThetaDeg - thetaTruthDeg;
rangeErrorM = coarseRangeM - rangeTruthM;
pointAudit = table(thetaTruthDeg, rangeTruthM, coarseThetaDeg, ...
    coarseRangeM, peakCarrierIndex, thetaErrorDeg, rangeErrorM);
writetable(pointAudit, fullfile(outputFolder, ...
    "zhang_reproduced_noiseless_coarse_grid.csv"));

angleHalfWidthsDeg = [0.02; 0.1; 0.2; 0.5; 1; 2; 5; 10];
rangeHalfWidthsM = [0.02; 0.1; 0.2; 0.5; 1; 2; 5; 10; 20; 50; 100];
numWindows = numel(angleHalfWidthsDeg) * numel(rangeHalfWidthsM);
angleHalfWidthDeg = zeros(numWindows, 1);
rangeHalfWidthM = zeros(numWindows, 1);
captureRate = zeros(numWindows, 1);
windowAreaDegM = zeros(numWindows, 1);
row = 0;
for angleHalfWidth = angleHalfWidthsDeg.'
    for rangeHalfWidth = rangeHalfWidthsM.'
        row = row + 1;
        captured = abs(thetaErrorDeg) <= angleHalfWidth ...
            & abs(rangeErrorM) <= rangeHalfWidth;
        angleHalfWidthDeg(row) = angleHalfWidth;
        rangeHalfWidthM(row) = rangeHalfWidth;
        captureRate(row) = mean(captured);
        windowAreaDegM(row) = 4 * angleHalfWidth * rangeHalfWidth;
    end
end
windowAudit = table(angleHalfWidthDeg, rangeHalfWidthM, ...
    windowAreaDegM, captureRate);
windowAudit = sortrows(windowAudit, ...
    ["captureRate", "windowAreaDegM"], ["descend", "ascend"]);
writetable(windowAudit, fullfile(outputFolder, ...
    "zhang_reproduced_noiseless_window_capture.csv"));

truthThetaDeg = 15;
truthRangeM = 30;
response = fsjad.exactSpectralResponse(cfg, deg2rad(truthThetaDeg), ...
    truthRangeM, scan);
[~, peak] = max(abs(response).^2);
example = table(truthThetaDeg, truthRangeM, ...
    scan.focusThetaDeg(peak), scan.focusRangeM(peak), peak - 1, ...
    scan.focusThetaDeg(peak) - truthThetaDeg, ...
    scan.focusRangeM(peak) - truthRangeM, ...
    VariableNames=["truthThetaDeg", "truthRangeM", ...
    "coarseThetaDeg", "coarseRangeM", "peakCarrierIndex", ...
    "thetaErrorDeg", "rangeErrorM"]);
writetable(example, fullfile(outputFolder, ...
    "zhang_reproduced_noiseless_paper_example.csv"));
disp(example);
disp(windowAudit(1:min(10, height(windowAudit)), :));
end

function calibrateLuoReproduction(outputFolder)
L = bs_lib();
P = L.par("N", 256, "f0", 58.5e9, "W", 3e9, "M", 2047, ...
    "fresnel", false);
snrValues = [-10; -5; 0];
truthThetaRad = deg2rad(15);
truthRangeM = 30;
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
reference = fsjad.exactSpectralResponse( ...
    cfg, truthThetaRad, truthRangeM, scan);
commonNoiseScale = cfg.numAntennas * mean(abs(reference).^2);
luoSnrAdjustmentDb = -10 * log10(commonNoiseScale);
rMidValuesM = [5; 10; 15; 20; 25; 30; 40; 50];
angleHalfSpansDeg = [60; 61; 62];
[rMid1M, rMid2M, angleHalfSpanDeg] = ndgrid( ...
    rMidValuesM, rMidValuesM, angleHalfSpansDeg);
candidates = table(rMid1M(:), rMid2M(:), angleHalfSpanDeg(:), ...
    VariableNames=["rMid1M", "rMid2M", "angleHalfSpanDeg"]);

pilotTrialsPerSnr = 20;
pilot = runLuoCandidates(L, P, candidates, snrValues, ...
    truthThetaRad, truthRangeM, pilotTrialsPerSnr, 20269001, ...
    luoSnrAdjustmentDb);
pilotScores = rankLuoCandidates(pilot, candidates, snrValues);
writetable(pilotScores, fullfile(outputFolder, ...
    "luo_reproduction_pilot_scores.csv"));
topCount = min(12, height(pilotScores));
topCandidates = pilotScores(1:topCount, ...
    ["rMid1M", "rMid2M", "angleHalfSpanDeg"]);

calibrationTrialsPerSnr = 200;
calibration = runLuoCandidates(L, P, topCandidates, snrValues, ...
    truthThetaRad, truthRangeM, calibrationTrialsPerSnr, 20279001, ...
    luoSnrAdjustmentDb);
calibrationScores = rankLuoCandidates( ...
    calibration, topCandidates, snrValues);
selectedLuo = calibrationScores(1, :);
writetable(calibrationScores, fullfile(outputFolder, ...
    "luo_reproduction_calibration_scores.csv"));
writetable(selectedLuo, fullfile(outputFolder, ...
    "luo_reproduction_selected_parameters.csv"));
save(fullfile(outputFolder, "luo_reproduction_calibration.mat"), ...
    "P", "snrValues", "truthThetaRad", "truthRangeM", ...
    "commonNoiseScale", "luoSnrAdjustmentDb", ...
    "rMidValuesM", "angleHalfSpansDeg", "pilotTrialsPerSnr", ...
    "pilot", "pilotScores", "calibrationTrialsPerSnr", ...
    "calibration", "calibrationScores", "selectedLuo");
disp(selectedLuo);
end

function trials = runLuoCandidates(L, P, candidates, snrValues, ...
    truthThetaRad, truthRangeM, numPerSnr, seedBase, ...
    luoSnrAdjustmentDb)
numCandidates = height(candidates);
numRows = numCandidates * numel(snrValues) * numPerSnr;
candidateIndex = repelem((1:numCandidates).', ...
    numel(snrValues) * numPerSnr);
snrDb = repmat(repelem(snrValues, numPerSnr), numCandidates, 1);
seed = seedBase + repmat((1:numel(snrValues) * numPerSnr).', ...
    numCandidates, 1);
thetaErrorDeg = zeros(numRows, 1);
rangeErrorM = zeros(numRows, 1);
parfor row = 1:numRows
    candidate = candidates(candidateIndex(row), :);
    rng(seed(row), "twister");
    settings = L.sense_par("rmin", 15, "rmax", 50, ...
        "thmin", deg2rad(-candidate.angleHalfSpanDeg), ...
        "thmax", deg2rad(candidate.angleHalfSpanDeg), ...
        "rmid1", candidate.rMid1M, "rmid2", candidate.rMid2M, ...
        "snr", 10^((snrDb(row) + luoSnrAdjustmentDb) / 10));
    estimate = L.cbs_low(P, truthRangeM, truthThetaRad, settings);
    thetaErrorDeg(row) = rad2deg(estimate.th - truthThetaRad);
    rangeErrorM(row) = estimate.r - truthRangeM;
end
trials = table(candidateIndex, snrDb, seed, ...
    thetaErrorDeg, rangeErrorM);
end

function scores = rankLuoCandidates(trials, candidates, snrValues)
numCandidates = height(candidates);
angleRmseDeg = zeros(numCandidates, numel(snrValues));
rangeRmseM = zeros(numCandidates, numel(snrValues));
for candidate = 1:numCandidates
    for snrIndex = 1:numel(snrValues)
        selected = trials.candidateIndex == candidate ...
            & trials.snrDb == snrValues(snrIndex);
        angleRmseDeg(candidate, snrIndex) = sqrt(mean( ...
            trials.thetaErrorDeg(selected).^2));
        rangeRmseM(candidate, snrIndex) = sqrt(mean( ...
            trials.rangeErrorM(selected).^2));
    end
end
relativeRangeMse = rangeRmseM.^2 ./ min(rangeRmseM.^2, [], 1);
maximumRelativeRangeMse = max(relativeRangeMse, [], 2);
meanRelativeRangeMse = mean(relativeRangeMse, 2);
pooledAngleRmseDeg = sqrt(mean(angleRmseDeg.^2, 2));
pooledRangeRmseM = sqrt(mean(rangeRmseM.^2, 2));
scores = [candidates, table(maximumRelativeRangeMse, ...
    meanRelativeRangeMse, pooledAngleRmseDeg, pooledRangeRmseM)];
for snrIndex = 1:numel(snrValues)
    scores.("angleRmseSnr" + string(snrIndex)) = ...
        angleRmseDeg(:, snrIndex);
    scores.("rangeRmseSnr" + string(snrIndex)) = ...
        rangeRmseM(:, snrIndex);
end
scores = sortrows(scores, ["maximumRelativeRangeMse", ...
    "meanRelativeRangeMse", "pooledAngleRmseDeg"], ...
    ["ascend", "ascend", "ascend"]);
end
