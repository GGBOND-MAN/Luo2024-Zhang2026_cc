function run_confidence_gate_screening
%RUN_CONFIDENCE_GATE_SCREENING Screen observable range-update gates.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
round7Folder = fullfile(projectFolder, "results", "full_spectrum", "round7");
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round8");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

snrValues = (-10:5:20).';
calibration = loadTrials(fullfile(round7Folder, ...
    "adaptive_gate_calibration_checkpoint.mat"), snrValues, 12);
validation = loadTrials(fullfile(round7Folder, ...
    "adaptive_gate_validation_checkpoint.mat"), snrValues, 30);

snrThresholdsDb = snrValues;
deltaThresholdsM = [0; 0.001; 0.0025; 0.005; 0.0075; 0.01; ...
    0.0125; 0.015; 0.0175; 0.02; inf];
boundaryModes = ["all"; "interior"; "boundary"];
calibrationScores = evaluateCandidates(calibration, snrThresholdsDb, ...
    deltaThresholdsM, boundaryModes);
calibrationRanking = sortrows(calibrationScores, ...
    ["rangeRmseM", "rangeMseChange", "updateRate"], ...
    ["ascend", "ascend", "descend"]);
selected = calibrationRanking(1, :);

selectedUse = applyGate(validation, selected.maxSnrDb, ...
    selected.maxAbsDeltaM, selected.boundaryMode);
oracleUse = validation.musicRangeErrorM.^2 ...
    < validation.frontRangeErrorM.^2;
[validationDetails, validationSummary] = summarizeValidation( ...
    validation, selectedUse, oracleUse, snrValues);

writetable(calibrationScores, fullfile(outputFolder, ...
    "confidence_gate_calibration_scores.csv"));
writetable(calibrationRanking, fullfile(outputFolder, ...
    "confidence_gate_calibration_ranking.csv"));
writetable(selected, fullfile(outputFolder, ...
    "confidence_gate_selected.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "confidence_gate_validation_trials.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "confidence_gate_validation_summary.csv"));
save(fullfile(outputFolder, "confidence_gate_screening.mat"), ...
    "calibration", "validation", "calibrationScores", ...
    "calibrationRanking", "selected", "validationDetails", ...
    "validationSummary");

plotSummary(validationSummary, fullfile(outputFolder, ...
    "confidence_gate_screening.png"));
disp(calibrationRanking(1:min(12, height(calibrationRanking)), :));
disp(selected);
disp(validationSummary);
end

function trials = loadTrials(checkpointFile, snrValues, numPerSnr)
checkpoint = load(checkpointFile);
snrDb = repelem(snrValues, numPerSnr);
frontAngleErrorDeg = checkpoint.frontAngleErrorDeg;
frontRangeErrorM = checkpoint.frontRangeErrorM;
musicAngleErrorDeg = checkpoint.musicAngleErrorDeg;
musicRangeErrorM = checkpoint.musicRangeErrorM;
musicBoundaryPeak = checkpoint.musicBoundaryPeak;
rangeDeltaM = musicRangeErrorM - frontRangeErrorM;
trials = table(snrDb, frontAngleErrorDeg, frontRangeErrorM, ...
    musicAngleErrorDeg, musicRangeErrorM, musicBoundaryPeak, rangeDeltaM);
end

function scores = evaluateCandidates(trials, snrThresholds, ...
    deltaThresholds, boundaryModes)
numCandidates = 1 + numel(snrThresholds) * numel(deltaThresholds) ...
    * numel(boundaryModes);
gateType = strings(numCandidates, 1);
maxSnrDb = zeros(numCandidates, 1);
maxAbsDeltaM = zeros(numCandidates, 1);
boundaryMode = strings(numCandidates, 1);
rangeRmseM = zeros(numCandidates, 1);
rangeMseChange = zeros(numCandidates, 1);
updateRate = zeros(numCandidates, 1);
improvementRate = zeros(numCandidates, 1);

candidateIndex = 1;
gateType(candidateIndex) = "none";
maxSnrDb(candidateIndex) = -inf;
maxAbsDeltaM(candidateIndex) = 0;
boundaryMode(candidateIndex) = "none";
[rangeRmseM(candidateIndex), rangeMseChange(candidateIndex), ...
    updateRate(candidateIndex), improvementRate(candidateIndex)] = ...
    scoreGate(trials, false(height(trials), 1));

for snrIndex = 1:numel(snrThresholds)
    for deltaIndex = 1:numel(deltaThresholds)
        for modeIndex = 1:numel(boundaryModes)
            candidateIndex = candidateIndex + 1;
            gateType(candidateIndex) = "confidence";
            maxSnrDb(candidateIndex) = snrThresholds(snrIndex);
            maxAbsDeltaM(candidateIndex) = deltaThresholds(deltaIndex);
            boundaryMode(candidateIndex) = boundaryModes(modeIndex);
            useMusic = applyGate(trials, maxSnrDb(candidateIndex), ...
                maxAbsDeltaM(candidateIndex), boundaryMode(candidateIndex));
            [rangeRmseM(candidateIndex), rangeMseChange(candidateIndex), ...
                updateRate(candidateIndex), improvementRate(candidateIndex)] = ...
                scoreGate(trials, useMusic);
        end
    end
end
scores = table(gateType, maxSnrDb, maxAbsDeltaM, boundaryMode, ...
    rangeRmseM, rangeMseChange, updateRate, improvementRate);
end

function useMusic = applyGate(trials, maxSnrDb, maxAbsDeltaM, boundaryMode)
useMusic = trials.snrDb <= maxSnrDb ...
    & abs(trials.rangeDeltaM) <= maxAbsDeltaM;
if boundaryMode == "interior"
    useMusic = useMusic & ~trials.musicBoundaryPeak;
elseif boundaryMode == "boundary"
    useMusic = useMusic & trials.musicBoundaryPeak;
elseif boundaryMode == "none"
    useMusic(:) = false;
end
end

function [rmse, mseChange, updateRate, improvementRate] = ...
    scoreGate(trials, useMusic)
hybridError = trials.frontRangeErrorM;
hybridError(useMusic) = trials.musicRangeErrorM(useMusic);
frontSquaredError = trials.frontRangeErrorM.^2;
hybridSquaredError = hybridError.^2;
rmse = sqrt(mean(hybridSquaredError));
mseChange = mean(hybridSquaredError - frontSquaredError);
updateRate = mean(useMusic);
improvementRate = mean(hybridSquaredError < frontSquaredError);
end

function [details, summary] = summarizeValidation( ...
    trials, selectedUse, oracleUse, snrValues)
numTrials = height(trials);
methodNames = ["Full-spectrum front"; "Fixed narrow MUSIC"; ...
    "Selected confidence gate"; "Oracle gate"];
numMethods = numel(methodNames);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(trials.snrDb, numMethods);

selectedRangeError = trials.frontRangeErrorM;
selectedRangeError(selectedUse) = trials.musicRangeErrorM(selectedUse);
oracleRangeError = trials.frontRangeErrorM;
oracleRangeError(oracleUse) = trials.musicRangeErrorM(oracleUse);
angleErrorDeg = [trials.frontAngleErrorDeg.'; ...
    trials.musicAngleErrorDeg.'; trials.musicAngleErrorDeg.'; ...
    trials.musicAngleErrorDeg.'];
rangeErrorM = [trials.frontRangeErrorM.'; ...
    trials.musicRangeErrorM.'; selectedRangeError.'; oracleRangeError.'];
updatedRange = [false(1, numTrials); true(1, numTrials); ...
    selectedUse.'; oracleUse.'];
boundaryPeak = [false(1, numTrials); trials.musicBoundaryPeak.'; ...
    trials.musicBoundaryPeak.'; trials.musicBoundaryPeak.'];
details = table(method, snrDb, angleErrorDeg(:), rangeErrorM(:), ...
    updatedRange(:), boundaryPeak(:), VariableNames=["method", "snrDb", ...
    "angleErrorDeg", "rangeErrorM", "updatedRange", "boundaryPeak"]);

numRows = numMethods * numel(snrValues);
summaryMethod = strings(numRows, 1);
summarySnrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
updateRate = zeros(numRows, 1);
row = 0;
for methodIndex = 1:numMethods
    for snrIndex = 1:numel(snrValues)
        row = row + 1;
        rows = details.method == methodNames(methodIndex) ...
            & details.snrDb == snrValues(snrIndex);
        summaryMethod(row) = methodNames(methodIndex);
        summarySnrDb(row) = snrValues(snrIndex);
        angleRmseDeg(row) = sqrt(mean(details.angleErrorDeg(rows).^2));
        rangeRmseM(row) = sqrt(mean(details.rangeErrorM(rows).^2));
        updateRate(row) = mean(details.updatedRange(rows));
    end
end
summary = table(summaryMethod, summarySnrDb, angleRmseDeg, ...
    rangeRmseM, updateRate, VariableNames=["method", "snrDb", ...
    "angleRmseDeg", "rangeRmseM", "updateRate"]);
end

function plotSummary(summary, outputFile)
figureHandle = figure(Color="w", Position=[100, 100, 680, 440]);
axisHandle = axes(figureHandle);
axisHandle.YScale = "log";
hold(axisHandle, "on");
methodNames = unique(summary.method, "stable");
lineStyles = ["-o", "-s", "-^", "--d"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.rangeRmseM(rows), ...
        lineStyles(methodIndex), LineWidth=1.5, MarkerSize=6);
end
hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Range RMSE (m)");
legend(axisHandle, methodNames, Location="best");
title(axisHandle, "Observable confidence gate screening");
exportgraphics(figureHandle, outputFile, Resolution=180);
close(figureHandle);
end
