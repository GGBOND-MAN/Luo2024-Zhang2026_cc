function run_tuned_end_to_end_validation
%RUN_TUNED_END_TO_END_VALIDATION Validate frozen front-end and MUSIC tuning.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

defaultCfg = jad.defaultConfig();
tunedCfg = defaultCfg;
tunedCfg.subarraySize = 96;
tunedCfg.numSubarrays = tunedCfg.numAntennas - tunedCfg.subarraySize + 1;
tunedCfg.numFusionCarriers = 33;
tunedCfg.localHalfWidthDeg = 1.5;
tunedCfg.localHalfWidthM = 0.25;
tunedCfg.gridSizes = [41, 31, 21];
scan = fsjad.prepareScan(defaultCfg);
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];

snrDbValues = [-10, 0, 10];
numTrialsPerSnr = 15;
numObservations = numel(snrDbValues) * numTrialsPerSnr;
snrDb = repelem(snrDbValues(:), numTrialsPerSnr);
stream = RandStream("mt19937ar", Seed=defaultCfg.randomSeed + 1201);
truthThetaDeg = -57.3 + 114.6 * rand(stream, numObservations, 1);
truthRangeM = 17.2 + 30.6 * rand(stream, numObservations, 1);

centerCarrier = round(defaultCfg.numSubcarriers / 2);
maxCarrierIndex = (centerCarrier-16:centerCarrier+16).';
defaultColumns = (15:19).';
defaultCarrierIndex = maxCarrierIndex(defaultColumns);
scalarObservation = complex(zeros(defaultCfg.numSubcarriers, ...
    numObservations));
snapshots = complex(zeros(defaultCfg.numAntennas, ...
    numel(maxCarrierIndex), numObservations));
for observationIndex = 1:numObservations
    truthResponse = fsjad.exactSpectralResponse(defaultCfg, ...
        deg2rad(truthThetaDeg(observationIndex)), ...
        truthRangeM(observationIndex), scan);
    signalPower = mean(abs(truthResponse).^2);
    noiseVariance = signalPower / 10^(snrDb(observationIndex) / 10);
    beta = exp(1i * 2 * pi * rand(stream));
    noise = sqrt(noiseVariance / 2) * ( ...
        randn(stream, defaultCfg.numSubcarriers, 1) ...
        + 1i * randn(stream, defaultCfg.numSubcarriers, 1));
    scalarObservation(:, observationIndex) = beta * truthResponse + noise;
    snapshots(:, :, observationIndex) = jad.simulateSnapshots( ...
        defaultCfg, truthThetaDeg(observationIndex), ...
        truthRangeM(observationIndex), snrDb(observationIndex), ...
        maxCarrierIndex, stream);
end

methodNames = ["Default front + default MUSIC"; ...
    "Default front + tuned MUSIC"; ...
    "Tuned front + tuned MUSIC"; ...
    "Truth center + tuned MUSIC"];
numMethods = numel(methodNames);
coarseThetaDeg = zeros(numMethods, numObservations);
coarseRangeM = zeros(numMethods, numObservations);
finalThetaDeg = zeros(numMethods, numObservations);
finalRangeM = zeros(numMethods, numObservations);
frontRuntimeMs = zeros(numMethods, numObservations);
musicRuntimeMs = zeros(numMethods, numObservations);
frontResponseEvaluations = zeros(numMethods, numObservations);
boundaryPeak = false(numMethods, numObservations);
completedSnrCount = 0;

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round5");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
checkpointFile = fullfile(outputFolder, ...
    "tuned_end_to_end_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    coarseThetaDeg = checkpoint.coarseThetaDeg;
    coarseRangeM = checkpoint.coarseRangeM;
    finalThetaDeg = checkpoint.finalThetaDeg;
    finalRangeM = checkpoint.finalRangeM;
    frontRuntimeMs = checkpoint.frontRuntimeMs;
    musicRuntimeMs = checkpoint.musicRuntimeMs;
    frontResponseEvaluations = checkpoint.frontResponseEvaluations;
    boundaryPeak = checkpoint.boundaryPeak;
    completedSnrCount = checkpoint.completedSnrCount;
end

for snrIndex = completedSnrCount + 1:numel(snrDbValues)
    observationRows = (snrIndex - 1) * numTrialsPerSnr ...
        + (1:numTrialsPerSnr);
    for observationIndex = observationRows
        timer = tic;
        peakEstimate = fsjad.peakInitializedProfileEstimate( ...
            defaultCfg, scalarObservation(:, observationIndex), scan);
        peakRuntimeMs = 1000 * toc(timer);
        timer = tic;
        tunedFrontEstimate = fsjad.angleMultistartProfileEstimate( ...
            defaultCfg, scalarObservation(:, observationIndex), scan, ...
            frontOffsetsDeg);
        tunedFrontRuntimeMs = 1000 * toc(timer);

        coarseThetaDeg(:, observationIndex) = [peakEstimate.thetaDeg; ...
            peakEstimate.thetaDeg; tunedFrontEstimate.thetaDeg; ...
            truthThetaDeg(observationIndex)];
        coarseRangeM(:, observationIndex) = [peakEstimate.rangeM; ...
            peakEstimate.rangeM; tunedFrontEstimate.rangeM; ...
            truthRangeM(observationIndex)];
        frontRuntimeMs(:, observationIndex) = [peakRuntimeMs; ...
            peakRuntimeMs; tunedFrontRuntimeMs; 0];
        frontResponseEvaluations(:, observationIndex) = [ ...
            peakEstimate.totalResponseEvaluations; ...
            peakEstimate.totalResponseEvaluations; ...
            tunedFrontEstimate.totalResponseEvaluations; 0];

        timer = tic;
        defaultResult = jad.localMusicEstimate(defaultCfg, ...
            snapshots(:, defaultColumns, observationIndex), ...
            defaultCarrierIndex, peakEstimate.thetaDeg, peakEstimate.rangeM);
        musicRuntimeMs(1, observationIndex) = 1000 * toc(timer);
        timer = tic;
        musicOnlyResult = jad.localMusicEstimate(tunedCfg, ...
            snapshots(:, :, observationIndex), maxCarrierIndex, ...
            peakEstimate.thetaDeg, peakEstimate.rangeM);
        musicRuntimeMs(2, observationIndex) = 1000 * toc(timer);
        timer = tic;
        fullyTunedResult = jad.localMusicEstimate(tunedCfg, ...
            snapshots(:, :, observationIndex), maxCarrierIndex, ...
            tunedFrontEstimate.thetaDeg, tunedFrontEstimate.rangeM);
        musicRuntimeMs(3, observationIndex) = 1000 * toc(timer);
        timer = tic;
        oracleResult = jad.localMusicEstimate(tunedCfg, ...
            snapshots(:, :, observationIndex), maxCarrierIndex, ...
            truthThetaDeg(observationIndex), truthRangeM(observationIndex));
        musicRuntimeMs(4, observationIndex) = 1000 * toc(timer);

        finalThetaDeg(:, observationIndex) = [defaultResult.thetaDeg; ...
            musicOnlyResult.thetaDeg; fullyTunedResult.thetaDeg; ...
            oracleResult.thetaDeg];
        finalRangeM(:, observationIndex) = [defaultResult.rangeM; ...
            musicOnlyResult.rangeM; fullyTunedResult.rangeM; ...
            oracleResult.rangeM];
        boundaryPeak(:, observationIndex) = [ ...
            isBoundaryPeak(defaultResult.initialSpectrum); ...
            isBoundaryPeak(musicOnlyResult.initialSpectrum); ...
            isBoundaryPeak(fullyTunedResult.initialSpectrum); ...
            isBoundaryPeak(oracleResult.initialSpectrum)];
        fprintf("End-to-end SNR %g dB trial %d/%d complete.\n", ...
            snrDbValues(snrIndex), observationIndex - observationRows(1) + 1, ...
            numTrialsPerSnr);
    end
    completedSnrCount = snrIndex;
    save(checkpointFile, "coarseThetaDeg", "coarseRangeM", ...
        "finalThetaDeg", "finalRangeM", "frontRuntimeMs", ...
        "musicRuntimeMs", "frontResponseEvaluations", "boundaryPeak", ...
        "completedSnrCount");
end

method = repmat(methodNames, numObservations, 1);
snrDbColumn = repelem(snrDb, numMethods);
truthThetaColumn = repelem(truthThetaDeg, numMethods);
truthRangeColumn = repelem(truthRangeM, numMethods);
coarseAngleError = coarseThetaDeg(:) - truthThetaColumn;
coarseRangeError = coarseRangeM(:) - truthRangeColumn;
finalAngleError = finalThetaDeg(:) - truthThetaColumn;
finalRangeError = finalRangeM(:) - truthRangeColumn;
coarseCaptured = abs(coarseAngleError) <= 1 & abs(coarseRangeError) <= 1;
finalCaptured = abs(finalAngleError) <= 1 & abs(finalRangeError) <= 1;
musicRescued = ~coarseCaptured & finalCaptured;
musicDegraded = coarseCaptured & ~finalCaptured;
boundaryPeak = boundaryPeak(:);
frontRuntimeMs = frontRuntimeMs(:);
musicRuntimeMs = musicRuntimeMs(:);
frontResponseEvaluations = frontResponseEvaluations(:);
totalRuntimeMs = frontRuntimeMs + musicRuntimeMs;
details = table(method, snrDbColumn, truthThetaColumn, truthRangeColumn, ...
    coarseAngleError, coarseRangeError, finalAngleError, finalRangeError, ...
    coarseCaptured, finalCaptured, musicRescued, musicDegraded, ...
    boundaryPeak, frontRuntimeMs, musicRuntimeMs, totalRuntimeMs, ...
    frontResponseEvaluations);
summary = groupsummary(details, ["method", "snrDbColumn"], "mean", ...
    ["coarseAngleError", "coarseRangeError", "finalAngleError", ...
    "finalRangeError", "coarseCaptured", "finalCaptured", ...
    "musicRescued", "musicDegraded", "boundaryPeak", ...
    "frontRuntimeMs", "musicRuntimeMs", "totalRuntimeMs", ...
    "frontResponseEvaluations"]);
summary.coarseAngleRmseDeg = groupRmse(details, summary, ...
    "coarseAngleError");
summary.coarseRangeRmseM = groupRmse(details, summary, ...
    "coarseRangeError");
summary.finalAngleRmseDeg = groupRmse(details, summary, ...
    "finalAngleError");
summary.finalRangeRmseM = groupRmse(details, summary, ...
    "finalRangeError");

writetable(details, fullfile(outputFolder, ...
    "tuned_end_to_end_validation_trials.csv"));
writetable(summary, fullfile(outputFolder, ...
    "tuned_end_to_end_validation_summary.csv"));
save(fullfile(outputFolder, "tuned_end_to_end_validation.mat"), ...
    "defaultCfg", "tunedCfg", "frontOffsetsDeg", "snrDbValues", ...
    "numTrialsPerSnr", "methodNames", "details", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotMetric(summary, methodNames, "mean_finalCaptured", ...
    "Final capture rate", false);
plotMetric(summary, methodNames, "finalRangeRmseM", ...
    "Final range RMSE (m)", true);
title(layout, "Frozen single-path end-to-end validation");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "tuned_end_to_end_validation.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "tuned_end_to_end_validation.fig"));
close(figureHandle);

disp(summary);
end

function boundary = isBoundaryPeak(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundary = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
end

function rmse = groupRmse(details, summary, variableName)
rmse = zeros(height(summary), 1);
for row = 1:height(summary)
    selected = details.method == summary.method(row) ...
        & details.snrDbColumn == summary.snrDbColumn(row);
    rmse(row) = sqrt(mean(details.(variableName)(selected).^2));
end
end

function plotMetric(summary, methodNames, variableName, plotTitle, useLog)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^", "-d"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    if useLog
        semilogy(summary.snrDbColumn(rows), ...
            summary.(variableName)(rows), lineStyle(methodIndex), ...
            LineWidth=1.5, MarkerSize=6);
    else
        plot(summary.snrDbColumn(rows), summary.(variableName)(rows), ...
            lineStyle(methodIndex), LineWidth=1.5, MarkerSize=6);
    end
end
hold off;
grid on;
xlabel("SNR (dB)");
title(plotTitle);
legend(methodNames, Location="best");
end
