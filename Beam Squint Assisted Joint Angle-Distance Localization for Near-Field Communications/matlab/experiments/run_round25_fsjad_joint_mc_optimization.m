function run_round25_fsjad_joint_mc_optimization(options)
%RUN_ROUND25_FSJAD_JOINT_MC_OPTIMIZATION Tune every FSJAD design setting.

arguments
    options.NumWorkers (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} ...
        = "Threads"
    options.OutputRoot (1, 1) string = ""
    options.Protocol (1, 1) string ...
        {mustBeMember(options.Protocol, ["formal", "large", "smoke"])} ...
        = "formal"
end

projectFolder = fileparts(fileparts(mfilename("fullpath")));
zhangFolder = fullfile(projectFolder, "algorithms", ...
    "zhang_reproduction");
compressedFolder = fullfile(projectFolder, "algorithms", "compressed");
addpath(projectFolder, zhangFolder, compressedFolder);
cleanupPath = onCleanup(@() rmpath( ...
    projectFolder, zhangFolder, compressedFolder));
if strlength(options.OutputRoot) == 0
    assert(options.Protocol ~= "smoke", "fsjad:Round25SmokeOutput", ...
        "Smoke runs require an explicit temporary OutputRoot.");
    outputName = "round25_fsjad_joint_mc";
    if options.Protocol == "large"
        outputName = "round26_fsjad_large_joint_mc";
    end
    outputFolder = fullfile(projectFolder, "results", ...
        "full_spectrum", outputName);
else
    outputFolder = options.OutputRoot;
end
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

pool = gcp("nocreate");
if isempty(pool)
    pool = parpool(options.PoolType, options.NumWorkers);
elseif pool.NumWorkers ~= options.NumWorkers
    warning("fsjad:Round25ExistingPool", ...
        "Using the existing pool with %d workers, not requested %d.", ...
        pool.NumWorkers, options.NumWorkers);
end
fprintf("Round 25 uses %d %s workers.\n", ...
    pool.NumWorkers, options.PoolType);

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
snrValuesDb = [-10; 0; 20];
angleLimitsDeg = [-55, 55];
rangeLimitsM = [17, 48];
calibrationPerSnr = 60;
validationPerSnr = 200;
stageSamplesPerSnr = [4, 20, 60];
stageKeepCounts = [32, 8];
angleRmseRatioLimit = 1.15;
[candidates, levels] = fsjadJointSearchSpace();
baselineAlgorithm = fsjadRound23ComparisonConfig();
zhangAlgorithm = zhangEfJointMcR23Config();
calibrationSeedRoot = 27100000;
validationSeedRoot = 34100000;
selectedVersion = "FSJAD-JointMC-R25-locked";
if options.Protocol == "large"
    calibrationPerSnr = 1000;
    validationPerSnr = 200;
    stageSamplesPerSnr = [67, 333, 1000];
    stageKeepCounts = [32, 8];
    calibrationSeedRoot = 36100000;
    validationSeedRoot = 37100000;
    selectedVersion = "FSJAD-JointMC-R26-locked";
elseif options.Protocol == "smoke"
    candidates = smokeCandidates(candidates, baselineAlgorithm);
    calibrationPerSnr = 1;
    validationPerSnr = 1;
    stageSamplesPerSnr = 1;
    stageKeepCounts = [];
end
baselineId = findBaselineCandidate(candidates, baselineAlgorithm);

% Reuse exactly the Round 23 calibration realization for equal tuning data.
calibrationDesign = makeDesign(snrValuesDb, calibrationPerSnr, ...
    angleLimitsDeg, rangeLimitsM, calibrationSeedRoot);
checkpointFile = fullfile(outputFolder, "calibration_checkpoint.mat");
calibration = initializeOrLoadCalibration(checkpointFile, candidates, ...
    calibrationDesign, cfg, levels);
activeIds = candidates.candidateId;
stageSummaries = cell(numel(stageSamplesPerSnr), 1);
stageMembership = strings(height(candidates), numel(stageSamplesPerSnr));
for stage = 1:numel(stageSamplesPerSnr)
    rows = stageRows(calibrationDesign.snrDb, snrValuesDb, ...
        stageSamplesPerSnr(stage));
    stageMembership(activeIds, stage) = "evaluated";
    calibration = evaluateCalibration(cfg, scan, candidates, levels, ...
        calibrationDesign, calibration, activeIds, rows, ...
        checkpointFile, options.BatchSize);
    stageSummary = scoreCandidates(candidates, calibrationDesign, ...
        calibration, activeIds, rows, baselineId, snrValuesDb, ...
        angleRmseRatioLimit);
    stageSummaries{stage} = stageSummary;
    writetable(stageSummary, fullfile(outputFolder, ...
        sprintf("stage%d_screen.csv", stage)));
    if stage <= numel(stageKeepCounts)
        activeIds = selectForNextStage(stageSummary, ...
            stageKeepCounts(stage), baselineId);
        stageMembership(activeIds, stage) = "promoted";
    end
end

finalScreen = stageSummaries{end};
eligible = finalScreen(finalScreen.feasible, :);
assert(~isempty(eligible), "fsjad:Round25NoFeasibleCandidate");
eligible = sortrows(eligible, "normalizedRangeMse", "ascend");
selected = eligible(1, :);
selectedAlgorithm = rowToAlgorithm(selected, levels, selectedVersion);
writetable(selected, fullfile(outputFolder, ...
    "selected_configuration.csv"));
stageNames = cellstr("stage" + string(1:numel(stageSamplesPerSnr)));
membershipTable = [candidates, array2table(stageMembership, ...
    'VariableNames', stageNames)];
writetable(membershipTable, fullfile(outputFolder, ...
    "candidate_membership.csv"));

% These seeds are new and are not used by Round 23 or Round 24.
validationDesign = makeDesign(snrValuesDb, validationPerSnr, ...
    angleLimitsDeg, rangeLimitsM, validationSeedRoot);
validation = runValidation(cfg, scan, validationDesign, ...
    zhangAlgorithm, baselineAlgorithm, selectedAlgorithm, ...
    outputFolder, options.BatchSize);
[comparisonSummary, pairedSummary, mechanismSummary, seedAudit] = ...
    summarizeValidation(validationDesign, validation, ...
    zhangAlgorithm, baselineAlgorithm, selectedAlgorithm, snrValuesDb);

sampleConfigurationEvaluations = nnz(isfinite(calibration.rangeM));
protocol = table(levels.fullDiscreteSpaceCount, height(candidates), ...
    calibrationPerSnr, validationPerSnr, ...
    strjoin(string(stageSamplesPerSnr), "/"), ...
    strjoin(string(stageKeepCounts), "/"), ...
    sampleConfigurationEvaluations, angleRmseRatioLimit, ...
    angleLimitsDeg(1), angleLimitsDeg(2), ...
    rangeLimitsM(1), rangeLimitsM(2), ...
    'VariableNames', {'fullDiscreteSpaceCount', ...
    'sampledJointCandidateCount', 'calibrationCountPerSnr', ...
    'validationCountPerSnr', 'stageSamplesPerSnr', ...
    'stageKeepCounts', 'sampleConfigurationEvaluations', ...
    'angleRmseRatioLimit', 'angleMinDeg', 'angleMaxDeg', ...
    'rangeMinM', 'rangeMaxM'});
protocol.protocolType = options.Protocol;
writetable(protocol, fullfile(outputFolder, "protocol.csv"));
writetable(calibrationDesign, fullfile(outputFolder, ...
    "calibration_design.csv"));
writetable(validationDesign, fullfile(outputFolder, ...
    "validation_design.csv"));
writetable(comparisonSummary, fullfile(outputFolder, ...
    "comparison_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, ...
    "paired_summary.csv"));
writetable(mechanismSummary, fullfile(outputFolder, ...
    "mechanism_summary.csv"));
writetable(seedAudit, fullfile(outputFolder, "seed_audit.csv"));
save(fullfile(outputFolder, "fsjad_joint_mc_optimization.mat"), ...
    "cfg", "levels", "candidates", "calibrationDesign", ...
    "calibration", "stageSummaries", "selected", ...
    "selectedAlgorithm", "baselineAlgorithm", "zhangAlgorithm", ...
    "validationDesign", "validation", "comparisonSummary", ...
    "pairedSummary", "mechanismSummary", "protocol", "seedAudit", ...
    "-v7.3");
save(fullfile(outputFolder, "selected_algorithm.mat"), ...
    "selectedAlgorithm", "selected", "protocol");
plotResults(comparisonSummary, fullfile(outputFolder, ...
    "fsjad_joint_mc_optimization.png"));
disp(protocol);
disp(selected);
disp(comparisonSummary);
disp(pairedSummary);
end

function candidates = smokeCandidates(candidates, baseline)
gridLevels = strjoin(string(baseline.gridSizes), "/");
baselineRow = find(candidates.fusionCarrierCount ...
    == baseline.fusionCarrierCount ...
    & candidates.subarraySize == baseline.subarraySize ...
    & abs(candidates.angleHalfWidthDeg ...
    - baseline.localHalfWidthDeg) < 1e-12 ...
    & abs(candidates.rangeHalfWidthM ...
    - baseline.localHalfWidthM) < 1e-12 ...
    & candidates.gridLevels == gridLevels ...
    & abs(candidates.profileHalfWidthM ...
    - baseline.profileHalfWidthM) < 1e-12 ...
    & abs(candidates.profileSpacingM ...
    - baseline.profileSpacingM) < 1e-12 ...
    & abs(candidates.profileLambda ...
    - baseline.profileLambda) < 1e-12, 1);
smallRow = find(candidates.fusionCarrierCount == 65 ...
    & candidates.subarraySize == 32 ...
    & candidates.gridIndex == 1, 1);
assert(~isempty(baselineRow) && ~isempty(smallRow), ...
    "fsjad:Round25SmokeCandidates");
candidates = candidates([baselineRow; smallRow], :);
candidates.candidateId = (1:height(candidates)).';
end

function baselineId = findBaselineCandidate(candidates, algorithm)
gridLevels = strjoin(string(algorithm.gridSizes), "/");
matched = candidates.fusionCarrierCount == algorithm.fusionCarrierCount ...
    & candidates.subarraySize == algorithm.subarraySize ...
    & abs(candidates.angleHalfWidthDeg ...
    - algorithm.localHalfWidthDeg) < 1e-12 ...
    & abs(candidates.rangeHalfWidthM ...
    - algorithm.localHalfWidthM) < 1e-12 ...
    & candidates.gridLevels == gridLevels ...
    & abs(candidates.profileHalfWidthM ...
    - algorithm.profileHalfWidthM) < 1e-12 ...
    & abs(candidates.profileSpacingM ...
    - algorithm.profileSpacingM) < 1e-12 ...
    & abs(candidates.profileLambda ...
    - algorithm.profileLambda) < 1e-12;
assert(sum(matched) == 1, "fsjad:Round25BaselineCandidateMissing");
baselineId = candidates.candidateId(matched);
end

function design = makeDesign(snrValuesDb, countPerSnr, ...
    angleLimitsDeg, rangeLimitsM, seedRoot)
totalCount = numel(snrValuesDb) * countPerSnr;
seed = zeros(totalCount, 1);
truthThetaDeg = zeros(totalCount, 1);
truthRangeM = zeros(totalCount, 1);
snrDb = zeros(totalCount, 1);
for snrIndex = 1:numel(snrValuesDb)
    seedBase = seedRoot + 100000 * snrIndex;
    stream = RandStream("mt19937ar", Seed=seedBase);
    rows = (snrIndex - 1) * countPerSnr + (1:countPerSnr);
    seed(rows) = seedBase + (1:countPerSnr).';
    truthThetaDeg(rows) = angleLimitsDeg(1) + diff(angleLimitsDeg) ...
        * rand(stream, countPerSnr, 1);
    truthRangeM(rows) = rangeLimitsM(1) + diff(rangeLimitsM) ...
        * rand(stream, countPerSnr, 1);
    snrDb(rows) = snrValuesDb(snrIndex);
end
design = table(seed, truthThetaDeg, truthRangeM, snrDb);
end

function rows = stageRows(snrDb, snrValuesDb, countPerSnr)
rows = zeros(numel(snrValuesDb) * countPerSnr, 1);
writeIndex = 0;
for snrIndex = 1:numel(snrValuesDb)
    candidates = find(snrDb == snrValuesDb(snrIndex));
    chosen = candidates(1:countPerSnr);
    rows(writeIndex + (1:countPerSnr)) = chosen;
    writeIndex = writeIndex + countPerSnr;
end
end

function calibration = initializeOrLoadCalibration( ...
    checkpointFile, candidates, design, cfg, levels)
if isfile(checkpointFile)
    saved = load(checkpointFile);
    assert(isequal(saved.candidates, candidates) ...
        && isequal(saved.design, design) ...
        && isequal(saved.levels, levels) ...
        && isequal(saved.cfg, cfg), ...
        "fsjad:Round25CalibrationCheckpointMismatch");
    calibration = saved.calibration;
else
    shape = [height(candidates), height(design)];
    calibration.thetaDeg = nan(shape);
    calibration.rangeM = nan(shape);
    calibration.runtimeMs = nan(shape);
    calibration.musicBoundaryPeak = nan(shape);
    calibration.profileBoundaryPeak = nan(shape);
    save(checkpointFile, "calibration", "candidates", ...
        "design", "cfg", "levels", "-v7.3");
end
end

function calibration = evaluateCalibration(cfg, scan, candidates, ...
    levels, design, calibration, activeIds, targetRows, ...
    checkpointFile, batchSize)
pending = false(size(targetRows));
for index = 1:numel(targetRows)
    pending(index) = any(isnan( ...
        calibration.rangeM(activeIds, targetRows(index))));
end
pendingRows = targetRows(pending);
for batchStart = 1:batchSize:numel(pendingRows)
    rows = pendingRows(batchStart:min( ...
        batchStart + batchSize - 1, numel(pendingRows)));
    batchDesign = design(rows, :);
    missingIdsByRow = cell(numel(rows), 1);
    for batchIndex = 1:numel(rows)
        missingIdsByRow{batchIndex} = activeIds(isnan( ...
            calibration.rangeM(activeIds, rows(batchIndex))));
    end
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        batch{batchIndex} = evaluateCandidateSet(cfg, scan, ...
            candidates, levels, batchDesign(batchIndex, :), ...
            missingIdsByRow{batchIndex});
    end
    for batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        result = batch{batchIndex};
        calibration.thetaDeg(result.candidateId, row) = result.thetaDeg;
        calibration.rangeM(result.candidateId, row) = result.rangeM;
        calibration.runtimeMs(result.candidateId, row) = result.runtimeMs;
        calibration.musicBoundaryPeak(result.candidateId, row) = ...
            result.musicBoundaryPeak;
        calibration.profileBoundaryPeak(result.candidateId, row) = ...
            result.profileBoundaryPeak;
    end
    save(checkpointFile, "calibration", "candidates", ...
        "design", "cfg", "levels", "-v7.3");
    fprintf("Round 25 calibration rows %d/%d for %d candidates complete.\n", ...
        find(targetRows == rows(end), 1), numel(targetRows), numel(activeIds));
end
end

function result = evaluateCandidateSet(cfg, scan, candidates, levels, ...
    designRow, candidateIds)
[observation, fullSnapshots, peakCarrierIndex] = ...
    generateTrial(cfg, scan, designRow);
front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
    [-0.2; -0.1; 0; 0.1; 0.2]);
count = numel(candidateIds);
thetaDeg = nan(count, 1);
rangeM = nan(count, 1);
runtimeMs = nan(count, 1);
musicBoundaryPeak = nan(count, 1);
profileBoundaryPeak = nan(count, 1);
for index = 1:count
    candidate = candidates(candidateIds(index), :);
    algorithm = rowToAlgorithm(candidate, levels, "FSJAD-calibration");
    carrierIndex = fixedCountWindow(peakCarrierIndex, ...
        algorithm.fusionCarrierCount, cfg.numSubcarriers);
    timer = tic;
    [estimate, music, profile] = runFsjad(cfg, observation, ...
        fullSnapshots(:, carrierIndex + 1), carrierIndex, ...
        front, scan, algorithm);
    runtimeMs(index) = 1000 * toc(timer);
    thetaDeg(index) = estimate.thetaDeg;
    rangeM(index) = estimate.rangeM;
    musicBoundaryPeak(index) = isMusicBoundaryPeak(music.initialSpectrum);
    profileBoundaryPeak(index) = isProfileBoundaryPeak(profile);
end
result.candidateId = candidateIds;
result.thetaDeg = thetaDeg;
result.rangeM = rangeM;
result.runtimeMs = runtimeMs;
result.musicBoundaryPeak = musicBoundaryPeak;
result.profileBoundaryPeak = profileBoundaryPeak;
end

function [observation, snapshots, peakCarrierIndex] = ...
    generateTrial(cfg, scan, designRow)
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
peakCarrierIndex = peakPosition - 1;
fullCarrierIndex = (0:cfg.numSubcarriers - 1).';
snapshots = jad.simulateSnapshots(cfg, designRow.truthThetaDeg, ...
    designRow.truthRangeM, designRow.snrDb, fullCarrierIndex, stream);
end

function screen = scoreCandidates(candidates, design, calibration, ...
    activeIds, rows, baselineId, snrValuesDb, angleRmseRatioLimit)
baselineRangeError = calibration.rangeM(baselineId, rows).' ...
    - design.truthRangeM(rows);
baselineAngleError = calibration.thetaDeg(baselineId, rows).' ...
    - design.truthThetaDeg(rows);
baselineRangeMse = groupedMse( ...
    baselineRangeError, design.snrDb(rows), snrValuesDb);
baselineAngleRmse = sqrt(groupedMse( ...
    baselineAngleError, design.snrDb(rows), snrValuesDb));
count = numel(activeIds);
normalizedRangeMse = zeros(count, 1);
maximumAngleRmseRatio = zeros(count, 1);
pooledRangeRmseM = zeros(count, 1);
pooledAngleRmseDeg = zeros(count, 1);
musicBoundaryRate = zeros(count, 1);
profileBoundaryRate = zeros(count, 1);
medianRuntimeMs = zeros(count, 1);
rangeRmseBySnr = zeros(count, numel(snrValuesDb));
angleRmseBySnr = zeros(count, numel(snrValuesDb));
for index = 1:count
    candidateId = activeIds(index);
    rangeError = calibration.rangeM(candidateId, rows).' ...
        - design.truthRangeM(rows);
    angleError = calibration.thetaDeg(candidateId, rows).' ...
        - design.truthThetaDeg(rows);
    rangeMse = groupedMse(rangeError, design.snrDb(rows), snrValuesDb);
    angleMse = groupedMse(angleError, design.snrDb(rows), snrValuesDb);
    rangeRmseBySnr(index, :) = sqrt(rangeMse);
    angleRmseBySnr(index, :) = sqrt(angleMse);
    ratios = rangeMse ./ max(baselineRangeMse, eps);
    normalizedRangeMse(index) = exp(mean(log(max(ratios, realmin))));
    maximumAngleRmseRatio(index) = max( ...
        sqrt(angleMse) ./ max(baselineAngleRmse, eps));
    pooledRangeRmseM(index) = rms(rangeError);
    pooledAngleRmseDeg(index) = rms(angleError);
    musicBoundaryRate(index) = mean( ...
        calibration.musicBoundaryPeak(candidateId, rows));
    profileBoundaryRate(index) = mean( ...
        calibration.profileBoundaryPeak(candidateId, rows));
    medianRuntimeMs(index) = median( ...
        calibration.runtimeMs(candidateId, rows));
end
feasible = maximumAngleRmseRatio <= angleRmseRatioLimit;
rankingScore = normalizedRangeMse ...
    + 100 * max(0, maximumAngleRmseRatio - angleRmseRatioLimit).^2;
screen = candidates(activeIds, :);
screen.normalizedRangeMse = normalizedRangeMse;
screen.maximumAngleRmseRatio = maximumAngleRmseRatio;
screen.feasible = feasible;
screen.rankingScore = rankingScore;
screen.pooledRangeRmseM = pooledRangeRmseM;
screen.pooledAngleRmseDeg = pooledAngleRmseDeg;
screen.musicBoundaryRate = musicBoundaryRate;
screen.profileBoundaryRate = profileBoundaryRate;
screen.medianRuntimeMs = medianRuntimeMs;
screen.rangeRmseNeg10 = rangeRmseBySnr(:, 1);
screen.rangeRmse0 = rangeRmseBySnr(:, 2);
screen.rangeRmse20 = rangeRmseBySnr(:, 3);
screen.angleRmseNeg10 = angleRmseBySnr(:, 1);
screen.angleRmse0 = angleRmseBySnr(:, 2);
screen.angleRmse20 = angleRmseBySnr(:, 3);
screen = sortrows(screen, {'feasible', 'rankingScore'}, ...
    {'descend', 'ascend'});
end

function mse = groupedMse(error, snrDb, snrValuesDb)
mse = zeros(1, numel(snrValuesDb));
for snrIndex = 1:numel(snrValuesDb)
    mse(snrIndex) = mean(error(snrDb == snrValuesDb(snrIndex)).^2);
end
end

function activeIds = selectForNextStage(screen, keepCount, baselineId)
selectedRows = 1:min(keepCount, height(screen));
activeIds = screen.candidateId(selectedRows);
if ~ismember(baselineId, activeIds)
    activeIds(end) = baselineId;
end
activeIds = unique(activeIds, "stable");
end

function algorithm = rowToAlgorithm(row, levels, version)
algorithm.version = version;
algorithm.fusionCarrierCount = row.fusionCarrierCount;
algorithm.subarraySize = row.subarraySize;
algorithm.localHalfWidthDeg = row.angleHalfWidthDeg;
algorithm.localHalfWidthM = row.rangeHalfWidthM;
algorithm.gridSizes = levels.gridSizes{row.gridIndex};
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
algorithm.profileHalfWidthM = row.profileHalfWidthM;
algorithm.profileSpacingM = row.profileSpacingM;
algorithm.profileLambda = row.profileLambda;
end

function validation = runValidation(cfg, scan, design, zhang, ...
    baseline, selected, outputFolder, batchSize)
checkpointFile = fullfile(outputFolder, "validation_checkpoint.mat");
if isfile(checkpointFile)
    saved = load(checkpointFile);
    assert(isequal(saved.design, design) ...
        && isequal(saved.zhang, zhang) ...
        && isequal(saved.baseline, baseline) ...
        && isequal(saved.selected, selected) ...
        && isequal(saved.cfg, cfg), ...
        "fsjad:Round25ValidationCheckpointMismatch");
    validation = saved.validation;
    completedRows = saved.completedRows;
else
    validation = initializeValidation(height(design));
    completedRows = 0;
end
for batchStart = completedRows + 1:batchSize:height(design)
    rows = batchStart:min(batchStart + batchSize - 1, height(design));
    batchDesign = design(rows, :);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        batch{batchIndex} = evaluateValidationTrial(cfg, scan, ...
            batchDesign(batchIndex, :), zhang, baseline, selected);
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
        "zhang", "baseline", "selected", "cfg", "-v7.3");
    fprintf("Round 25 validation rows %d/%d complete.\n", ...
        completedRows, height(design));
end
end

function validation = initializeValidation(count)
fields = ["zhangThetaDeg", "zhangRangeM", "baselineThetaDeg", ...
    "baselineRangeM", "selectedThetaDeg", "selectedRangeM", ...
    "zhangRuntimeMs", "baselineRuntimeMs", "selectedRuntimeMs", ...
    "zhangMusicBoundary", "baselineMusicBoundary", ...
    "selectedMusicBoundary", "baselineProfileBoundary", ...
    "selectedProfileBoundary"];
validation = struct();
for field = fields
    validation.(field) = nan(count, 1);
end
end

function result = evaluateValidationTrial(cfg, scan, designRow, ...
    zhang, baseline, selected)
[observation, fullSnapshots, peakCarrierIndex] = ...
    generateTrial(cfg, scan, designRow);
front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
    zhang.frontOffsetsDeg);

zhangCarrierIndex = fixedCountWindow(peakCarrierIndex, ...
    zhang.fusionCarrierCount, cfg.numSubcarriers);
timer = tic;
zhangMusic = runMusic(cfg, fullSnapshots(:, zhangCarrierIndex + 1), ...
    zhangCarrierIndex, front, zhang);
result.zhangRuntimeMs = 1000 * toc(timer);

baselineCarrierIndex = fixedCountWindow(peakCarrierIndex, ...
    baseline.fusionCarrierCount, cfg.numSubcarriers);
timer = tic;
[baselineEstimate, baselineMusic, baselineProfile] = runFsjad( ...
    cfg, observation, fullSnapshots(:, baselineCarrierIndex + 1), ...
    baselineCarrierIndex, front, scan, baseline);
result.baselineRuntimeMs = 1000 * toc(timer);

selectedCarrierIndex = fixedCountWindow(peakCarrierIndex, ...
    selected.fusionCarrierCount, cfg.numSubcarriers);
timer = tic;
[selectedEstimate, selectedMusic, selectedProfile] = runFsjad( ...
    cfg, observation, fullSnapshots(:, selectedCarrierIndex + 1), ...
    selectedCarrierIndex, front, scan, selected);
result.selectedRuntimeMs = 1000 * toc(timer);

result.zhangThetaDeg = zhangMusic.thetaDeg;
result.zhangRangeM = zhangMusic.rangeM;
result.baselineThetaDeg = baselineEstimate.thetaDeg;
result.baselineRangeM = baselineEstimate.rangeM;
result.selectedThetaDeg = selectedEstimate.thetaDeg;
result.selectedRangeM = selectedEstimate.rangeM;
result.zhangMusicBoundary = isMusicBoundaryPeak( ...
    zhangMusic.initialSpectrum);
result.baselineMusicBoundary = isMusicBoundaryPeak( ...
    baselineMusic.initialSpectrum);
result.selectedMusicBoundary = isMusicBoundaryPeak( ...
    selectedMusic.initialSpectrum);
result.baselineProfileBoundary = isProfileBoundaryPeak(baselineProfile);
result.selectedProfileBoundary = isProfileBoundaryPeak(selectedProfile);
end

function [estimate, music, profile] = runFsjad(cfg, observation, ...
    snapshots, carrierIndex, front, scan, algorithm)
music = runMusic(cfg, snapshots, carrierIndex, front, algorithm);
rangeSeedsM = localRangeSeeds(cfg, front.rangeM, ...
    algorithm.profileHalfWidthM, algorithm.profileSpacingM);
profile = fsjad.profileRangeAtAngle(cfg, observation, ...
    music.thetaDeg, scan, rangeSeedsM);
estimate.thetaDeg = music.thetaDeg;
estimate.rangeM = front.rangeM + algorithm.profileLambda ...
    * (profile.rangeM - front.rangeM);
end

function music = runMusic(cfg, snapshots, carrierIndex, front, algorithm)
musicCfg = cfg;
musicCfg.subarraySize = algorithm.subarraySize;
musicCfg.numSubarrays = cfg.numAntennas - algorithm.subarraySize + 1;
musicCfg.localHalfWidthDeg = algorithm.localHalfWidthDeg;
musicCfg.localHalfWidthM = algorithm.localHalfWidthM;
musicCfg.gridSizes = algorithm.gridSizes;
music = jad.localMusicEstimate(musicCfg, snapshots, carrierIndex, ...
    front.thetaDeg, front.rangeM);
end

function seedsM = localRangeSeeds(cfg, centerM, halfWidthM, spacingM)
lowerM = max(cfg.rangeLimitsM(1), centerM - halfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerM + halfWidthM);
numIntervals = max(1, ceil((upperM - lowerM) / spacingM));
seedsM = linspace(lowerM, upperM, numIntervals + 1).';
end

function [summary, paired, mechanism, seedAudit] = ...
    summarizeValidation(design, validation, zhang, baseline, ...
    selected, snrValuesDb)
zhangAngleError = validation.zhangThetaDeg - design.truthThetaDeg;
zhangRangeError = validation.zhangRangeM - design.truthRangeM;
baselineAngleError = validation.baselineThetaDeg - design.truthThetaDeg;
baselineRangeError = validation.baselineRangeM - design.truthRangeM;
selectedAngleError = validation.selectedThetaDeg - design.truthThetaDeg;
selectedRangeError = validation.selectedRangeM - design.truthRangeM;
methodNames = [zhang.version; baseline.version; selected.version];
method = repmat(methodNames, numel(snrValuesDb), 1);
snrDb = repelem(snrValuesDb, numel(methodNames));
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
medianRuntimeMs = zeros(size(snrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = design.snrDb == snrValuesDb(snrIndex);
    rows = (snrIndex - 1) * numel(methodNames) + (1:numel(methodNames));
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(zhangAngleError(chosen)); ...
        rms(baselineAngleError(chosen)); rms(selectedAngleError(chosen))];
    rangeRmseM(rows) = [rms(zhangRangeError(chosen)); ...
        rms(baselineRangeError(chosen)); rms(selectedRangeError(chosen))];
    medianRuntimeMs(rows) = [median(validation.zhangRuntimeMs(chosen)); ...
        median(validation.baselineRuntimeMs(chosen)); ...
        median(validation.selectedRuntimeMs(chosen))];
end
summary = table(method, snrDb, sampleCount, angleRmseDeg, ...
    rangeRmseM, medianRuntimeMs);

comparisonNames = ["Selected FSJAD minus Joint-MC Zhang"; ...
    "Selected FSJAD minus prior FSJAD"];
comparison = repmat(comparisonNames, numel(snrValuesDb), 1);
pairedSnrDb = repelem(snrValuesDb, numel(comparisonNames));
pairedCount = zeros(size(pairedSnrDb));
mseChangeM2 = zeros(size(pairedSnrDb));
ci95LowerM2 = zeros(size(pairedSnrDb));
ci95UpperM2 = zeros(size(pairedSnrDb));
rmseReductionPercent = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = design.snrDb == snrValuesDb(snrIndex);
    references = {zhangRangeError(chosen); baselineRangeError(chosen)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) + comparisonIndex;
        pairedCount(row) = sum(chosen);
        [mseChangeM2(row), ci95LowerM2(row), ci95UpperM2(row)] = ...
            interval(selectedRangeError(chosen), ...
            references{comparisonIndex});
        rmseReductionPercent(row) = 100 * (1 ...
            - rms(selectedRangeError(chosen)) ...
            / rms(references{comparisonIndex}));
    end
end
paired = table(comparison, pairedSnrDb, pairedCount, mseChangeM2, ...
    ci95LowerM2, ci95UpperM2, rmseReductionPercent, ...
    'VariableNames', {'comparison', 'snrDb', 'sampleCount', ...
    'mseChangeM2', 'ci95LowerM2', 'ci95UpperM2', ...
    'rmseReductionPercent'});

mechanismCount = zeros(numel(snrValuesDb), 1);
zhangMusicBoundaryRate = zeros(numel(snrValuesDb), 1);
baselineMusicBoundaryRate = zeros(numel(snrValuesDb), 1);
selectedMusicBoundaryRate = zeros(numel(snrValuesDb), 1);
baselineProfileBoundaryRate = zeros(numel(snrValuesDb), 1);
selectedProfileBoundaryRate = zeros(numel(snrValuesDb), 1);
for snrIndex = 1:numel(snrValuesDb)
    chosen = design.snrDb == snrValuesDb(snrIndex);
    mechanismCount(snrIndex) = sum(chosen);
    zhangMusicBoundaryRate(snrIndex) = ...
        mean(validation.zhangMusicBoundary(chosen));
    baselineMusicBoundaryRate(snrIndex) = ...
        mean(validation.baselineMusicBoundary(chosen));
    selectedMusicBoundaryRate(snrIndex) = ...
        mean(validation.selectedMusicBoundary(chosen));
    baselineProfileBoundaryRate(snrIndex) = ...
        mean(validation.baselineProfileBoundary(chosen));
    selectedProfileBoundaryRate(snrIndex) = ...
        mean(validation.selectedProfileBoundary(chosen));
end
mechanism = table(snrValuesDb, mechanismCount, ...
    zhangMusicBoundaryRate, baselineMusicBoundaryRate, ...
    selectedMusicBoundaryRate, baselineProfileBoundaryRate, ...
    selectedProfileBoundaryRate, ...
    'VariableNames', {'snrDb', 'sampleCount', ...
    'zhangMusicBoundaryRate', 'baselineMusicBoundaryRate', ...
    'selectedMusicBoundaryRate', 'baselineProfileBoundaryRate', ...
    'selectedProfileBoundaryRate'});

gainM2 = zhangRangeError.^2 - selectedRangeError.^2;
[~, gainIndex] = max(gainM2);
[~, bestIndex] = min(abs(selectedRangeError));
auditIndex = [gainIndex; bestIndex];
auditType = ["Maximum FSJAD MSE gain over Joint-MC Zhang"; ...
    "Minimum selected FSJAD absolute error"];
seed = design.seed(auditIndex);
auditSnrDb = design.snrDb(auditIndex);
truthThetaDeg = design.truthThetaDeg(auditIndex);
truthRangeM = design.truthRangeM(auditIndex);
zhangAbsErrorM = abs(zhangRangeError(auditIndex));
baselineAbsErrorM = abs(baselineRangeError(auditIndex));
selectedAbsErrorM = abs(selectedRangeError(auditIndex));
seedAudit = table(auditType, seed, auditSnrDb, truthThetaDeg, ...
    truthRangeM, zhangAbsErrorM, baselineAbsErrorM, selectedAbsErrorM);
seedAudit.Properties.VariableNames{3} = 'snrDb';
end

function [change, lower, upper] = interval(methodError, referenceError)
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
halfWidth = 1.96 * std(squaredChange) / sqrt(numel(squaredChange));
lower = change - halfWidth;
upper = change + halfWidth;
end

function boundary = isMusicBoundaryPeak(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundary = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
end

function boundary = isProfileBoundaryPeak(profile)
boundary = profile.bestSeedIndex == 1 ...
    || profile.bestSeedIndex == numel(profile.rangeSeedsM);
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function plotResults(summary, outputFile)
figureHandle = figure("Visible", "off", "Color", "w", ...
    "Position", [100, 100, 760, 460]);
cleanupFigure = onCleanup(@() close(figureHandle));
axisHandle = axes(figureHandle);
hold(axisHandle, "on");
methods = unique(summary.method, "stable");
for methodIndex = 1:numel(methods)
    chosen = summary.method == methods(methodIndex);
    semilogy(axisHandle, summary.snrDb(chosen), ...
        summary.rangeRmseM(chosen), "-o", "LineWidth", 1.5, ...
        "DisplayName", methods(methodIndex));
end
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Range RMSE (m)");
title(axisHandle, "Round 25 full joint FSJAD optimization");
legend(axisHandle, "Location", "best");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
end
