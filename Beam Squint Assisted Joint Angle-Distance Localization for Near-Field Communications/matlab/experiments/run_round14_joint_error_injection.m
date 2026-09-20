function run_round14_joint_error_injection
%RUN_ROUND14_JOINT_ERROR_INJECTION Diagnose range errors in joint MUSIC.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round14");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 14 uses %d workers.\n", pool.NumWorkers);

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
snrValues = [-10; -5; 0];
numPerSnr = 60;
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
windowNames = ["narrow-range"; "baseline"; "wide-range"; ...
    "narrow-angle"; "wide-angle"];
windowAngleHalfWidthDeg = [0.02; 0.02; 0.02; 0.01; 0.05];
windowRangeHalfWidthM = [0.01; 0.02; 0.05; 0.02; 0.02];
numWindows = numel(windowNames);
snrDb = repelem(snrValues, numPerSnr);
seed = 20299001 + (1:numel(snrDb)).';
checkpointFile = fullfile(outputFolder, ...
    "joint_error_injection_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    results = checkpoint.results;
    completedRows = checkpoint.completedRows;
else
    results = initializeResults(snrDb, seed, numWindows);
    completedRows = 0;
end

batchSize = 12;
for batchStart = completedRows + 1:batchSize:numel(snrDb)
    rows = batchStart:min(batchStart + batchSize - 1, numel(snrDb));
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        batch{batchIndex} = simulateTrial(cfg, scan, snrDb(row), ...
            fusionCarriers, frontOffsetsDeg, seed(row), ...
            windowAngleHalfWidthDeg, windowRangeHalfWidthM);
    end
    results = storeBatch(results, rows, batch);
    completedRows = rows(end);
    save(checkpointFile, "results", "completedRows", "snrValues", ...
        "numPerSnr", "fusionCarriers", "frontOffsetsDeg", ...
        "windowNames", "windowAngleHalfWidthDeg", ...
        "windowRangeHalfWidthM", "cfg");
    fprintf("Round 14 diagnostic rows %d/%d complete.\n", ...
        completedRows, numel(snrDb));
end

rule = readtable(fullfile(projectFolder, "results", "full_spectrum", ...
    "round13", "noharm_release_selected_rule.csv"));
[details, methodSummary, mechanismSummary, pairwise, windowSummary] = ...
    summarizeResults(results, snrValues, windowNames, ...
    windowAngleHalfWidthDeg, windowRangeHalfWidthM, rule);
writetable(details, fullfile(outputFolder, ...
    "joint_error_injection_details.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "joint_error_injection_method_summary.csv"));
writetable(mechanismSummary, fullfile(outputFolder, ...
    "joint_error_injection_mechanism_summary.csv"));
writetable(pairwise, fullfile(outputFolder, ...
    "joint_error_injection_pairwise.csv"));
writetable(windowSummary, fullfile(outputFolder, ...
    "joint_error_injection_window_summary.csv"));
save(fullfile(outputFolder, "joint_error_injection.mat"), ...
    "results", "details", "methodSummary", "mechanismSummary", ...
    "pairwise", "windowSummary", "snrValues", "numPerSnr", ...
    "fusionCarriers", "frontOffsetsDeg", "windowNames", ...
    "windowAngleHalfWidthDeg", "windowRangeHalfWidthM", "rule", "cfg");
disp(methodSummary);
disp(mechanismSummary);
disp(pairwise);
disp(windowSummary);
end

function results = initializeResults(snrDb, seed, numWindows)
numRows = numel(snrDb);
results.snrDb = snrDb;
results.seed = seed;
scalarFields = ["frontAngleErrorDeg", "frontRangeErrorM", ...
    "jointAngleErrorDeg", "jointRangeErrorM", ...
    "oracleCenterAngleErrorDeg", "oracleCenterRangeErrorM", ...
    "jointInitialAngleErrorDeg", "jointInitialRangeErrorM", ...
    "truthAngleProfileRangeErrorM", ...
    "oracleTruthAngleProfileRangeErrorM", "frontSnrDb", ...
    "snapshotSnrDb", "curvatureCoupling", ...
    "ridgeSlopeMPerDeg", "predictedRangeInjectionM"];
for field = scalarFields
    results.(field) = zeros(numRows, 1);
end
logicalFields = ["truthCapturedByInitialWindow", ...
    "initialThetaBoundary", "initialRangeBoundary", ...
    "finalRangeSaturated", "locallyConcave"];
for field = logicalFields
    results.(field) = false(numRows, 1);
end
results.windowAngleErrorDeg = zeros(numRows, numWindows);
results.windowRangeErrorM = zeros(numRows, numWindows);
results.windowThetaBoundary = false(numRows, numWindows);
results.windowRangeBoundary = false(numRows, numWindows);
end

function results = storeBatch(results, rows, batch)
scalarFields = ["frontAngleErrorDeg", "frontRangeErrorM", ...
    "jointAngleErrorDeg", "jointRangeErrorM", ...
    "oracleCenterAngleErrorDeg", "oracleCenterRangeErrorM", ...
    "jointInitialAngleErrorDeg", "jointInitialRangeErrorM", ...
    "truthAngleProfileRangeErrorM", ...
    "oracleTruthAngleProfileRangeErrorM", "frontSnrDb", ...
    "snapshotSnrDb", "curvatureCoupling", ...
    "ridgeSlopeMPerDeg", "predictedRangeInjectionM", ...
    "truthCapturedByInitialWindow", "initialThetaBoundary", ...
    "initialRangeBoundary", "finalRangeSaturated", ...
    "locallyConcave"];
matrixFields = ["windowAngleErrorDeg", "windowRangeErrorM", ...
    "windowThetaBoundary", "windowRangeBoundary"];
for batchIndex = 1:numel(rows)
    row = rows(batchIndex);
    trial = batch{batchIndex};
    for field = scalarFields
        results.(field)(row) = trial.(field);
    end
    for field = matrixFields
        results.(field)(row, :) = trial.(field);
    end
end
end

function result = simulateTrial(cfg, scan, snrDb, fusionCarriers, ...
    frontOffsetsDeg, seed, angleHalfWidthsDeg, rangeHalfWidthsM)
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
oracleCenter = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    truthThetaDeg, truthRangeM);
snrDiagnostics = fsjad.fittedSnrDiagnostics(cfg, observation, ...
    snapshots, carrierIndex, front, joint, scan);

initialDiagnostics = jad.localSpectrumDiagnostics( ...
    joint.initialSpectrum, joint.initialThetaGridDeg, ...
    joint.initialRangeGridM);
truthThetaSpectrum = jad.localMusicSpectrum(cfg, ...
    joint.signalVectors, carrierIndex, truthThetaDeg, ...
    joint.initialRangeGridM);
[~, truthAnglePeakRow] = max(truthThetaSpectrum(:, 1));
truthAngleProfileRangeM = ...
    joint.initialRangeGridM(truthAnglePeakRow);
oracleTruthThetaSpectrum = jad.localMusicSpectrum(cfg, ...
    oracleCenter.signalVectors, carrierIndex, truthThetaDeg, ...
    oracleCenter.initialRangeGridM);
[~, oracleTruthAnglePeakRow] = max( ...
    oracleTruthThetaSpectrum(:, 1));
oracleTruthAngleProfileRangeM = ...
    oracleCenter.initialRangeGridM(oracleTruthAnglePeakRow);

curvatureThetaGridDeg = truthThetaDeg + (-2:2) * 0.001;
curvatureRangeGridM = truthRangeM + (-2:2) * 0.001;
curvatureSpectrum = jad.localMusicSpectrum(cfg, ...
    joint.signalVectors, carrierIndex, curvatureThetaGridDeg, ...
    curvatureRangeGridM);
curvature = jad.localSpectrumDiagnostics(curvatureSpectrum, ...
    curvatureThetaGridDeg, curvatureRangeGridM, 3, 3);

numWindows = numel(angleHalfWidthsDeg);
windowAngleErrorDeg = zeros(1, numWindows);
windowRangeErrorM = zeros(1, numWindows);
windowThetaBoundary = false(1, numWindows);
windowRangeBoundary = false(1, numWindows);
for window = 1:numWindows
    thetaGridDeg = linspace(front.thetaDeg ...
        - angleHalfWidthsDeg(window), front.thetaDeg ...
        + angleHalfWidthsDeg(window), 61);
    rangeGridM = linspace(front.rangeM - rangeHalfWidthsM(window), ...
        front.rangeM + rangeHalfWidthsM(window), 61);
    spectrum = jad.localMusicSpectrum(cfg, joint.signalVectors, ...
        carrierIndex, thetaGridDeg, rangeGridM);
    diagnostics = jad.localSpectrumDiagnostics( ...
        spectrum, thetaGridDeg, rangeGridM);
    windowAngleErrorDeg(window) = ...
        diagnostics.peakThetaDeg - truthThetaDeg;
    windowRangeErrorM(window) = diagnostics.peakRangeM - truthRangeM;
    windowThetaBoundary(window) = diagnostics.thetaBoundary;
    windowRangeBoundary(window) = diagnostics.rangeBoundary;
end

maximumRangeShiftM = cumulativeMaximumShift( ...
    cfg.localHalfWidthM, cfg.gridSizes);
result.frontAngleErrorDeg = front.thetaDeg - truthThetaDeg;
result.frontRangeErrorM = front.rangeM - truthRangeM;
result.jointAngleErrorDeg = joint.thetaDeg - truthThetaDeg;
result.jointRangeErrorM = joint.rangeM - truthRangeM;
result.oracleCenterAngleErrorDeg = ...
    oracleCenter.thetaDeg - truthThetaDeg;
result.oracleCenterRangeErrorM = oracleCenter.rangeM - truthRangeM;
result.jointInitialAngleErrorDeg = ...
    initialDiagnostics.peakThetaDeg - truthThetaDeg;
result.jointInitialRangeErrorM = ...
    initialDiagnostics.peakRangeM - truthRangeM;
result.truthAngleProfileRangeErrorM = ...
    truthAngleProfileRangeM - truthRangeM;
result.oracleTruthAngleProfileRangeErrorM = ...
    oracleTruthAngleProfileRangeM - truthRangeM;
result.frontSnrDb = snrDiagnostics.frontSnrDb;
result.snapshotSnrDb = snrDiagnostics.snapshotSnrDb;
result.truthCapturedByInitialWindow = ...
    abs(result.frontAngleErrorDeg) <= cfg.localHalfWidthDeg ...
    && abs(result.frontRangeErrorM) <= cfg.localHalfWidthM;
result.initialThetaBoundary = initialDiagnostics.thetaBoundary;
result.initialRangeBoundary = initialDiagnostics.rangeBoundary;
result.finalRangeSaturated = abs(joint.rangeM - front.rangeM) ...
    >= 0.999 * maximumRangeShiftM;
result.curvatureCoupling = curvature.curvatureCoupling;
result.ridgeSlopeMPerDeg = curvature.ridgeSlopeMPerDeg;
result.locallyConcave = curvature.locallyConcave;
result.predictedRangeInjectionM = curvature.ridgeSlopeMPerDeg ...
    * result.jointAngleErrorDeg;
result.windowAngleErrorDeg = windowAngleErrorDeg;
result.windowRangeErrorM = windowRangeErrorM;
result.windowThetaBoundary = windowThetaBoundary;
result.windowRangeBoundary = windowRangeBoundary;
end

function [details, methodSummary, mechanismSummary, pairwise, ...
    windowSummary] = summarizeResults(results, snrValues, windowNames, ...
    angleHalfWidthsDeg, rangeHalfWidthsM, rule)
snrEstimateDb = (results.frontSnrDb + results.snapshotSnrDb) / 2;
alpha = fsjad.snrReleasedAlpha(snrEstimateDb, rule.thresholdDb, ...
    rule.slopeDb, rule.saturationDb);
noHarmRangeErrorM = results.frontRangeErrorM + alpha ...
    .* (results.jointRangeErrorM - results.frontRangeErrorM);
details = scalarDetailsTable(results);
details.noHarmAlpha = alpha;
details.noHarmRangeErrorM = noHarmRangeErrorM;
for window = 1:numel(windowNames)
    suffix = matlab.lang.makeValidName(windowNames(window));
    details.("angleError_" + suffix) = ...
        results.windowAngleErrorDeg(:, window);
    details.("rangeError_" + suffix) = ...
        results.windowRangeErrorM(:, window);
    details.("thetaBoundary_" + suffix) = ...
        results.windowThetaBoundary(:, window);
    details.("rangeBoundary_" + suffix) = ...
        results.windowRangeBoundary(:, window);
end

methodNames = ["Enhanced full-spectrum front"; "Joint 2-D MUSIC"; ...
    "Oracle-centered joint MUSIC"; "No-harm SNR release"];
numMethods = numel(methodNames);
method = repmat(methodNames, numel(snrValues), 1);
snrDb = repelem(snrValues, numMethods);
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
meanAlpha = zeros(size(snrDb));
for snrIndex = 1:numel(snrValues)
    selected = results.snrDb == snrValues(snrIndex);
    rows = (snrIndex - 1) * numMethods + (1:numMethods);
    angleRmseDeg(rows) = [rms(results.frontAngleErrorDeg(selected)); ...
        rms(results.jointAngleErrorDeg(selected)); ...
        rms(results.oracleCenterAngleErrorDeg(selected)); ...
        rms(results.jointAngleErrorDeg(selected))];
    rangeRmseM(rows) = [rms(results.frontRangeErrorM(selected)); ...
        rms(results.jointRangeErrorM(selected)); ...
        rms(results.oracleCenterRangeErrorM(selected)); ...
        rms(noHarmRangeErrorM(selected))];
    meanAlpha(rows) = [0; 1; 1; mean(alpha(selected))];
end
methodSummary = table(method, snrDb, angleRmseDeg, ...
    rangeRmseM, meanAlpha);

mechanismSummary = mechanismMetrics( ...
    results, snrValues, noHarmRangeErrorM);
pairwise = pairedComparisons(results, snrValues, noHarmRangeErrorM);
windowSummary = windowMetrics(results, snrValues, windowNames, ...
    angleHalfWidthsDeg, rangeHalfWidthsM);
end

function details = scalarDetailsTable(results)
fields = string(fieldnames(results));
matrixFields = ["windowAngleErrorDeg", "windowRangeErrorM", ...
    "windowThetaBoundary", "windowRangeBoundary"];
fields = setdiff(fields, matrixFields, "stable");
details = table();
for field = fields.'
    details.(field) = results.(field);
end
end

function summary = mechanismMetrics(results, snrValues, noHarmError)
snrDb = snrValues;
sampleCount = zeros(size(snrValues));
angleImproveRate = zeros(size(snrValues));
rangeWorsenRate = zeros(size(snrValues));
angleImproveRangeWorsenRate = zeros(size(snrValues));
conditionalRangeWorsenRate = zeros(size(snrValues));
truthCaptureRate = zeros(size(snrValues));
initialRangeBoundaryRate = zeros(size(snrValues));
finalRangeSaturationRate = zeros(size(snrValues));
locallyConcaveRate = zeros(size(snrValues));
medianCurvatureCoupling = zeros(size(snrValues));
medianAbsRidgeSlopeMPerDeg = zeros(size(snrValues));
injectionCorrelation = zeros(size(snrValues));
boundaryMseChange = zeros(size(snrValues));
interiorMseChange = zeros(size(snrValues));
noHarmMseChange = zeros(size(snrValues));
for snrIndex = 1:numel(snrValues)
    selected = results.snrDb == snrValues(snrIndex);
    angleImprove = results.jointAngleErrorDeg(selected).^2 ...
        < results.frontAngleErrorDeg(selected).^2;
    rangeWorsen = results.jointRangeErrorM(selected).^2 ...
        > results.frontRangeErrorM(selected).^2;
    sampleCount(snrIndex) = sum(selected);
    angleImproveRate(snrIndex) = mean(angleImprove);
    rangeWorsenRate(snrIndex) = mean(rangeWorsen);
    angleImproveRangeWorsenRate(snrIndex) = ...
        mean(angleImprove & rangeWorsen);
    conditionalRangeWorsenRate(snrIndex) = ...
        mean(rangeWorsen(angleImprove));
    truthCaptureRate(snrIndex) = mean( ...
        results.truthCapturedByInitialWindow(selected));
    initialRangeBoundaryRate(snrIndex) = mean( ...
        results.initialRangeBoundary(selected));
    finalRangeSaturationRate(snrIndex) = mean( ...
        results.finalRangeSaturated(selected));
    locallyConcaveRate(snrIndex) = mean( ...
        results.locallyConcave(selected));
    medianCurvatureCoupling(snrIndex) = median( ...
        results.curvatureCoupling(selected), "omitnan");
    medianAbsRidgeSlopeMPerDeg(snrIndex) = median(abs( ...
        results.ridgeSlopeMPerDeg(selected)), "omitnan");
    valid = selected & isfinite(results.predictedRangeInjectionM);
    injectionCorrelation(snrIndex) = corr( ...
        results.predictedRangeInjectionM(valid), ...
        results.jointRangeErrorM(valid));
    squaredChange = results.jointRangeErrorM(selected).^2 ...
        - results.frontRangeErrorM(selected).^2;
    boundary = results.initialRangeBoundary(selected);
    boundaryMseChange(snrIndex) = mean(squaredChange(boundary));
    interiorMseChange(snrIndex) = mean(squaredChange(~boundary));
    noHarmMseChange(snrIndex) = mean(noHarmError(selected).^2 ...
        - results.frontRangeErrorM(selected).^2);
end
summary = table(snrDb, sampleCount, angleImproveRate, rangeWorsenRate, ...
    angleImproveRangeWorsenRate, conditionalRangeWorsenRate, ...
    truthCaptureRate, initialRangeBoundaryRate, ...
    finalRangeSaturationRate, locallyConcaveRate, ...
    medianCurvatureCoupling, medianAbsRidgeSlopeMPerDeg, ...
    injectionCorrelation, boundaryMseChange, interiorMseChange, ...
    noHarmMseChange);
end

function statistics = pairedComparisons(results, snrValues, noHarmError)
comparisonNames = ["Oracle center minus joint"; ...
    "Truth-angle profile minus joint initial"; ...
    "No-harm minus joint"; "No-harm minus front"];
comparison = repmat(comparisonNames, numel(snrValues), 1);
snrDb = repelem(snrValues, numel(comparisonNames));
mseChange = zeros(size(snrDb));
ci95Lower = zeros(size(snrDb));
ci95Upper = zeros(size(snrDb));
for snrIndex = 1:numel(snrValues)
    selected = results.snrDb == snrValues(snrIndex);
    pairs = {results.oracleCenterRangeErrorM(selected), ...
        results.jointRangeErrorM(selected); ...
        results.truthAngleProfileRangeErrorM(selected), ...
        results.jointInitialRangeErrorM(selected); ...
        noHarmError(selected), results.jointRangeErrorM(selected); ...
        noHarmError(selected), results.frontRangeErrorM(selected)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) ...
            + comparisonIndex;
        [mseChange(row), ci95Lower(row), ci95Upper(row)] = ...
            interval(pairs{comparisonIndex, 1}, ...
            pairs{comparisonIndex, 2});
    end
end
statistics = table(comparison, snrDb, mseChange, ...
    ci95Lower, ci95Upper);
end

function summary = windowMetrics(results, snrValues, windowNames, ...
    angleHalfWidthsDeg, rangeHalfWidthsM)
numRows = numel(snrValues) * numel(windowNames);
window = repmat(windowNames, numel(snrValues), 1);
snrDb = repelem(snrValues, numel(windowNames));
angleHalfWidthDeg = repmat(angleHalfWidthsDeg, numel(snrValues), 1);
rangeHalfWidthM = repmat(rangeHalfWidthsM, numel(snrValues), 1);
truthCaptureRate = zeros(numRows, 1);
thetaBoundaryRate = zeros(numRows, 1);
rangeBoundaryRate = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
for snrIndex = 1:numel(snrValues)
    selected = results.snrDb == snrValues(snrIndex);
    for windowIndex = 1:numel(windowNames)
        row = (snrIndex - 1) * numel(windowNames) + windowIndex;
        truthCaptureRate(row) = mean(abs( ...
            results.frontAngleErrorDeg(selected)) ...
            <= angleHalfWidthsDeg(windowIndex) & abs( ...
            results.frontRangeErrorM(selected)) ...
            <= rangeHalfWidthsM(windowIndex));
        thetaBoundaryRate(row) = mean( ...
            results.windowThetaBoundary(selected, windowIndex));
        rangeBoundaryRate(row) = mean( ...
            results.windowRangeBoundary(selected, windowIndex));
        angleRmseDeg(row) = rms( ...
            results.windowAngleErrorDeg(selected, windowIndex));
        rangeRmseM(row) = rms( ...
            results.windowRangeErrorM(selected, windowIndex));
    end
end
summary = table(window, snrDb, angleHalfWidthDeg, rangeHalfWidthM, ...
    truthCaptureRate, thetaBoundaryRate, rangeBoundaryRate, ...
    angleRmseDeg, rangeRmseM);
end

function [change, lower, upper] = interval(methodError, referenceError)
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
halfWidth = 1.96 * std(squaredChange) / sqrt(numel(squaredChange));
lower = change - halfWidth;
upper = change + halfWidth;
end

function maximumShift = cumulativeMaximumShift(initialHalfWidth, gridSizes)
halfWidth = initialHalfWidth;
maximumShift = 0;
for gridSize = gridSizes
    maximumShift = maximumShift + halfWidth;
    step = 2 * halfWidth / (gridSize - 1);
    halfWidth = 2 * step;
end
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end
