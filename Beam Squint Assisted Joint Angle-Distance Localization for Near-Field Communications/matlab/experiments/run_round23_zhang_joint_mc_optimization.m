
function run_round23_zhang_joint_mc_optimization(options)
%RUN_ROUND23_ZHANG_JOINT_MC_OPTIMIZATION Jointly tune all unknown settings.

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
    assert(options.Protocol ~= "smoke", "fsjad:Round23SmokeOutput", ...
        "Smoke runs require an explicit temporary OutputRoot.");
    outputName = "round23";
    if options.Protocol == "large"
        outputName = "round26_zhang_large_joint_mc";
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
    warning("fsjad:Round23ExistingPool", ...
        "Using the existing pool with %d workers, not requested %d.", ...
        pool.NumWorkers, options.NumWorkers);
end
fprintf("Zhang joint MC (%s) uses %d %s workers.\n", ...
    options.Protocol, pool.NumWorkers, options.PoolType);

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
[candidates, levels] = zhangJointSearchSpace();
frozenAlgorithm = zhangEf513Config();
compressedAlgorithm = fsjadCompressedConfig();
calibrationSeedRoot = 27100000;
validationSeedRoot = 28100000;
selectedVersion = "Zhang-EF-JointMC-R23-locked";
if options.Protocol == "large"
    calibrationPerSnr = 1000;
    validationPerSnr = 200;
    stageSamplesPerSnr = [67, 333, 1000];
    stageKeepCounts = [32, 8];
    calibrationSeedRoot = 36100000;
    validationSeedRoot = 37100000;
    selectedVersion = "Zhang-EF-JointMC-R26-locked";
elseif options.Protocol == "smoke"
    candidates = smokeCandidates(candidates, frozenAlgorithm);
    calibrationPerSnr = 1;
    validationPerSnr = 1;
    stageSamplesPerSnr = 1;
    stageKeepCounts = [];
end
baselineId = findFrozenCandidate(candidates, frozenAlgorithm);

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
assert(~isempty(eligible), "fsjad:Round23NoFeasibleCandidate");
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

validationDesign = makeDesign(snrValuesDb, validationPerSnr, ...
    angleLimitsDeg, rangeLimitsM, validationSeedRoot);
validation = runValidation(cfg, scan, validationDesign, ...
    frozenAlgorithm, selectedAlgorithm, compressedAlgorithm, ...
    outputFolder, options.BatchSize);
[comparisonSummary, pairedSummary, seedAudit] = ...
    summarizeValidation(validationDesign, validation, ...
    frozenAlgorithm, selectedAlgorithm, compressedAlgorithm, ...
    snrValuesDb);

fullSpaceCount = prod([numel(levels.fusionCarrierCount), ...
    numel(levels.subarraySize), numel(levels.angleHalfWidthDeg), ...
    numel(levels.rangeHalfWidthM), numel(levels.gridSizes)]);
sampleConfigurationEvaluations = nnz(isfinite(calibration.rangeM));
protocol = table(fullSpaceCount, height(candidates), ...
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
writetable(seedAudit, fullfile(outputFolder, "seed_audit.csv"));
save(fullfile(outputFolder, "zhang_joint_mc_optimization.mat"), ...
    "cfg", "levels", "candidates", "calibrationDesign", ...
    "calibration", "stageSummaries", "selected", ...
    "selectedAlgorithm", "frozenAlgorithm", "compressedAlgorithm", ...
    "validationDesign", "validation", "comparisonSummary", ...
    "pairedSummary", "protocol", "seedAudit", "-v7.3");
save(fullfile(outputFolder, "selected_algorithm.mat"), ...
    "selectedAlgorithm", "selected", "protocol");
plotResults(comparisonSummary, fullfile(outputFolder, ...
    "zhang_joint_mc_optimization.png"));
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
    & candidates.gridLevels == gridLevels, 1);
assert(~isempty(baselineRow), "fsjad:Round23SmokeBaselineMissing");
otherRow = find((1:height(candidates)).' ~= baselineRow, 1);
candidates = candidates([baselineRow; otherRow], :);
candidates.candidateId = (1:height(candidates)).';
end

function baselineId = findFrozenCandidate(candidates, algorithm)
gridLevels = strjoin(string(algorithm.gridSizes), "/");
matched = candidates.fusionCarrierCount == algorithm.fusionCarrierCount ...
    & candidates.subarraySize == algorithm.subarraySize ...
    & abs(candidates.angleHalfWidthDeg ...
    - algorithm.localHalfWidthDeg) < 1e-12 ...
    & abs(candidates.rangeHalfWidthM ...
    - algorithm.localHalfWidthM) < 1e-12 ...
    & candidates.gridLevels == gridLevels;
assert(sum(matched) == 1, "fsjad:Round23FrozenCandidateMissing");
baselineId = candidates.candidateId(matched);
end

function design = makeDesign(snrValuesDb, countPerSnr, ...
    angleLimitsDeg, rangeLimitsM, seedRoot)
design = table();
for snrIndex = 1:numel(snrValuesDb)
    seedBase = seedRoot + 100000 * snrIndex;
    stream = RandStream("mt19937ar", Seed=seedBase);
    seed = seedBase + (1:countPerSnr).';
    truthThetaDeg = angleLimitsDeg(1) + diff(angleLimitsDeg) ...
        * rand(stream, countPerSnr, 1);
    truthRangeM = rangeLimitsM(1) + diff(rangeLimitsM) ...
        * rand(stream, countPerSnr, 1);
    snrDb = repmat(snrValuesDb(snrIndex), countPerSnr, 1);
    design = [design; table(seed, truthThetaDeg, ...
        truthRangeM, snrDb)]; %#ok<AGROW>
end
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
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.candidates, candidates) ...
        && isequal(checkpoint.design, design) ...
        && isequal(checkpoint.levels, levels), ...
        "fsjad:Round23CalibrationCheckpointMismatch");
    calibration = checkpoint.calibration;
else
    shape = [height(candidates), height(design)];
    calibration.thetaDeg = nan(shape);
    calibration.rangeM = nan(shape);
    calibration.runtimeMs = nan(shape);
    calibration.boundaryPeak = nan(shape);
    save(checkpointFile, "calibration", "candidates", ...
        "design", "cfg", "levels", "-v7.3");
end
end

function calibration = evaluateCalibration(cfg, scan, candidates, ...
    levels, design, calibration, activeIds, targetRows, checkpointFile, ...
    batchSize)
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
    activeRangeM = calibration.rangeM(activeIds, rows);
    batchMissingIds = cell(numel(rows), 1);
    for batchIndex = 1:numel(rows)
        batchMissingIds{batchIndex} = activeIds( ...
            isnan(activeRangeM(:, batchIndex)));
    end
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        batch{batchIndex} = evaluateCandidateSet(cfg, scan, ...
            candidates, levels, batchDesign(batchIndex, :), ...
            batchMissingIds{batchIndex});
    end
    for batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        result = batch{batchIndex};
        calibration.thetaDeg(result.candidateId, row) = result.thetaDeg;
        calibration.rangeM(result.candidateId, row) = result.rangeM;
        calibration.runtimeMs(result.candidateId, row) = result.runtimeMs;
        calibration.boundaryPeak(result.candidateId, row) = ...
            result.boundaryPeak;
    end
    save(checkpointFile, "calibration", "candidates", ...
        "design", "cfg", "levels", "-v7.3");
    fprintf("Round 23 calibration rows %d/%d for %d candidates complete.\n", ...
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
boundaryPeak = nan(count, 1);
for index = 1:count
    candidate = candidates(candidateIds(index), :);
    musicCfg = candidateConfig(cfg, candidate, levels);
    carrierIndex = fixedCountWindow(peakCarrierIndex, ...
        candidate.fusionCarrierCount, cfg.numSubcarriers);
    timer = tic;
    music = jad.localMusicEstimate(musicCfg, ...
        fullSnapshots(:, carrierIndex + 1), carrierIndex, ...
        front.thetaDeg, front.rangeM);
    runtimeMs(index) = 1000 * toc(timer);
    thetaDeg(index) = music.thetaDeg;
    rangeM(index) = music.rangeM;
    boundaryPeak(index) = isBoundaryPeak(music.initialSpectrum);
end
result.candidateId = candidateIds;
result.thetaDeg = thetaDeg;
result.rangeM = rangeM;
result.runtimeMs = runtimeMs;
result.boundaryPeak = boundaryPeak;
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

function musicCfg = candidateConfig(cfg, candidate, levels)
musicCfg = cfg;
musicCfg.subarraySize = candidate.subarraySize;
musicCfg.numSubarrays = cfg.numAntennas - candidate.subarraySize + 1;
musicCfg.localHalfWidthDeg = candidate.angleHalfWidthDeg;
musicCfg.localHalfWidthM = candidate.rangeHalfWidthM;
musicCfg.gridSizes = levels.gridSizes{candidate.gridIndex};
end

function boundary = isBoundaryPeak(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundary = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
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
boundaryRate = zeros(count, 1);
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
    boundaryRate(index) = mean( ...
        calibration.boundaryPeak(candidateId, rows));
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
screen.boundaryRate = boundaryRate;
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

function algorithm = rowToAlgorithm(selected, levels, version)
algorithm.version = version;
algorithm.fusionCarrierCount = selected.fusionCarrierCount;
algorithm.subarraySize = selected.subarraySize;
algorithm.localHalfWidthDeg = selected.angleHalfWidthDeg;
algorithm.localHalfWidthM = selected.rangeHalfWidthM;
algorithm.gridSizes = levels.gridSizes{selected.gridIndex};
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
end

function validation = runValidation(cfg, scan, design, frozen, ...
    selected, compressed, outputFolder, batchSize)
checkpointFile = fullfile(outputFolder, "validation_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.design, design) ...
        && isequal(checkpoint.selected, selected), ...
        "fsjad:Round23ValidationCheckpointMismatch");
    validation = checkpoint.validation;
    completedRows = checkpoint.completedRows;
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
            batchDesign(batchIndex, :), frozen, selected, compressed);
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
        "frozen", "selected", "compressed", "cfg", "-v7.3");
    fprintf("Round 23 validation rows %d/%d complete.\n", ...
        completedRows, height(design));
end
end

function validation = initializeValidation(count)
fields = ["frozenThetaDeg", "frozenRangeM", "selectedThetaDeg", ...
    "selectedRangeM", "oursThetaDeg", "oursRangeM", ...
    "frozenRuntimeMs", "selectedRuntimeMs", "oursRuntimeMs"];
validation = struct();
for field = fields
    validation.(field) = nan(count, 1);
end
end

function result = evaluateValidationTrial(cfg, scan, designRow, ...
    frozen, selected, compressed)
[observation, snapshots, peakCarrierIndex] = ...
    generateTrial(cfg, scan, designRow);
front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
    frozen.frontOffsetsDeg);

timer = tic;
frozenMusic = runMusic(cfg, snapshots, peakCarrierIndex, ...
    front, frozen);
frozenRuntimeMs = 1000 * toc(timer);
timer = tic;
selectedMusic = runMusic(cfg, snapshots, peakCarrierIndex, ...
    front, selected);
selectedRuntimeMs = 1000 * toc(timer);
oursAlgorithm = frozen;
oursAlgorithm.fusionCarrierCount = compressed.fusionCarrierCount;
oursAlgorithm.gridSizes = compressed.gridSizes;
timer = tic;
oursMusic = runMusic(cfg, snapshots, peakCarrierIndex, ...
    front, oursAlgorithm);
rangeSeedsM = localRangeSeeds(cfg, front.rangeM, ...
    compressed.profileHalfWidthM, compressed.profileSpacingM);
profile = fsjad.profileRangeAtAngle(cfg, observation, ...
    oursMusic.thetaDeg, scan, rangeSeedsM);
oursRangeM = front.rangeM + compressed.profileLambda ...
    * (profile.rangeM - front.rangeM);
oursRuntimeMs = 1000 * toc(timer);

result.frozenThetaDeg = frozenMusic.thetaDeg;
result.frozenRangeM = frozenMusic.rangeM;
result.selectedThetaDeg = selectedMusic.thetaDeg;
result.selectedRangeM = selectedMusic.rangeM;
result.oursThetaDeg = oursMusic.thetaDeg;
result.oursRangeM = oursRangeM;
result.frozenRuntimeMs = frozenRuntimeMs;
result.selectedRuntimeMs = selectedRuntimeMs;
result.oursRuntimeMs = oursRuntimeMs;
end

function music = runMusic(cfg, snapshots, peakCarrierIndex, front, algorithm)
musicCfg = cfg;
musicCfg.subarraySize = algorithm.subarraySize;
musicCfg.numSubarrays = cfg.numAntennas - algorithm.subarraySize + 1;
musicCfg.localHalfWidthDeg = algorithm.localHalfWidthDeg;
musicCfg.localHalfWidthM = algorithm.localHalfWidthM;
musicCfg.gridSizes = algorithm.gridSizes;
carrierIndex = fixedCountWindow(peakCarrierIndex, ...
    algorithm.fusionCarrierCount, cfg.numSubcarriers);
music = jad.localMusicEstimate(musicCfg, ...
    snapshots(:, carrierIndex + 1), carrierIndex, ...
    front.thetaDeg, front.rangeM);
end

function seedsM = localRangeSeeds(cfg, centerM, halfWidthM, spacingM)
lowerM = max(cfg.rangeLimitsM(1), centerM - halfWidthM);
upperM = min(cfg.rangeLimitsM(2), centerM + halfWidthM);
numIntervals = max(1, ceil((upperM - lowerM) / spacingM));
seedsM = linspace(lowerM, upperM, numIntervals + 1).';
end

function [summary, paired, seedAudit] = summarizeValidation( ...
    design, validation, frozen, selected, compressed, snrValuesDb)
frozenAngleError = validation.frozenThetaDeg - design.truthThetaDeg;
frozenRangeError = validation.frozenRangeM - design.truthRangeM;
selectedAngleError = validation.selectedThetaDeg - design.truthThetaDeg;
selectedRangeError = validation.selectedRangeM - design.truthRangeM;
oursAngleError = validation.oursThetaDeg - design.truthThetaDeg;
oursRangeError = validation.oursRangeM - design.truthRangeM;
methodNames = [frozen.version; selected.version; compressed.version];
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
    angleRmseDeg(rows) = [rms(frozenAngleError(chosen)); ...
        rms(selectedAngleError(chosen)); rms(oursAngleError(chosen))];
    rangeRmseM(rows) = [rms(frozenRangeError(chosen)); ...
        rms(selectedRangeError(chosen)); rms(oursRangeError(chosen))];
    medianRuntimeMs(rows) = [median(validation.frozenRuntimeMs(chosen)); ...
        median(validation.selectedRuntimeMs(chosen)); ...
        median(validation.oursRuntimeMs(chosen))];
end
summary = table(method, snrDb, sampleCount, angleRmseDeg, ...
    rangeRmseM, medianRuntimeMs);

comparisonNames = ["Joint-MC Zhang minus frozen Zhang"; ...
    "FSJAD compressed minus Joint-MC Zhang"];
comparison = repmat(comparisonNames, numel(snrValuesDb), 1);
pairedSnrDb = repelem(snrValuesDb, numel(comparisonNames));
pairedCount = zeros(size(pairedSnrDb));
mseChangeM2 = zeros(size(pairedSnrDb));
ci95LowerM2 = zeros(size(pairedSnrDb));
ci95UpperM2 = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = design.snrDb == snrValuesDb(snrIndex);
    methodErrors = {selectedRangeError(chosen); oursRangeError(chosen)};
    referenceErrors = {frozenRangeError(chosen); selectedRangeError(chosen)};
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

[~, bestIndex] = min(abs(selectedRangeError));
gainM2 = selectedRangeError.^2 - oursRangeError.^2;
[~, gainIndex] = max(gainM2);
auditIndex = [bestIndex; gainIndex];
auditType = ["Minimum Joint-MC Zhang absolute error"; ...
    "Maximum FSJAD MSE gain over Joint-MC Zhang"];
seed = design.seed(auditIndex);
auditSnrDb = design.snrDb(auditIndex);
truthThetaDeg = design.truthThetaDeg(auditIndex);
truthRangeM = design.truthRangeM(auditIndex);
selectedAbsErrorM = abs(selectedRangeError(auditIndex));
frozenAbsErrorM = abs(frozenRangeError(auditIndex));
oursAbsErrorM = abs(oursRangeError(auditIndex));
seedAudit = table(auditType, seed, auditSnrDb, truthThetaDeg, ...
    truthRangeM, selectedAbsErrorM, frozenAbsErrorM, oursAbsErrorM);
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
    "Position", [100, 100, 760, 460]);
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
title(axisHandle, "Round 23 joint Zhang parameter optimization");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
