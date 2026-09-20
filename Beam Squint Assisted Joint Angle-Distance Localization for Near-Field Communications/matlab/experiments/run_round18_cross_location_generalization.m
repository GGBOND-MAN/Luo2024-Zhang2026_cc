function run_round18_cross_location_generalization
%RUN_ROUND18_CROSS_LOCATION_GENERALIZATION Validate the frozen range profile.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder)); %#ok<NASGU>
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round18");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Round 18 uses %d workers.\n", pool.NumWorkers);

cfg = configuredZhangBaseline();
scan = fsjad.prepareScan(cfg);
thetaValuesDeg = [-45; 15; 45];
rangeValuesM = [18; 30; 47];
snrValuesDb = [-10; 0; 20];
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
profileHalfWidthsM = [1; 2];
profileLambda = 0.9;
rangeSeedSpacingM = 0.1;
minimumTrialsPerCell = 100;
maximumTrialsPerCell = 500;
batchSize = 50;
maximumSequentialLooks = 1 + ...
    (maximumTrialsPerCell - minimumTrialsPerCell) / batchSize;
sequentialZ = norminv(1 - 0.05 / (2 * maximumSequentialLooks));

writeZhangVersion(outputFolder, cfg, fusionCarriers);
writeProtocol(outputFolder, minimumTrialsPerCell, ...
    maximumTrialsPerCell, batchSize, maximumSequentialLooks, ...
    sequentialZ);
design = makeDesign(thetaValuesDeg, rangeValuesM, snrValuesDb);
cellTrials = runDesign(cfg, scan, design, fusionCarriers, ...
    frontOffsetsDeg, profileHalfWidthsM, profileLambda, ...
    rangeSeedSpacingM, minimumTrialsPerCell, maximumTrialsPerCell, ...
    batchSize, sequentialZ, outputFolder);
[details, methodSummary, pairedByCell, aggregateSummary, ...
    aggregatePaired, mechanism] = summarizeResults( ...
    design, cellTrials, profileLambda, profileHalfWidthsM, ...
    minimumTrialsPerCell, sequentialZ);

writetable(design, fullfile(outputFolder, "cross_location_design.csv"));
writetable(details, fullfile(outputFolder, ...
    "cross_location_validation_details.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "cross_location_method_by_cell.csv"));
writetable(pairedByCell, fullfile(outputFolder, ...
    "cross_location_paired_by_cell.csv"));
writetable(aggregateSummary, fullfile(outputFolder, ...
    "cross_location_aggregate_summary.csv"));
writetable(aggregatePaired, fullfile(outputFolder, ...
    "cross_location_aggregate_paired.csv"));
writetable(mechanism, fullfile(outputFolder, ...
    "cross_location_mechanism.csv"));
save(fullfile(outputFolder, "cross_location_generalization.mat"), ...
    "cfg", "design", "cellTrials", "details", "methodSummary", ...
    "pairedByCell", "aggregateSummary", "aggregatePaired", ...
    "mechanism", "thetaValuesDeg", "rangeValuesM", ...
    "snrValuesDb", "fusionCarriers", "frontOffsetsDeg", ...
    "profileHalfWidthsM", "profileLambda", "rangeSeedSpacingM", ...
    "minimumTrialsPerCell", "maximumTrialsPerCell", ...
    "maximumSequentialLooks", "sequentialZ");
plotResults(aggregateSummary, pairedByCell, snrValuesDb, ...
    thetaValuesDeg, rangeValuesM, fullfile(outputFolder, ...
    "cross_location_generalization.png"));

disp(aggregateSummary);
disp(aggregatePaired);
disp(mechanism);
end

function writeProtocol(outputFolder, minimumCount, maximumCount, ...
    batchSize, maximumLooks, sequentialZ)
balancedAggregateCountPerCell = minimumCount;
protocol = table(minimumCount, maximumCount, batchSize, ...
    maximumLooks, sequentialZ, balancedAggregateCountPerCell);
writetable(protocol, fullfile(outputFolder, ...
    "cross_location_protocol.csv"));
end

function cfg = configuredZhangBaseline
cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
end

function writeZhangVersion(outputFolder, cfg, fusionCarriers)
versionName = "Zhang-EF-513-v1";
role = "Strengthened same-condition Zhang-style baseline";
coarseCenter = "Enhanced full-complex-spectrum profile estimate";
carrierStrategy = "Power-peak neighborhood";
fusionCarrierCount = fusionCarriers;
subarraySize = cfg.subarraySize;
angleHalfWidthDeg = cfg.localHalfWidthDeg;
rangeHalfWidthM = cfg.localHalfWidthM;
gridLevels = strjoin(string(cfg.gridSizes), "/");
paperLiteral = false;
notes = "Zhang geometry compensation and fused 2-D MUSIC; " ...
    + "unpublished numerical parameters are locally calibrated.";
version = table(versionName, role, coarseCenter, carrierStrategy, ...
    fusionCarrierCount, subarraySize, angleHalfWidthDeg, ...
    rangeHalfWidthM, gridLevels, paperLiteral, notes);
writetable(version, fullfile(outputFolder, ...
    "zhang_reproduction_version.csv"));
end

function design = makeDesign(thetaValuesDeg, rangeValuesM, snrValuesDb)
[thetaGrid, rangeGrid, snrGrid] = ndgrid( ...
    thetaValuesDeg, rangeValuesM, snrValuesDb);
cellIndex = (1:numel(thetaGrid)).';
truthThetaDeg = thetaGrid(:);
truthRangeM = rangeGrid(:);
snrDb = snrGrid(:);
design = table(cellIndex, truthThetaDeg, truthRangeM, snrDb);
end

function cellTrials = runDesign(cfg, scan, design, fusionCarriers, ...
    frontOffsetsDeg, profileWidthsM, profileLambda, seedSpacingM, ...
    minimumCount, maximumCount, batchSize, sequentialZ, outputFolder)
numCells = height(design);
checkpointFile = fullfile(outputFolder, ...
    "cross_location_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    cellTrials = checkpoint.cellTrials;
    completedCells = checkpoint.completedCells;
    assert(height(checkpoint.design) == numCells ...
        && all(checkpoint.design.truthThetaDeg == design.truthThetaDeg) ...
        && all(checkpoint.design.truthRangeM == design.truthRangeM) ...
        && all(checkpoint.design.snrDb == design.snrDb), ...
        "fsjad:Round18CheckpointDesignMismatch");
    for cellIndex = 1:numCells
        if ~isempty(cellTrials{cellIndex})
            completedCells(cellIndex) = ~needsMoreTrials( ...
                cellTrials{cellIndex}, profileLambda, minimumCount, ...
                maximumCount, sequentialZ);
        end
    end
else
    cellTrials = cell(numCells, 1);
    completedCells = false(numCells, 1);
end

for cellIndex = 1:numCells
    if completedCells(cellIndex)
        continue;
    end
    trials = cellTrials{cellIndex};
    if isempty(trials)
        trials = initializeTrials(0, numel(profileWidthsM));
    end
    while needsMoreTrials(trials, profileLambda, ...
            minimumCount, maximumCount, sequentialZ)
        startIndex = numel(trials.seed) + 1;
        stopIndex = min(startIndex + batchSize - 1, maximumCount);
        trialIndices = (startIndex:stopIndex).';
        batch = cell(numel(trialIndices), 1);
        parfor batchIndex = 1:numel(trialIndices)
            trialIndex = trialIndices(batchIndex);
            seed = 20400000 + 1000 * cellIndex + trialIndex;
            batch{batchIndex} = simulateTrial(cfg, scan, ...
                design.truthThetaDeg(cellIndex), ...
                design.truthRangeM(cellIndex), ...
                design.snrDb(cellIndex), seed, fusionCarriers, ...
                frontOffsetsDeg, profileWidthsM, seedSpacingM);
        end
        trials = appendTrials(trials, packBatch(batch, ...
            numel(profileWidthsM)));
        cellTrials{cellIndex} = trials;
        save(checkpointFile, "cellTrials", "completedCells", ...
            "design", "fusionCarriers", "frontOffsetsDeg", ...
            "profileWidthsM", "profileLambda", "seedSpacingM", ...
            "minimumCount", "maximumCount", "batchSize", ...
            "sequentialZ", "cfg");
        fprintf("Round 18 cell %d/%d: theta %.1f, range %.1f, " ...
            + "SNR %.0f, trials %d.\n", cellIndex, numCells, ...
            design.truthThetaDeg(cellIndex), ...
            design.truthRangeM(cellIndex), design.snrDb(cellIndex), ...
            numel(trials.seed));
    end
    completedCells(cellIndex) = true;
    cellTrials{cellIndex} = trials;
    save(checkpointFile, "cellTrials", "completedCells", ...
        "design", "fusionCarriers", "frontOffsetsDeg", ...
        "profileWidthsM", "profileLambda", "seedSpacingM", ...
        "minimumCount", "maximumCount", "batchSize", ...
        "sequentialZ", "cfg");
end
end

function more = needsMoreTrials( ...
    trials, lambda, minimumCount, maximumCount, sequentialZ)
count = numel(trials.seed);
if count < minimumCount
    more = true;
    return;
end
if count >= maximumCount
    more = false;
    return;
end
fixedError = trials.frontRangeErrorM + lambda ...
    * (trials.profileRangeErrorM(:, 1) - trials.frontRangeErrorM);
[~, lower, upper] = interval( ...
    fixedError, trials.jointRangeErrorM, sequentialZ);
more = lower <= 0 && upper >= 0;
end

function result = simulateTrial(cfg, scan, truthThetaDeg, truthRangeM, ...
    snrDb, seed, fusionCarriers, frontOffsetsDeg, profileWidthsM, ...
    seedSpacingM)
truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
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

numWidths = numel(profileWidthsM);
profileRangeErrorM = zeros(1, numWidths);
profileBoundary = false(1, numWidths);
for widthIndex = 1:numWidths
    seedsM = localRangeSeeds(cfg, front.rangeM, ...
        profileWidthsM(widthIndex), seedSpacingM);
    profile = fsjad.profileRangeAtAngle( ...
        cfg, observation, joint.thetaDeg, scan, seedsM);
    profileRangeErrorM(widthIndex) = profile.rangeM - truthRangeM;
    profileBoundary(widthIndex) = isProfileBoundary( ...
        profile.rangeM, seedsM, seedSpacingM);
end

result.seed = seed;
result.frontAngleErrorDeg = front.thetaDeg - truthThetaDeg;
result.frontRangeErrorM = front.rangeM - truthRangeM;
result.jointAngleErrorDeg = joint.thetaDeg - truthThetaDeg;
result.jointRangeErrorM = joint.rangeM - truthRangeM;
result.profileRangeErrorM = profileRangeErrorM;
result.profileBoundary = profileBoundary;
end

function trials = initializeTrials(count, numWidths)
trials.seed = zeros(count, 1);
trials.frontAngleErrorDeg = zeros(count, 1);
trials.frontRangeErrorM = zeros(count, 1);
trials.jointAngleErrorDeg = zeros(count, 1);
trials.jointRangeErrorM = zeros(count, 1);
trials.profileRangeErrorM = zeros(count, numWidths);
trials.profileBoundary = false(count, numWidths);
end

function packed = packBatch(batch, numWidths)
packed = initializeTrials(numel(batch), numWidths);
fields = ["seed", "frontAngleErrorDeg", "frontRangeErrorM", ...
    "jointAngleErrorDeg", "jointRangeErrorM"];
for row = 1:numel(batch)
    for field = fields
        packed.(field)(row) = batch{row}.(field);
    end
    packed.profileRangeErrorM(row, :) = batch{row}.profileRangeErrorM;
    packed.profileBoundary(row, :) = batch{row}.profileBoundary;
end
end

function combined = appendTrials(existing, added)
combined = existing;
fields = string(fieldnames(existing));
for field = fields.'
    combined.(field) = [existing.(field); added.(field)];
end
end

function [details, methodSummary, pairedByCell, aggregateSummary, ...
    aggregatePaired, mechanism] = summarizeResults( ...
    design, cellTrials, lambda, widthsM, balancedCount, sequentialZ)
details = table();
for cellIndex = 1:height(design)
    trials = cellTrials{cellIndex};
    count = numel(trials.seed);
    cellColumn = repmat(design.cellIndex(cellIndex), count, 1);
    thetaColumn = repmat(design.truthThetaDeg(cellIndex), count, 1);
    rangeColumn = repmat(design.truthRangeM(cellIndex), count, 1);
    snrColumn = repmat(design.snrDb(cellIndex), count, 1);
    fixed1ErrorM = trials.frontRangeErrorM + lambda ...
        * (trials.profileRangeErrorM(:, 1) - trials.frontRangeErrorM);
    fixed2ErrorM = trials.frontRangeErrorM + lambda ...
        * (trials.profileRangeErrorM(:, 2) - trials.frontRangeErrorM);
    block = table(cellColumn, thetaColumn, rangeColumn, snrColumn, ...
        trials.seed, trials.frontAngleErrorDeg, ...
        trials.frontRangeErrorM, trials.jointAngleErrorDeg, ...
        trials.jointRangeErrorM, trials.profileRangeErrorM(:, 1), ...
        trials.profileRangeErrorM(:, 2), fixed1ErrorM, fixed2ErrorM, ...
        trials.profileBoundary(:, 1), trials.profileBoundary(:, 2));
    block.Properties.VariableNames = ["cellIndex", "truthThetaDeg", ...
        "truthRangeM", "snrDb", "seed", "frontAngleErrorDeg", ...
        "frontRangeErrorM", "jointAngleErrorDeg", ...
        "jointRangeErrorM", "profile1RangeErrorM", ...
        "profile2RangeErrorM", "fixed1RangeErrorM", ...
        "fixed2RangeErrorM", "profile1Boundary", ...
        "profile2Boundary"];
    details = [details; block]; %#ok<AGROW>
end

methodNames = ["Enhanced full-spectrum front"; ...
    "Zhang-EF-513-v1 joint 2-D MUSIC"; ...
    "Fixed 0.9 profile, 1 m"; "Fixed 0.9 profile, 2 m"];
numMethods = numel(methodNames);
numRows = height(design) * numMethods;
method = repmat(methodNames, height(design), 1);
cellIndex = repelem(design.cellIndex, numMethods);
truthThetaDeg = repelem(design.truthThetaDeg, numMethods);
truthRangeM = repelem(design.truthRangeM, numMethods);
snrDb = repelem(design.snrDb, numMethods);
sampleCount = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
for designIndex = 1:height(design)
    chosen = details.cellIndex == design.cellIndex(designIndex);
    rows = (designIndex - 1) * numMethods + (1:numMethods);
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(details.frontAngleErrorDeg(chosen)); ...
        repmat(rms(details.jointAngleErrorDeg(chosen)), 3, 1)];
    rangeRmseM(rows) = [rms(details.frontRangeErrorM(chosen)); ...
        rms(details.jointRangeErrorM(chosen)); ...
        rms(details.fixed1RangeErrorM(chosen)); ...
        rms(details.fixed2RangeErrorM(chosen))];
end
methodSummary = table(method, cellIndex, truthThetaDeg, truthRangeM, ...
    snrDb, sampleCount, angleRmseDeg, rangeRmseM);

comparisonNames = ["Fixed 1 m minus Zhang"; ...
    "Fixed 2 m minus Zhang"; "Fixed 1 m minus fixed 2 m"];
pairedByCell = pairedTable( ...
    details, design, comparisonNames, sequentialZ);
balancedDetails = balancedSubset(details, design, balancedCount);
[aggregateSummary, aggregatePaired] = aggregateTables( ...
    balancedDetails, design, methodNames, comparisonNames);

mechanismSnrDb = unique(design.snrDb, "stable");
mechanismSampleCount = zeros(size(mechanismSnrDb));
profile1BoundaryRate = zeros(size(mechanismSnrDb));
profile2BoundaryRate = zeros(size(mechanismSnrDb));
fixed1ImproveVsZhangRate = zeros(size(mechanismSnrDb));
fixed2ImproveVsZhangRate = zeros(size(mechanismSnrDb));
for snrIndex = 1:numel(mechanismSnrDb)
    chosen = balancedDetails.snrDb == mechanismSnrDb(snrIndex);
    mechanismSampleCount(snrIndex) = sum(chosen);
    profile1BoundaryRate(snrIndex) = mean( ...
        balancedDetails.profile1Boundary(chosen));
    profile2BoundaryRate(snrIndex) = mean( ...
        balancedDetails.profile2Boundary(chosen));
    fixed1ImproveVsZhangRate(snrIndex) = mean( ...
        balancedDetails.fixed1RangeErrorM(chosen).^2 ...
        < balancedDetails.jointRangeErrorM(chosen).^2);
    fixed2ImproveVsZhangRate(snrIndex) = mean( ...
        balancedDetails.fixed2RangeErrorM(chosen).^2 ...
        < balancedDetails.jointRangeErrorM(chosen).^2);
end
mechanism = table(mechanismSnrDb, mechanismSampleCount, ...
    profile1BoundaryRate, profile2BoundaryRate, ...
    fixed1ImproveVsZhangRate, fixed2ImproveVsZhangRate);
mechanism.Properties.VariableNames(1:2) = ["snrDb", "sampleCount"];

assert(numel(widthsM) == 2 && widthsM(1) == 1 && widthsM(2) == 2, ...
    "fsjad:Round18UnexpectedProfileWidths");
end

function balanced = balancedSubset(details, design, countPerCell)
chosen = false(height(details), 1);
for designIndex = 1:height(design)
    rows = find(details.cellIndex == design.cellIndex(designIndex));
    assert(numel(rows) >= countPerCell, ...
        "fsjad:Round18InsufficientBalancedTrials");
    chosen(rows(1:countPerCell)) = true;
end
balanced = details(chosen, :);
end

function paired = pairedTable( ...
    details, design, comparisonNames, sequentialZ)
numComparisons = numel(comparisonNames);
comparison = repmat(comparisonNames, height(design), 1);
cellIndex = repelem(design.cellIndex, numComparisons);
truthThetaDeg = repelem(design.truthThetaDeg, numComparisons);
truthRangeM = repelem(design.truthRangeM, numComparisons);
snrDb = repelem(design.snrDb, numComparisons);
sampleCount = zeros(size(cellIndex));
mseChange = zeros(size(cellIndex));
sequential95Lower = zeros(size(cellIndex));
sequential95Upper = zeros(size(cellIndex));
for designIndex = 1:height(design)
    chosen = details.cellIndex == design.cellIndex(designIndex);
    pairs = {details.fixed1RangeErrorM(chosen), ...
        details.jointRangeErrorM(chosen); ...
        details.fixed2RangeErrorM(chosen), ...
        details.jointRangeErrorM(chosen); ...
        details.fixed1RangeErrorM(chosen), ...
        details.fixed2RangeErrorM(chosen)};
    for comparisonIndex = 1:numComparisons
        row = (designIndex - 1) * numComparisons + comparisonIndex;
        sampleCount(row) = sum(chosen);
        [mseChange(row), sequential95Lower(row), ...
            sequential95Upper(row)] = interval( ...
            pairs{comparisonIndex, 1}, pairs{comparisonIndex, 2}, ...
            sequentialZ);
    end
end
paired = table(comparison, cellIndex, truthThetaDeg, truthRangeM, ...
    snrDb, sampleCount, mseChange, sequential95Lower, ...
    sequential95Upper);
end

function [summary, paired] = aggregateTables( ...
    details, design, methodNames, comparisonNames)
snrValues = unique(design.snrDb, "stable");
numMethods = numel(methodNames);
method = repmat(methodNames, numel(snrValues), 1);
snrDb = repelem(snrValues, numMethods);
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
for snrIndex = 1:numel(snrValues)
    chosen = details.snrDb == snrValues(snrIndex);
    rows = (snrIndex - 1) * numMethods + (1:numMethods);
    sampleCount(rows) = sum(chosen);
    angleRmseDeg(rows) = [rms(details.frontAngleErrorDeg(chosen)); ...
        repmat(rms(details.jointAngleErrorDeg(chosen)), 3, 1)];
    rangeRmseM(rows) = [rms(details.frontRangeErrorM(chosen)); ...
        rms(details.jointRangeErrorM(chosen)); ...
        rms(details.fixed1RangeErrorM(chosen)); ...
        rms(details.fixed2RangeErrorM(chosen))];
end
summary = table(method, snrDb, sampleCount, angleRmseDeg, rangeRmseM);

numComparisons = numel(comparisonNames);
comparison = repmat(comparisonNames, numel(snrValues), 1);
pairedSnrDb = repelem(snrValues, numComparisons);
pairedCount = zeros(size(pairedSnrDb));
mseChange = zeros(size(pairedSnrDb));
ci95Lower = zeros(size(pairedSnrDb));
ci95Upper = zeros(size(pairedSnrDb));
for snrIndex = 1:numel(snrValues)
    chosen = details.snrDb == snrValues(snrIndex);
    pairs = {details.fixed1RangeErrorM(chosen), ...
        details.jointRangeErrorM(chosen); ...
        details.fixed2RangeErrorM(chosen), ...
        details.jointRangeErrorM(chosen); ...
        details.fixed1RangeErrorM(chosen), ...
        details.fixed2RangeErrorM(chosen)};
    for comparisonIndex = 1:numComparisons
        row = (snrIndex - 1) * numComparisons + comparisonIndex;
        pairedCount(row) = sum(chosen);
        [mseChange(row), ci95Lower(row), ci95Upper(row)] = interval( ...
            pairs{comparisonIndex, 1}, pairs{comparisonIndex, 2});
    end
end
paired = table(comparison, pairedSnrDb, pairedCount, mseChange, ...
    ci95Lower, ci95Upper);
paired.Properties.VariableNames(2:3) = ["snrDb", "sampleCount"];
end

function [change, lower, upper] = interval( ...
    methodError, referenceError, zValue)
if nargin < 3
    zValue = 1.96;
end
squaredChange = methodError.^2 - referenceError.^2;
change = mean(squaredChange);
halfWidth = zValue * std(squaredChange) / sqrt(numel(squaredChange));
lower = change - halfWidth;
upper = change + halfWidth;
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

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function plotResults(summary, pairedByCell, snrValues, thetaValues, ...
    rangeValues, outputFile)
figureHandle = figure("Visible", "off", "Color", "w", ...
    "Position", [100, 100, 1180, 760]);
layout = tiledlayout(2, 2, "TileSpacing", "compact", ...
    "Padding", "compact");
axisHandle = nexttile(layout);
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
ylabel(axisHandle, "Aggregate range RMSE (m)");
legend(axisHandle, methods, "Location", "best");

for snrIndex = 1:numel(snrValues)
    axisHandle = nexttile(layout);
    chosen = pairedByCell.comparison == "Fixed 1 m minus Zhang" ...
        & pairedByCell.snrDb == snrValues(snrIndex);
    ratio = nan(numel(thetaValues), numel(rangeValues));
    rows = find(chosen);
    for rowIndex = 1:numel(rows)
        row = rows(rowIndex);
        thetaIndex = find(thetaValues == ...
            pairedByCell.truthThetaDeg(row), 1);
        rangeIndex = find(rangeValues == ...
            pairedByCell.truthRangeM(row), 1);
        ratio(thetaIndex, rangeIndex) = pairedByCell.mseChange(row);
    end
    imagesc(axisHandle, rangeValues, thetaValues, ratio);
    set(axisHandle, "YDir", "normal");
    colorbar(axisHandle);
    xlabel(axisHandle, "Range (m)");
    ylabel(axisHandle, "Angle (deg)");
    title(axisHandle, sprintf("Fixed 1 m - Zhang MSE at %d dB", ...
        snrValues(snrIndex)));
end
title(layout, "Round 18 cross-location generalization");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
close(figureHandle);
end
