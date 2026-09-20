function run_profile_initialization_tuning
%RUN_PROFILE_INITIALIZATION_TUNING Tune 2-D dictionary multistart search.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
snrDbValues = [-10, 0, 10];
numCalibrationPerSnr = 15;
numValidationPerSnr = 30;
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 1001);
calibration = generateScalarData(cfg, scan, snrDbValues, ...
    numCalibrationPerSnr, stream);
validation = generateScalarData(cfg, scan, snrDbValues, ...
    numValidationPerSnr, stream);

bankName = ["5 deg / 2.5 m"; "2 deg / 1 m"; "1 deg / 1 m"];
bankBuildTimeSec = zeros(3, 1);
timer = tic;
coarseBank = fsjad.prepareCandidateBank(cfg, (-60:5:60).', ...
    (15:2.5:50).', scan);
bankBuildTimeSec(1) = toc(timer);
timer = tic;
fineBank = fsjad.prepareCandidateBank(cfg, (-60:1:60).', ...
    (15:1:50).', scan);
bankBuildTimeSec(3) = toc(timer);
mediumRows = mod(fineBank.thetaDeg + 60, 2) == 0;
mediumBank = subsetBank(fineBank, mediumRows);
bankBuildTimeSec(2) = bankBuildTimeSec(3);
banks = {coarseBank; mediumBank; fineBank};
candidateCount = cellfun(@(bank) size(bank.response, 2), banks);

startCandidates = [1, 3, 5];
numConfigurations = numel(banks) * numel(startCandidates);
dictionary = strings(numConfigurations, 1);
numStarts = zeros(numConfigurations, 1);
numBankCandidates = zeros(numConfigurations, 1);
captureRate = zeros(numConfigurations, 1);
angleRmseDeg = zeros(numConfigurations, 1);
rangeRmseM = zeros(numConfigurations, 1);
meanProfileScore = zeros(numConfigurations, 1);
meanScoreGap = nan(numConfigurations, 1);
meanResponseEvaluations = zeros(numConfigurations, 1);
meanMaxStartRuntimeMs = zeros(numConfigurations, 1);
configurationRow = 0;

for bankIndex = 1:numel(banks)
    bankResults = evaluateMaximumStarts(cfg, scan, calibration, ...
        banks{bankIndex}, max(startCandidates));
    for startIndex = 1:numel(startCandidates)
        configurationRow = configurationRow + 1;
        metrics = prefixMetrics(bankResults, calibration, ...
            startCandidates(startIndex));
        dictionary(configurationRow) = bankName(bankIndex);
        numStarts(configurationRow) = startCandidates(startIndex);
        numBankCandidates(configurationRow) = candidateCount(bankIndex);
        captureRate(configurationRow) = metrics.captureRate;
        angleRmseDeg(configurationRow) = metrics.angleRmseDeg;
        rangeRmseM(configurationRow) = metrics.rangeRmseM;
        meanProfileScore(configurationRow) = metrics.meanProfileScore;
        meanScoreGap(configurationRow) = metrics.meanScoreGap;
        meanResponseEvaluations(configurationRow) = ...
            metrics.meanResponseEvaluations;
        meanMaxStartRuntimeMs(configurationRow) = ...
            mean(bankResults.runtimeMs);
    end
    fprintf("Completed profile calibration for %s.\n", bankName(bankIndex));
end

calibrationSummary = table(dictionary, numStarts, numBankCandidates, ...
    captureRate, angleRmseDeg, rangeRmseM, meanProfileScore, ...
    meanScoreGap, meanResponseEvaluations, meanMaxStartRuntimeMs);
calibrationSummary = sortrows(calibrationSummary, ...
    ["captureRate", "rangeRmseM", "meanResponseEvaluations"], ...
    ["descend", "ascend", "ascend"]);
bestDictionary = calibrationSummary.dictionary(1);
bestNumStarts = calibrationSummary.numStarts(1);
bestBankIndex = find(bankName == bestDictionary, 1);
bestBank = banks{bestBankIndex};

validationBank = evaluateSelectedBank(cfg, scan, validation, bestBank, ...
    bestNumStarts, "2-D bank multistart");
validationPeak = evaluatePeakInitialization(cfg, scan, validation, ...
    "Peak-angle initialization");
validationOracle = evaluateOracleInitialization(cfg, scan, validation, ...
    "Truth initialization upper bound");
validationDetails = [validationPeak; validationBank; validationOracle];
validationSummary = groupsummary(validationDetails, ...
    ["method", "snrDb"], "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "profileScore", "scoreGap", "runtimeMs", "responseEvaluations"]);
validationSummary.angleRmseDeg = sqrt( ...
    validationSummary.mean_angleErrorSquared);
validationSummary.rangeRmseM = sqrt( ...
    validationSummary.mean_rangeErrorSquared);

bankBuild = table(bankName, candidateCount, bankBuildTimeSec);
selectedParameter = ["dictionary"; "numStarts"];
selectedValue = [bestDictionary; string(bestNumStarts)];
selected = table(selectedParameter, selectedValue);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round5");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(bankBuild, fullfile(outputFolder, ...
    "profile_tuning_bank_build.csv"));
writetable(calibrationSummary, fullfile(outputFolder, ...
    "profile_tuning_calibration.csv"));
writetable(selected, fullfile(outputFolder, ...
    "profile_tuning_selected.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "profile_tuning_validation_trials.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "profile_tuning_validation_summary.csv"));
save(fullfile(outputFolder, "profile_initialization_tuning.mat"), ...
    "cfg", "snrDbValues", "numCalibrationPerSnr", ...
    "numValidationPerSnr", "bankBuild", "calibrationSummary", ...
    "selected", "validationDetails", "validationSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
hold on;
methods = ["Peak-angle initialization", "2-D bank multistart", ...
    "Truth initialization upper bound"];
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methods)
    rows = validationSummary.method == methods(methodIndex);
    plot(validationSummary.snrDb(rows), ...
        validationSummary.mean_captured(rows), lineStyle(methodIndex), ...
        LineWidth=1.5, MarkerSize=6);
end
hold off; grid on; ylim([0, 1.02]);
xlabel("SNR (dB)"); ylabel("Held-out capture rate");
legend(methods, Location="southeast");
title("Initialization validation");
nexttile;
scatter(calibrationSummary.meanResponseEvaluations, ...
    calibrationSummary.captureRate, 60, ...
    calibrationSummary.numBankCandidates, "filled");
grid on; colorbar;
xlabel("Mean response evaluations"); ylabel("Calibration capture rate");
title("Dictionary and multistart cost");
title(layout, "Tuning full-spectrum global initialization");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "profile_initialization_tuning.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "profile_initialization_tuning.fig"));
close(figureHandle);

disp(bankBuild);
disp(calibrationSummary);
disp(selected);
disp(validationSummary);
end

function data = generateScalarData(cfg, scan, snrValues, numPerSnr, stream)
numRows = numel(snrValues) * numPerSnr;
snrDb = repelem(snrValues(:), numPerSnr);
truthThetaDeg = -57.3 + 114.6 * rand(stream, numRows, 1);
truthRangeM = 17.2 + 30.6 * rand(stream, numRows, 1);
observation = complex(zeros(cfg.numSubcarriers, numRows));
for row = 1:numRows
    truthResponse = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(truthThetaDeg(row)), truthRangeM(row), scan);
    signalPower = mean(abs(truthResponse).^2);
    noiseVariance = signalPower / 10^(snrDb(row) / 10);
    beta = exp(1i * 2 * pi * rand(stream));
    noise = sqrt(noiseVariance / 2) * ( ...
        randn(stream, cfg.numSubcarriers, 1) ...
        + 1i * randn(stream, cfg.numSubcarriers, 1));
    observation(:, row) = beta * truthResponse + noise;
end
data = table(snrDb, truthThetaDeg, truthRangeM);
data.Properties.UserData.observation = observation;
end

function result = evaluateMaximumStarts(cfg, scan, data, bank, maxStarts)
numRows = height(data);
thetaDeg = zeros(maxStarts, numRows);
rangeM = zeros(maxStarts, numRows);
score = zeros(maxStarts, numRows);
iterations = zeros(maxStarts, numRows);
runtimeMs = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    estimate = fsjad.bankInitializedProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), bank, scan, ...
        maxStarts, 2, 1);
    runtimeMs(row) = 1000 * toc(timer);
    thetaDeg(:, row) = estimate.refinedThetaDeg;
    rangeM(:, row) = estimate.refinedRangeM;
    score(:, row) = estimate.refinedScore;
    iterations(:, row) = estimate.refinedIterations;
end
result.thetaDeg = thetaDeg;
result.rangeM = rangeM;
result.score = score;
result.iterations = iterations;
result.runtimeMs = runtimeMs;
end

function metrics = prefixMetrics(result, data, numStarts)
[bestScore, bestStart] = max(result.score(1:numStarts, :), [], 1);
columnIndex = 1:height(data);
linearIndex = sub2ind(size(result.score), bestStart, columnIndex);
thetaDeg = result.thetaDeg(linearIndex).';
rangeM = result.rangeM(linearIndex).';
angleError = thetaDeg - data.truthThetaDeg;
rangeError = rangeM - data.truthRangeM;
metrics.captureRate = mean(abs(angleError) <= 1 & abs(rangeError) <= 1);
metrics.angleRmseDeg = sqrt(mean(angleError.^2));
metrics.rangeRmseM = sqrt(mean(rangeError.^2));
metrics.meanProfileScore = mean(bestScore);
if numStarts > 1
    sortedScore = sort(result.score(1:numStarts, :), 1, "descend");
    metrics.meanScoreGap = mean(sortedScore(1, :) - sortedScore(2, :));
else
    metrics.meanScoreGap = NaN;
end
metrics.meanResponseEvaluations = mean(sum( ...
    result.iterations(1:numStarts, :) + 1, 1));
end

function details = evaluateSelectedBank(cfg, scan, data, bank, numStarts, ...
    methodName)
numRows = height(data);
method = repmat(string(methodName), numRows, 1);
snrDb = data.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
profileScore = zeros(numRows, 1);
scoreGap = zeros(numRows, 1);
runtimeMs = zeros(numRows, 1);
responseEvaluations = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    estimate = fsjad.bankInitializedProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), bank, scan, ...
        numStarts, 2, 1);
    runtimeMs(row) = 1000 * toc(timer);
    angleError = estimate.thetaDeg - data.truthThetaDeg(row);
    rangeError = estimate.rangeM - data.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    profileScore(row) = estimate.score;
    scoreGap(row) = estimate.scoreGap;
    responseEvaluations(row) = estimate.totalResponseEvaluations;
end
details = table(method, snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, profileScore, scoreGap, runtimeMs, responseEvaluations);
end

function details = evaluatePeakInitialization(cfg, scan, data, methodName)
numRows = height(data);
method = repmat(string(methodName), numRows, 1);
snrDb = data.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
profileScore = zeros(numRows, 1);
scoreGap = nan(numRows, 1);
runtimeMs = zeros(numRows, 1);
responseEvaluations = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    estimate = fsjad.peakInitializedProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), scan);
    runtimeMs(row) = 1000 * toc(timer);
    angleError = estimate.thetaDeg - data.truthThetaDeg(row);
    rangeError = estimate.rangeM - data.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    profileScore(row) = estimate.score;
    responseEvaluations(row) = estimate.totalResponseEvaluations;
end
details = table(method, snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, profileScore, scoreGap, runtimeMs, responseEvaluations);
end

function details = evaluateOracleInitialization(cfg, scan, data, methodName)
numRows = height(data);
method = repmat(string(methodName), numRows, 1);
snrDb = data.snrDb;
angleErrorSquared = zeros(numRows, 1);
rangeErrorSquared = zeros(numRows, 1);
captured = false(numRows, 1);
profileScore = zeros(numRows, 1);
scoreGap = nan(numRows, 1);
runtimeMs = zeros(numRows, 1);
responseEvaluations = zeros(numRows, 1);
for row = 1:numRows
    timer = tic;
    estimate = fsjad.refineProfileEstimate(cfg, ...
        data.Properties.UserData.observation(:, row), ...
        data.truthThetaDeg(row), data.truthRangeM(row), scan, 20);
    runtimeMs(row) = 1000 * toc(timer);
    angleError = estimate.thetaDeg - data.truthThetaDeg(row);
    rangeError = estimate.rangeM - data.truthRangeM(row);
    angleErrorSquared(row) = angleError^2;
    rangeErrorSquared(row) = rangeError^2;
    captured(row) = abs(angleError) <= 1 && abs(rangeError) <= 1;
    profileScore(row) = estimate.score;
    responseEvaluations(row) = estimate.responseEvaluations;
end
details = table(method, snrDb, angleErrorSquared, rangeErrorSquared, ...
    captured, profileScore, scoreGap, runtimeMs, responseEvaluations);
end

function subset = subsetBank(bank, rows)
subset.thetaDeg = bank.thetaDeg(rows);
subset.rangeM = bank.rangeM(rows);
subset.response = bank.response(:, rows);
subset.energy = bank.energy(rows);
end
