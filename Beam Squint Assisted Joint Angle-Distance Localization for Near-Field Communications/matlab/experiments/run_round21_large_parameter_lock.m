function run_round21_large_parameter_lock
%RUN_ROUND21_LARGE_PARAMETER_LOCK Tune and independently lock compression.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
fullFolder = fullfile(projectFolder, "algorithms", "full");
compressedFolder = fullfile(projectFolder, "algorithms", "compressed");
addpath(projectFolder, fullFolder, compressedFolder);
cleanupPath = onCleanup(@() rmpath( ...
    projectFolder, fullFolder, compressedFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round21");
fullOutputFolder = fullfile(outputFolder, "full");
compressedOutputFolder = fullfile(outputFolder, "compressed");
folders = {outputFolder, fullOutputFolder, compressedOutputFolder};
for folderIndex = 1:numel(folders)
    if ~isfolder(folders{folderIndex})
        mkdir(folders{folderIndex});
    end
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 21 uses %d workers.\n", pool.NumWorkers);

source = load(fullfile(projectFolder, "results", "full_spectrum", ...
    "round19", "random_miss_fallback_complexity.mat"), ...
    "validation", "cfg");
cfg = source.cfg;
scan = fsjad.prepareScan(cfg);
snrValuesDb = [-10; 0; 20];
calibrationRows = splitRows(source.validation.snrDb, snrValuesDb, 50);
calibrationSource = subsetStruct(source.validation, calibrationRows);
fusionCandidates = [385; 449; 513];
gridCandidates = {[37, 27, 19]; [41, 29, 21]; [41, 31, 21]; ...
    [45, 33, 23]; [49, 35, 25]};
spacingCandidatesM = [0.075; 0.1; 0.125; 0.15; 0.2];
profileHalfWidthM = 1;
profileLambda = 0.9;
rangeRatioLimit = 1.03;
angleRatioLimit = 1.05;
numValidationPerSnr = 200;
angleLimitsDeg = [-55, 55];
rangeLimitsM = [17, 48];

calibration = runCalibration(cfg, scan, calibrationSource, ...
    fusionCandidates, gridCandidates, spacingCandidatesM, ...
    profileHalfWidthM, outputFolder);
[screen, selected] = selectCandidate(cfg, calibrationSource, ...
    calibration, fusionCandidates, gridCandidates, ...
    spacingCandidatesM, profileLambda, snrValuesDb, ...
    rangeRatioLimit, angleRatioLimit);
writetable(screen, fullfile(outputFolder, "calibration_screen.csv"));
writetable(selected, fullfile(compressedOutputFolder, ...
    "selected_configuration.csv"));

fullAlgorithm = fsjadFullConfig();
compressedAlgorithm = selectedAlgorithm(selected, gridCandidates, ...
    profileHalfWidthM, profileLambda);
validationDesign = makeValidationDesign(snrValuesDb, ...
    numValidationPerSnr, angleLimitsDeg, rangeLimitsM);
validation = runLockedValidation(cfg, scan, validationDesign, ...
    fullAlgorithm, compressedAlgorithm, outputFolder);
[comparisonSummary, pairedSummary, complexitySummary, ...
    fullDetails, compressedDetails, fullSummary, compressedSummary, ...
    seedAudit] = summarizeValidation(cfg, validation, fullAlgorithm, ...
    compressedAlgorithm, snrValuesDb);

protocol = table(numel(calibrationSource.snrDb), numValidationPerSnr, ...
    numel(fusionCandidates) * numel(gridCandidates) ...
    * numel(spacingCandidatesM), angleLimitsDeg(1), ...
    angleLimitsDeg(2), rangeLimitsM(1), rangeLimitsM(2), ...
    rangeRatioLimit, angleRatioLimit);
protocol.Properties.VariableNames = ["calibrationCount", ...
    "validationCountPerSnr", "candidateCount", "angleMinDeg", ...
    "angleMaxDeg", "rangeMinM", "rangeMaxM", ...
    "rangeMseRatioLimit", "angleMseRatioLimit"];
writetable(protocol, fullfile(outputFolder, "protocol.csv"));
writetable(validationDesign, fullfile(outputFolder, ...
    "validation_design.csv"));
writetable(comparisonSummary, fullfile(outputFolder, ...
    "comparison_summary.csv"));
writetable(pairedSummary, fullfile(outputFolder, "paired_summary.csv"));
writetable(complexitySummary, fullfile(outputFolder, ...
    "complexity_summary.csv"));
writetable(seedAudit, fullfile(outputFolder, "seed_audit.csv"));
writetable(fullDetails, fullfile(fullOutputFolder, ...
    "validation_details.csv"));
writetable(fullSummary, fullfile(fullOutputFolder, "summary.csv"));
writetable(complexitySummary(1:2, :), fullfile(fullOutputFolder, ...
    "complexity.csv"));
writetable(compressedDetails, fullfile(compressedOutputFolder, ...
    "validation_details.csv"));
writetable(compressedSummary, fullfile(compressedOutputFolder, ...
    "summary.csv"));
writetable(complexitySummary(3, :), fullfile(compressedOutputFolder, ...
    "complexity.csv"));
save(fullfile(outputFolder, "large_parameter_lock.mat"), ...
    "cfg", "calibrationSource", "calibration", "screen", ...
    "selected", "fullAlgorithm", "compressedAlgorithm", ...
    "validationDesign", "validation", "comparisonSummary", ...
    "pairedSummary", "complexitySummary", "fullDetails", ...
    "compressedDetails", "fullSummary", "compressedSummary", ...
    "seedAudit", "protocol");
plotResults(comparisonSummary, complexitySummary, fullfile(outputFolder, ...
    "large_parameter_lock.png"));

disp(selected);
disp(comparisonSummary);
disp(pairedSummary);
disp(complexitySummary);
disp(seedAudit);
end

function calibration = runCalibration(cfg, scan, source, ...
    fusionCandidates, gridCandidates, spacingCandidatesM, ...
    profileHalfWidthM, outputFolder)
numRows = numel(source.seed);
numMusicConfigurations = numel(fusionCandidates) * numel(gridCandidates);
numSpacings = numel(spacingCandidatesM);
checkpointFile = fullfile(outputFolder, "calibration_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.source.seed, source.seed) ...
        && isequal(checkpoint.fusionCandidates, fusionCandidates) ...
        && isequal(checkpoint.gridCandidates, gridCandidates) ...
        && isequal(checkpoint.spacingCandidatesM, spacingCandidatesM), ...
        "fsjad:Round21CalibrationCheckpointMismatch");
    calibration = checkpoint.calibration;
    completedRows = checkpoint.completedRows;
else
    calibration.musicThetaDeg = nan(numRows, numMusicConfigurations);
    calibration.musicRangeM = nan(numRows, numMusicConfigurations);
    calibration.musicRuntimeMs = nan(numRows, numMusicConfigurations);
    calibration.profileRangeM = ...
        nan(numRows, numMusicConfigurations, numSpacings);
    calibration.profileRuntimeMs = ...
        nan(numRows, numMusicConfigurations, numSpacings);
    calibration.profileResponseEvaluations = ...
        nan(numRows, numMusicConfigurations, numSpacings);
    completedRows = 0;
end
batchSize = 8;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        [observation, snapshots, fullCarrierIndex, peakCarrierIndex] = ...
            regenerateSourceTrial(cfg, scan, source, row);
        batch{batchIndex} = evaluateCalibrationTrial(cfg, scan, ...
            observation, snapshots, fullCarrierIndex, peakCarrierIndex, ...
            source.frontThetaDeg(row), source.frontRangeM(row), ...
            fusionCandidates, gridCandidates, spacingCandidatesM, ...
            profileHalfWidthM);
    end
    for batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        calibration.musicThetaDeg(row, :) = batch{batchIndex}.musicThetaDeg;
        calibration.musicRangeM(row, :) = batch{batchIndex}.musicRangeM;
        calibration.musicRuntimeMs(row, :) = batch{batchIndex}.musicRuntimeMs;
        calibration.profileRangeM(row, :, :) = ...
            batch{batchIndex}.profileRangeM;
        calibration.profileRuntimeMs(row, :, :) = ...
            batch{batchIndex}.profileRuntimeMs;
        calibration.profileResponseEvaluations(row, :, :) = ...
            batch{batchIndex}.profileResponseEvaluations;
    end
    completedRows = rows(end);
    save(checkpointFile, "calibration", "completedRows", "source", ...
        "fusionCandidates", "gridCandidates", ...
        "spacingCandidatesM", "profileHalfWidthM", "cfg");
    fprintf("Round 21 calibration rows %d/%d complete.\n", ...
        completedRows, numRows);
end
end

function [observation, snapshots, carrierIndex, peakCarrierIndex] = ...
    regenerateSourceTrial(cfg, scan, source, row)
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

function result = evaluateCalibrationTrial(cfg, scan, observation, ...
    snapshots, fullCarrierIndex, peakCarrierIndex, frontThetaDeg, ...
    frontRangeM, fusionCandidates, gridCandidates, spacingCandidatesM, ...
    profileHalfWidthM)
numMusicConfigurations = numel(fusionCandidates) * numel(gridCandidates);
numSpacings = numel(spacingCandidatesM);
result.musicThetaDeg = zeros(1, numMusicConfigurations);
result.musicRangeM = zeros(1, numMusicConfigurations);
result.musicRuntimeMs = zeros(1, numMusicConfigurations);
result.profileRangeM = zeros(1, numMusicConfigurations, numSpacings);
result.profileRuntimeMs = zeros(1, numMusicConfigurations, numSpacings);
result.profileResponseEvaluations = ...
    zeros(1, numMusicConfigurations, numSpacings);
configurationIndex = 0;
for fusionIndex = 1:numel(fusionCandidates)
    carrierIndex = fixedCountWindow(peakCarrierIndex, ...
        fusionCandidates(fusionIndex), cfg.numSubcarriers);
    positions = carrierIndex - fullCarrierIndex(1) + 1;
    assert(all(positions >= 1 & positions <= numel(fullCarrierIndex)), ...
        "fsjad:Round21CarrierSubsetMismatch");
    for gridIndex = 1:numel(gridCandidates)
        configurationIndex = configurationIndex + 1;
        candidateCfg = cfg;
        candidateCfg.gridSizes = gridCandidates{gridIndex};
        timer = tic;
        music = jad.localMusicEstimate(candidateCfg, ...
            snapshots(:, positions), carrierIndex, ...
            frontThetaDeg, frontRangeM);
        result.musicRuntimeMs(configurationIndex) = 1000 * toc(timer);
        result.musicThetaDeg(configurationIndex) = music.thetaDeg;
        result.musicRangeM(configurationIndex) = music.rangeM;
        for spacingIndex = 1:numSpacings
            seedsM = localRangeSeeds(cfg, frontRangeM, ...
                profileHalfWidthM, spacingCandidatesM(spacingIndex));
            timer = tic;
            profile = fsjad.profileRangeAtAngle(cfg, observation, ...
                music.thetaDeg, scan, seedsM);
            result.profileRuntimeMs(1, configurationIndex, ...
                spacingIndex) = 1000 * toc(timer);
            result.profileRangeM(1, configurationIndex, spacingIndex) = ...
                profile.rangeM;
            result.profileResponseEvaluations(1, configurationIndex, ...
                spacingIndex) = profile.responseEvaluations;
        end
    end
end
end

function [screen, selected] = selectCandidate(cfg, source, calibration, ...
    fusionCandidates, gridCandidates, spacingCandidatesM, lambda, ...
    snrValuesDb, rangeRatioLimit, angleRatioLimit)
numMusicConfigurations = numel(fusionCandidates) * numel(gridCandidates);
numCandidates = numMusicConfigurations * numel(spacingCandidatesM);
configurationIndex = zeros(numCandidates, 1);
fusionCarriers = zeros(numCandidates, 1);
gridIndex = zeros(numCandidates, 1);
gridLevels = strings(numCandidates, 1);
profileSpacingM = zeros(numCandidates, 1);
rangeRmseM = zeros(numCandidates, 1);
angleRmseDeg = zeros(numCandidates, 1);
maximumRangeMseRatio = zeros(numCandidates, 1);
maximumAngleMseRatio = zeros(numCandidates, 1);
maximumRangeMseRatioToZhang = zeros(numCandidates, 1);
operationProxy = zeros(numCandidates, 1);
referenceRangeError = source.frontRangeM + lambda ...
    * (source.profile1RangeM - source.frontRangeM) - source.truthRangeM;
referenceAngleError = source.jointThetaDeg - source.truthThetaDeg;
zhangRangeError = source.jointRangeM - source.truthRangeM;
frontEvaluations = mean(source.frontResponseEvaluations);
row = 0;
musicIndex = 0;
for fusionIndex = 1:numel(fusionCandidates)
    for currentGridIndex = 1:numel(gridCandidates)
        musicIndex = musicIndex + 1;
        angleError = calibration.musicThetaDeg(:, musicIndex) ...
            - source.truthThetaDeg;
        for spacingIndex = 1:numel(spacingCandidatesM)
            row = row + 1;
            rangeEstimate = source.frontRangeM + lambda ...
                * (calibration.profileRangeM( ...
                :, musicIndex, spacingIndex) - source.frontRangeM);
            rangeError = rangeEstimate - source.truthRangeM;
            rangeRatio = zeros(size(snrValuesDb));
            angleRatio = zeros(size(snrValuesDb));
            zhangRatio = zeros(size(snrValuesDb));
            for snrIndex = 1:numel(snrValuesDb)
                chosen = source.snrDb == snrValuesDb(snrIndex);
                rangeRatio(snrIndex) = mean(rangeError(chosen).^2) ...
                    / mean(referenceRangeError(chosen).^2);
                angleRatio(snrIndex) = mean(angleError(chosen).^2) ...
                    / mean(referenceAngleError(chosen).^2);
                zhangRatio(snrIndex) = mean(rangeError(chosen).^2) ...
                    / mean(zhangRangeError(chosen).^2);
            end
            configurationIndex(row) = musicIndex;
            fusionCarriers(row) = fusionCandidates(fusionIndex);
            gridIndex(row) = currentGridIndex;
            gridLevels(row) = ...
                strjoin(string(gridCandidates{currentGridIndex}), "/");
            profileSpacingM(row) = spacingCandidatesM(spacingIndex);
            rangeRmseM(row) = rms(rangeError);
            angleRmseDeg(row) = rms(angleError);
            maximumRangeMseRatio(row) = max(rangeRatio);
            maximumAngleMseRatio(row) = max(angleRatio);
            maximumRangeMseRatioToZhang(row) = max(zhangRatio);
            profileEvaluations = mean(calibration.profileResponseEvaluations( ...
                :, musicIndex, spacingIndex));
            operationProxy(row) = complexityProxy(cfg, ...
                fusionCandidates(fusionIndex), ...
                gridCandidates{currentGridIndex}, frontEvaluations, ...
                profileEvaluations);
        end
    end
end
feasible = maximumRangeMseRatio <= rangeRatioLimit ...
    & maximumAngleMseRatio <= angleRatioLimit ...
    & maximumRangeMseRatioToZhang <= 1;
screen = table(configurationIndex, fusionCarriers, gridIndex, ...
    gridLevels, profileSpacingM, rangeRmseM, angleRmseDeg, ...
    maximumRangeMseRatio, maximumAngleMseRatio, ...
    maximumRangeMseRatioToZhang, feasible, operationProxy);
if any(feasible)
    candidates = find(feasible);
    [~, localIndex] = min(operationProxy(candidates));
    selectedRow = candidates(localIndex);
else
    penalty = max([maximumRangeMseRatio / rangeRatioLimit, ...
        maximumAngleMseRatio / angleRatioLimit, ...
        maximumRangeMseRatioToZhang], [], 2);
    [~, selectedRow] = min(penalty);
end
selected = screen(selectedRow, :);
selected.rangeMseRatioLimit = rangeRatioLimit;
selected.angleMseRatioLimit = angleRatioLimit;
end

function algorithm = selectedAlgorithm(selected, gridCandidates, ...
    profileHalfWidthM, profileLambda)
algorithm.version = "FSJAD-Compressed-R21-locked";
algorithm.fusionCarrierCount = selected.fusionCarriers;
algorithm.gridSizes = gridCandidates{selected.gridIndex};
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
algorithm.profileHalfWidthM = profileHalfWidthM;
algorithm.profileSpacingM = selected.profileSpacingM;
algorithm.profileLambda = profileLambda;
end

function design = makeValidationDesign(snrValuesDb, countPerSnr, ...
    angleLimitsDeg, rangeLimitsM)
design = table();
for snrIndex = 1:numel(snrValuesDb)
    seedBase = 23100000 + 100000 * snrIndex;
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

function validation = runLockedValidation(cfg, scan, design, ...
    fullAlgorithm, compressedAlgorithm, outputFolder)
checkpointFile = fullfile(outputFolder, "validation_checkpoint.mat");
numRows = height(design);
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    assert(isequal(checkpoint.design, design) ...
        && isequal(checkpoint.fullAlgorithm, fullAlgorithm) ...
        && isequal(checkpoint.compressedAlgorithm, compressedAlgorithm), ...
        "fsjad:Round21ValidationCheckpointMismatch");
    validation = checkpoint.validation;
    completedRows = checkpoint.completedRows;
else
    validation = initializeValidation(numRows);
    completedRows = 0;
end
batchSize = 5;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        batch{batchIndex} = simulateLockedTrial(cfg, scan, ...
            design(row, :), fullAlgorithm, compressedAlgorithm);
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
        "fullAlgorithm", "compressedAlgorithm", "cfg");
    fprintf("Round 21 validation rows %d/%d complete.\n", ...
        completedRows, numRows);
end
end

function validation = initializeValidation(count)
fields = ["seed", "truthThetaDeg", "truthRangeM", "snrDb", ...
    "zhangThetaDeg", "zhangRangeM", "fullThetaDeg", "fullRangeM", ...
    "compressedThetaDeg", "compressedRangeM", "fullRuntimeMs", ...
    "compressedRuntimeMs", "fullFrontEvaluations", ...
    "compressedFrontEvaluations", "fullProfileEvaluations", ...
    "compressedProfileEvaluations"];
validation = struct();
for field = fields
    validation.(field) = nan(count, 1);
end
end

function result = simulateLockedTrial(cfg, scan, designRow, ...
    fullAlgorithm, compressedAlgorithm)
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
    fullAlgorithm.fusionCarrierCount, cfg.numSubcarriers);
snapshots = jad.simulateSnapshots(cfg, designRow.truthThetaDeg, ...
    designRow.truthRangeM, designRow.snrDb, fullCarrierIndex, stream);
compressedCarrierIndex = fixedCountWindow(peakPosition - 1, ...
    compressedAlgorithm.fusionCarrierCount, cfg.numSubcarriers);
positions = compressedCarrierIndex - fullCarrierIndex(1) + 1;

timer = tic;
fullEstimate = fsjadFullEstimate(cfg, observation, snapshots, ...
    fullCarrierIndex, scan, fullAlgorithm);
fullRuntimeMs = 1000 * toc(timer);
timer = tic;
compressedEstimate = fsjadCompressedEstimate(cfg, observation, ...
    snapshots(:, positions), compressedCarrierIndex, scan, ...
    compressedAlgorithm);
compressedRuntimeMs = 1000 * toc(timer);

result.seed = designRow.seed;
result.truthThetaDeg = designRow.truthThetaDeg;
result.truthRangeM = designRow.truthRangeM;
result.snrDb = designRow.snrDb;
result.zhangThetaDeg = fullEstimate.music.thetaDeg;
result.zhangRangeM = fullEstimate.music.rangeM;
result.fullThetaDeg = fullEstimate.thetaDeg;
result.fullRangeM = fullEstimate.rangeM;
result.compressedThetaDeg = compressedEstimate.thetaDeg;
result.compressedRangeM = compressedEstimate.rangeM;
result.fullRuntimeMs = fullRuntimeMs;
result.compressedRuntimeMs = compressedRuntimeMs;
result.fullFrontEvaluations = fullEstimate.front.totalResponseEvaluations;
result.compressedFrontEvaluations = ...
    compressedEstimate.front.totalResponseEvaluations;
result.fullProfileEvaluations = fullEstimate.profile.responseEvaluations;
result.compressedProfileEvaluations = ...
    compressedEstimate.profile.responseEvaluations;
end

function [comparisonSummary, pairedSummary, complexitySummary, ...
    fullDetails, compressedDetails, fullSummary, compressedSummary, ...
    seedAudit] = summarizeValidation(cfg, validation, fullAlgorithm, ...
    compressedAlgorithm, snrValuesDb)
zhangAngleError = validation.zhangThetaDeg - validation.truthThetaDeg;
zhangRangeError = validation.zhangRangeM - validation.truthRangeM;
fullAngleError = validation.fullThetaDeg - validation.truthThetaDeg;
fullRangeError = validation.fullRangeM - validation.truthRangeM;
compressedAngleError = validation.compressedThetaDeg ...
    - validation.truthThetaDeg;
compressedRangeError = validation.compressedRangeM ...
    - validation.truthRangeM;
methodNames = ["Zhang-EF-513-v1"; fullAlgorithm.version; ...
    compressedAlgorithm.version];
method = repmat(methodNames, numel(snrValuesDb), 1);
snrDb = repelem(snrValuesDb, numel(methodNames));
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = validation.snrDb == snrValuesDb(snrIndex);
    rows = (snrIndex - 1) * numel(methodNames) + (1:numel(methodNames));
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(zhangAngleError(chosen)); ...
        rms(fullAngleError(chosen)); rms(compressedAngleError(chosen))];
    rangeRmseM(rows) = [rms(zhangRangeError(chosen)); ...
        rms(fullRangeError(chosen)); rms(compressedRangeError(chosen))];
end
comparisonSummary = table(method, snrDb, sampleCount, ...
    angleRmseDeg, rangeRmseM);

comparisonNames = ["Compressed minus Zhang"; ...
    "Compressed minus full"];
comparison = repmat(comparisonNames, numel(snrValuesDb), 1);
pairedSnrDb = repelem(snrValuesDb, numel(comparisonNames));
pairedCount = zeros(size(pairedSnrDb));
mseChangeM2 = zeros(size(pairedSnrDb));
ci95LowerM2 = zeros(size(pairedSnrDb));
ci95UpperM2 = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = validation.snrDb == snrValuesDb(snrIndex);
    references = {zhangRangeError(chosen); fullRangeError(chosen)};
    for comparisonIndex = 1:numel(comparisonNames)
        row = (snrIndex - 1) * numel(comparisonNames) + comparisonIndex;
        pairedCount(row) = sum(chosen);
        [mseChangeM2(row), ci95LowerM2(row), ci95UpperM2(row)] = ...
            interval(compressedRangeError(chosen), ...
            references{comparisonIndex});
    end
end
pairedSummary = table(comparison, pairedSnrDb, pairedCount, ...
    mseChangeM2, ci95LowerM2, ci95UpperM2);
pairedSummary.Properties.VariableNames(2:3) = ["snrDb", "sampleCount"];

frontEvaluations = mean(validation.fullFrontEvaluations);
fullProfileEvaluations = mean(validation.fullProfileEvaluations);
compressedProfileEvaluations = ...
    mean(validation.compressedProfileEvaluations);
fullProxy = complexityProxy(cfg, fullAlgorithm.fusionCarrierCount, ...
    fullAlgorithm.gridSizes, frontEvaluations, fullProfileEvaluations);
compressedProxy = complexityProxy(cfg, ...
    compressedAlgorithm.fusionCarrierCount, ...
    compressedAlgorithm.gridSizes, frontEvaluations, ...
    compressedProfileEvaluations);
complexityMethod = methodNames;
medianRuntimeMs = [NaN; median(validation.fullRuntimeMs); ...
    median(validation.compressedRuntimeMs)];
candidateCarrierEvaluations = [fullAlgorithm.fusionCarrierCount ...
    * sum(fullAlgorithm.gridSizes.^2); ...
    fullAlgorithm.fusionCarrierCount * sum(fullAlgorithm.gridSizes.^2); ...
    compressedAlgorithm.fusionCarrierCount ...
    * sum(compressedAlgorithm.gridSizes.^2)];
eigendecompositionCount = [fullAlgorithm.fusionCarrierCount; ...
    fullAlgorithm.fusionCarrierCount; ...
    compressedAlgorithm.fusionCarrierCount];
meanExactResponseEvaluations = [frontEvaluations; ...
    frontEvaluations + fullProfileEvaluations; ...
    frontEvaluations + compressedProfileEvaluations];
operationProxy = [complexityProxy(cfg, ...
    fullAlgorithm.fusionCarrierCount, fullAlgorithm.gridSizes, ...
    frontEvaluations, 0); fullProxy; compressedProxy];
operationProxyRatioToFull = operationProxy / fullProxy;
complexitySummary = table(complexityMethod, medianRuntimeMs, ...
    candidateCarrierEvaluations, eigendecompositionCount, ...
    meanExactResponseEvaluations, operationProxy, ...
    operationProxyRatioToFull);
complexitySummary.Properties.VariableNames{1} = 'method';

base = struct2table(validation);
fullDetails = base(:, ["seed", "truthThetaDeg", "truthRangeM", ...
    "snrDb", "zhangThetaDeg", "zhangRangeM", "fullThetaDeg", ...
    "fullRangeM", "fullRuntimeMs", "fullFrontEvaluations", ...
    "fullProfileEvaluations"]);
compressedDetails = base(:, ["seed", "truthThetaDeg", ...
    "truthRangeM", "snrDb", "compressedThetaDeg", ...
    "compressedRangeM", "compressedRuntimeMs", ...
    "compressedFrontEvaluations", "compressedProfileEvaluations"]);
fullSummary = comparisonSummary( ...
    comparisonSummary.method ~= compressedAlgorithm.version, :);
compressedSummary = comparisonSummary( ...
    comparisonSummary.method == compressedAlgorithm.version, :);

[~, minimumIndex] = min(abs(compressedRangeError));
gainM2 = zhangRangeError.^2 - compressedRangeError.^2;
[~, gainIndex] = max(gainM2);
auditIndex = [minimumIndex; gainIndex];
auditType = ["Minimum absolute error"; "Maximum MSE gain over Zhang"];
seed = validation.seed(auditIndex);
auditSnrDb = validation.snrDb(auditIndex);
truthThetaDeg = validation.truthThetaDeg(auditIndex);
truthRangeM = validation.truthRangeM(auditIndex);
compressedAbsErrorM = abs(compressedRangeError(auditIndex));
fullAbsErrorM = abs(fullRangeError(auditIndex));
zhangAbsErrorM = abs(zhangRangeError(auditIndex));
seedAudit = table(auditType, seed, auditSnrDb, truthThetaDeg, ...
    truthRangeM, compressedAbsErrorM, fullAbsErrorM, zhangAbsErrorM);
seedAudit.Properties.VariableNames{3} = 'snrDb';
end

function rows = splitRows(snrDb, snrValuesDb, countPerSnr)
rows = zeros(numel(snrValuesDb) * countPerSnr, 1);
writeIndex = 0;
for snrIndex = 1:numel(snrValuesDb)
    candidates = find(snrDb == snrValuesDb(snrIndex));
    chosen = candidates(1:countPerSnr);
    rows(writeIndex + (1:countPerSnr)) = chosen;
    writeIndex = writeIndex + countPerSnr;
end
end

function output = subsetStruct(input, rows)
output = struct();
fields = string(fieldnames(input));
for field = fields.'
    output.(field) = input.(field)(rows, :);
end
end

function value = complexityProxy(cfg, fusionCarriers, gridSizes, ...
    frontResponseEvaluations, profileResponseEvaluations)
responseCost = cfg.numAntennas * cfg.numSubcarriers;
musicCost = fusionCarriers * (cfg.numSubarrays * cfg.subarraySize^2 ...
    + cfg.subarraySize^3 + sum(gridSizes.^2) * cfg.subarraySize);
value = musicCost + (frontResponseEvaluations ...
    + profileResponseEvaluations) * responseCost;
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
axisHandle = nexttile(layout);
bar(axisHandle, categorical(complexity.method), ...
    complexity.operationProxyRatioToFull);
grid(axisHandle, "on");
ylabel(axisHandle, "Operation proxy / full method");
title(layout, "Round 21 large parameter lock");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
