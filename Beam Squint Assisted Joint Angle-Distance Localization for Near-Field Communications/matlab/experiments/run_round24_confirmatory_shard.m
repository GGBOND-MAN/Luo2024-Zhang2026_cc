function run_round24_confirmatory_shard(shardId, shardCount, options)
%RUN_ROUND24_CONFIRMATORY_SHARD Run one locked distributed MC shard.

arguments
    shardId (1, 1) double {mustBeInteger, mustBePositive}
    shardCount (1, 1) double {mustBeInteger, mustBePositive}
    options.CountPerSnr (1, 1) double ...
        {mustBeInteger, mustBePositive} = 10000
    options.NumWorkers (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
    options.BatchSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 32
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} ...
        = "Threads"
    options.OutputRoot (1, 1) string = ""
end
if shardId > shardCount
    error("fsjad:Round24ShardId", ...
        "shardId cannot exceed shardCount.");
end

projectFolder = fileparts(fileparts(mfilename("fullpath")));
zhangFolder = fullfile(projectFolder, "algorithms", ...
    "zhang_reproduction");
compressedFolder = fullfile(projectFolder, "algorithms", "compressed");
addpath(projectFolder, zhangFolder, compressedFolder);
cleanupPath = onCleanup(@() rmpath( ...
    projectFolder, zhangFolder, compressedFolder));

if strlength(options.OutputRoot) == 0
    outputRoot = fullfile(projectFolder, "results", "full_spectrum", ...
        "round24_confirmatory");
else
    outputRoot = options.OutputRoot;
end
outputFolder = fullfile(outputRoot, sprintf( ...
    "shard_%02d_of_%02d", shardId, shardCount));
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

pool = gcp("nocreate");
if isempty(pool)
    pool = parpool(options.PoolType, options.NumWorkers);
elseif pool.NumWorkers ~= options.NumWorkers
    warning("fsjad:Round24ExistingPool", ...
        "Using the existing pool with %d workers, not requested %d.", ...
        pool.NumWorkers, options.NumWorkers);
end
fprintf("Round 24 shard %d/%d uses %d %s workers.\n", ...
    shardId, shardCount, pool.NumWorkers, options.PoolType);

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
[zhangAlgorithm, oursAlgorithm] = loadRound26Algorithms(projectFolder);
design = fsjad.round24ConfirmatoryDesign( ...
    shardId, shardCount, options.CountPerSnr);
protocol = makeProtocol(shardId, shardCount, options, cfg, ...
    zhangAlgorithm, oursAlgorithm);
checkpointFile = fullfile(outputFolder, "checkpoint.mat");
[results, completedRows] = initializeOrLoad(checkpointFile, ...
    protocol, design, cfg, zhangAlgorithm, oursAlgorithm);

startTime = tic;
numRows = height(design);
initialCompletedRows = completedRows;
for batchStart = completedRows + 1:options.BatchSize:numRows
    rows = batchStart:min(batchStart + options.BatchSize - 1, numRows);
    batchDesign = design(rows, :);
    batch = cell(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        batch{batchIndex} = evaluateTrial(cfg, scan, ...
            batchDesign(batchIndex, :), zhangAlgorithm, oursAlgorithm);
    end
    results = storeBatch(results, batch, rows);
    completedRows = rows(end);
    save(checkpointFile, "protocol", "design", "results", ...
        "completedRows", "cfg", "zhangAlgorithm", "oursAlgorithm", ...
        "-v7.3");
    elapsedSeconds = toc(startTime);
    completedThisRun = completedRows - initialCompletedRows;
    rowsPerSecond = max(completedThisRun / elapsedSeconds, eps);
    etaHours = (numRows - completedRows) / rowsPerSecond / 3600;
    fprintf("Round 24 shard %d/%d: %d/%d rows, ETA %.2f h.\n", ...
        shardId, shardCount, completedRows, numRows, etaHours);
end

trialTable = makeTrialTable(design, results);
writetable(trialTable, fullfile(outputFolder, "trial_results.csv"));
assert(all(results.success), ...
    "fsjad:Round24TrialFailure", ...
    "At least one trial failed. Inspect trial_results.csv.");
summary = summarizeShard(trialTable, zhangAlgorithm, oursAlgorithm);
writetable(summary, fullfile(outputFolder, "shard_summary.csv"));
writetable(struct2table(protocol), ...
    fullfile(outputFolder, "protocol.csv"));
save(fullfile(outputFolder, "shard_result.mat"), "protocol", ...
    "design", "results", "completedRows", "cfg", ...
    "zhangAlgorithm", "oursAlgorithm", "summary", "-v7.3");
writeCompletionMarker(outputFolder, shardId, shardCount, numRows);
fprintf("Round 24 shard %d/%d is complete: %s\n", ...
    shardId, shardCount, outputFolder);
disp(summary);
end

function [zhangAlgorithm, oursAlgorithm] = loadRound26Algorithms(projectFolder)
resultRoot = fullfile(projectFolder, "results", "full_spectrum");
zhangFile = fullfile(resultRoot, "round26_zhang_large_joint_mc", ...
    "selected_algorithm.mat");
oursFile = fullfile(resultRoot, "round26_fsjad_large_joint_mc", ...
    "selected_algorithm.mat");
zhangAlgorithm = loadSelectedAlgorithm(zhangFile, ...
    "Zhang-EF-JointMC-R26-locked", "Zhang");
oursAlgorithm = loadSelectedAlgorithm(oursFile, ...
    "FSJAD-JointMC-R26-locked", "FSJAD");
end

function algorithm = loadSelectedAlgorithm(selectedFile, version, label)
assert(isfile(selectedFile), "fsjad:Round24AwaitingRound26", ...
    ["Round 26 large joint tuning for %s must finish first. " ...
    "Copy selected_algorithm.mat to %s before starting Round 24."], ...
    label, selectedFile);
saved = load(selectedFile, "selectedAlgorithm");
assert(isfield(saved, "selectedAlgorithm") ...
    && saved.selectedAlgorithm.version == version, ...
    "fsjad:Round24InvalidRound26Algorithm", ...
    "The %s selected algorithm is missing or has the wrong version.", ...
    label);
algorithm = saved.selectedAlgorithm;
end

function protocol = makeProtocol(shardId, shardCount, options, cfg, ...
    zhangAlgorithm, oursAlgorithm)
protocol.protocolVersion = "Round24-confirmatory-v2-round26-lock";
protocol.shardId = shardId;
protocol.shardCount = shardCount;
protocol.countPerSnr = options.CountPerSnr;
protocol.snrValuesDb = "-10/0/20";
protocol.angleLimitsDeg = "-55/55";
protocol.rangeLimitsM = "17/48";
protocol.truthSeedRoot = 32000000;
protocol.noiseSeedRoot = 33000000;
protocol.numAntennas = cfg.numAntennas;
protocol.numSubcarriers = cfg.numSubcarriers;
protocol.zhangVersion = zhangAlgorithm.version;
protocol.oursVersion = oursAlgorithm.version;
end

function [results, completedRows] = initializeOrLoad( ...
    checkpointFile, protocol, design, cfg, zhangAlgorithm, oursAlgorithm)
if isfile(checkpointFile)
    saved = load(checkpointFile);
    assert(isequal(saved.protocol, protocol) ...
        && isequal(saved.design, design) ...
        && isequal(saved.cfg, cfg) ...
        && isequal(saved.zhangAlgorithm, zhangAlgorithm) ...
        && isequal(saved.oursAlgorithm, oursAlgorithm), ...
        "fsjad:Round24CheckpointMismatch", ...
        "Checkpoint does not match the requested locked protocol.");
    results = saved.results;
    completedRows = saved.completedRows;
else
    results = initializeResults(height(design));
    completedRows = 0;
end
end

function results = initializeResults(count)
numericFields = ["zhangThetaDeg", "zhangRangeM", "oursThetaDeg", ...
    "oursRangeM", "zhangFrontThetaDeg", "zhangFrontRangeM", ...
    "oursFrontThetaDeg", "oursFrontRangeM", "frontRuntimeMs", ...
    "zhangRuntimeMs", "oursRuntimeMs"];
logicalFields = ["zhangBoundaryPeak", "oursBoundaryPeak", ...
    "zhangTruthInWindow", "oursTruthInWindow", "success"];
results = struct();
for field = numericFields
    results.(field) = nan(count, 1);
end
for field = logicalFields
    results.(field) = false(count, 1);
end
results.errorIdentifier = strings(count, 1);
end

function result = evaluateTrial(cfg, scan, designRow, ...
    zhangAlgorithm, oursAlgorithm)
result = emptyTrialResult();
try
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
    fullSnapshots = jad.simulateSnapshots(cfg, designRow.truthThetaDeg, ...
        designRow.truthRangeM, designRow.snrDb, fullCarrierIndex, stream);

    timer = tic;
    front = fsjad.angleMultistartProfileEstimate(cfg, observation, scan, ...
        zhangAlgorithm.frontOffsetsDeg);
    result.frontRuntimeMs = 1000 * toc(timer);
    zhangCarrierIndex = fixedCountWindow(peakCarrierIndex, ...
        zhangAlgorithm.fusionCarrierCount, cfg.numSubcarriers);
    timer = tic;
    zhangMusic = runMusic(cfg, ...
        fullSnapshots(:, zhangCarrierIndex + 1), zhangCarrierIndex, ...
        front, zhangAlgorithm);
    result.zhangRuntimeMs = 1000 * toc(timer);

    oursCarrierIndex = fixedCountWindow(peakCarrierIndex, ...
        oursAlgorithm.fusionCarrierCount, cfg.numSubcarriers);
    timer = tic;
    oursMusic = runMusic(cfg, fullSnapshots(:, oursCarrierIndex + 1), ...
        oursCarrierIndex, front, oursAlgorithm);
    rangeSeedsM = localRangeSeeds(cfg, front.rangeM, ...
        oursAlgorithm.profileHalfWidthM, oursAlgorithm.profileSpacingM);
    profile = fsjad.profileRangeAtAngle(cfg, observation, ...
        oursMusic.thetaDeg, scan, rangeSeedsM);
    oursRangeM = front.rangeM + oursAlgorithm.profileLambda ...
        * (profile.rangeM - front.rangeM);
    result.oursRuntimeMs = 1000 * toc(timer);

    result.zhangThetaDeg = zhangMusic.thetaDeg;
    result.zhangRangeM = zhangMusic.rangeM;
    result.oursThetaDeg = oursMusic.thetaDeg;
    result.oursRangeM = oursRangeM;
    result.zhangFrontThetaDeg = front.thetaDeg;
    result.zhangFrontRangeM = front.rangeM;
    result.oursFrontThetaDeg = front.thetaDeg;
    result.oursFrontRangeM = front.rangeM;
    result.zhangBoundaryPeak = isBoundaryPeak( ...
        zhangMusic.initialSpectrum);
    result.oursBoundaryPeak = isBoundaryPeak(oursMusic.initialSpectrum);
    result.zhangTruthInWindow = abs(front.thetaDeg ...
        - designRow.truthThetaDeg) <= zhangAlgorithm.localHalfWidthDeg ...
        && abs(front.rangeM - designRow.truthRangeM) ...
        <= zhangAlgorithm.localHalfWidthM;
    result.oursTruthInWindow = abs(front.thetaDeg ...
        - designRow.truthThetaDeg) <= oursAlgorithm.localHalfWidthDeg ...
        && abs(front.rangeM - designRow.truthRangeM) ...
        <= oursAlgorithm.localHalfWidthM;
    result.success = true;
catch exception
    result.errorIdentifier = string(exception.identifier);
end
end

function result = emptyTrialResult
result = struct();
numericFields = ["zhangThetaDeg", "zhangRangeM", "oursThetaDeg", ...
    "oursRangeM", "zhangFrontThetaDeg", "zhangFrontRangeM", ...
    "oursFrontThetaDeg", "oursFrontRangeM", "frontRuntimeMs", ...
    "zhangRuntimeMs", "oursRuntimeMs"];
for field = numericFields
    result.(field) = NaN;
end
result.zhangBoundaryPeak = false;
result.oursBoundaryPeak = false;
result.zhangTruthInWindow = false;
result.oursTruthInWindow = false;
result.success = false;
result.errorIdentifier = "";
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

function results = storeBatch(results, batch, rows)
fields = string(fieldnames(results));
for batchIndex = 1:numel(rows)
    for field = fields.'
        results.(field)(rows(batchIndex)) = batch{batchIndex}.(field);
    end
end
end

function tableOut = makeTrialTable(design, results)
tableOut = design;
fields = string(fieldnames(results));
for field = fields.'
    tableOut.(field) = results.(field);
end
end

function summary = summarizeShard(trials, zhangAlgorithm, oursAlgorithm)
snrValuesDb = unique(trials.snrDb, "stable");
method = repmat([zhangAlgorithm.version; oursAlgorithm.version], ...
    numel(snrValuesDb), 1);
snrDb = repelem(snrValuesDb, 2);
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValuesDb)
    chosen = trials.snrDb == snrValuesDb(snrIndex);
    rows = (snrIndex - 1) * 2 + (1:2);
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(trials.zhangThetaDeg(chosen) ...
        - trials.truthThetaDeg(chosen)); ...
        rms(trials.oursThetaDeg(chosen) - trials.truthThetaDeg(chosen))];
    rangeRmseM(rows) = [rms(trials.zhangRangeM(chosen) ...
        - trials.truthRangeM(chosen)); ...
        rms(trials.oursRangeM(chosen) - trials.truthRangeM(chosen))];
end
summary = table(method, snrDb, sampleCount, angleRmseDeg, rangeRmseM);
end

function boundary = isBoundaryPeak(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundary = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function writeCompletionMarker(outputFolder, shardId, shardCount, numRows)
markerFile = fullfile(outputFolder, "COMPLETE.txt");
fileId = fopen(markerFile, "w");
assert(fileId >= 0, "fsjad:Round24CompletionMarker");
cleanupFile = onCleanup(@() fclose(fileId));
fprintf(fileId, "Round 24 shard %d/%d complete with %d rows.\n", ...
    shardId, shardCount, numRows);
end
