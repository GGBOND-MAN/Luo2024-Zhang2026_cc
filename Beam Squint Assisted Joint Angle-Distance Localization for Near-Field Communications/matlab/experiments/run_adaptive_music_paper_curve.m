function run_adaptive_music_paper_curve
%RUN_ADAPTIVE_MUSIC_PAPER_CURVE Tune gating and compare with paper Fig. 10.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.localHalfWidthDeg = 0.02;
cfg.localHalfWidthM = 0.02;
cfg.gridSizes = [61, 41, 31];
scan = fsjad.prepareScan(cfg);
fusionCarriers = 513;
frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
truthThetaDeg = 15;
truthRangeM = 30;
snrDbValues = (-10:5:20).';
numCalibrationPerSnr = 12;
numValidationPerSnr = 30;

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round7");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
calibration = runTrials(cfg, scan, snrDbValues, numCalibrationPerSnr, ...
    truthThetaDeg, truthRangeM, fusionCarriers, frontOffsetsDeg, ...
    cfg.randomSeed + 1601, fullfile(outputFolder, ...
    "adaptive_gate_calibration_checkpoint.mat"));

thresholdCandidatesDb = [-15; snrDbValues];
thresholdSummary = evaluateThresholds(calibration, thresholdCandidatesDb);
thresholdRanking = sortrows(thresholdSummary, ...
    ["rangeRmseM", "angleRmseDeg"], ["ascend", "ascend"]);
selectedThresholdDb = thresholdRanking.rangeMusicMaxSnrDb(1);

validation = runTrials(cfg, scan, snrDbValues, numValidationPerSnr, ...
    truthThetaDeg, truthRangeM, fusionCarriers, frontOffsetsDeg, ...
    cfg.randomSeed + 1701, fullfile(outputFolder, ...
    "adaptive_gate_validation_checkpoint.mat"));
[validationDetails, validationSummary] = fsjad.summarizeAdaptiveMethods( ...
    validation, selectedThresholdDb);
published = publishedFigure10();
comparison = compareWithPublished(validationSummary, published);

selectedParameter = ["fusionCarriers"; "angleHalfWidthDeg"; ...
    "rangeHalfWidthM"; "rangeMusicMaxSnrDb"];
selectedValue = [fusionCarriers; cfg.localHalfWidthDeg; ...
    cfg.localHalfWidthM; selectedThresholdDb];
selected = table(selectedParameter, selectedValue);

writetable(calibration, fullfile(outputFolder, ...
    "adaptive_gate_calibration_trials.csv"));
writetable(thresholdSummary, fullfile(outputFolder, ...
    "adaptive_gate_threshold_summary.csv"));
writetable(thresholdRanking, fullfile(outputFolder, ...
    "adaptive_gate_threshold_ranking.csv"));
writetable(selected, fullfile(outputFolder, ...
    "adaptive_gate_selected.csv"));
writetable(validationDetails, fullfile(outputFolder, ...
    "adaptive_gate_validation_trials.csv"));
writetable(validationSummary, fullfile(outputFolder, ...
    "adaptive_gate_validation_summary.csv"));
writetable(comparison, fullfile(outputFolder, ...
    "adaptive_gate_paper_comparison.csv"));
save(fullfile(outputFolder, "adaptive_music_paper_curve.mat"), ...
    "cfg", "fusionCarriers", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "numCalibrationPerSnr", "numValidationPerSnr", ...
    "thresholdSummary", "thresholdRanking", "selected", ...
    "validationDetails", "validationSummary", "published", ...
    "comparison");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotComparison(validationSummary, published, "angleRmseDeg", ...
    "proposedAngleRmseDeg", "Angle RMSE (deg)");
plotComparison(validationSummary, published, "rangeRmseM", ...
    "proposedRangeRmseM", "Range RMSE (m)");
title(layout, "Adaptive single-path estimator vs published Fig. 10");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "adaptive_music_paper_curve.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "adaptive_music_paper_curve.fig"));
close(figureHandle);

disp(thresholdRanking);
disp(selected);
disp(validationSummary);
disp(comparison);
end

function trials = runTrials(cfg, scan, snrValues, numPerSnr, ...
    truthThetaDeg, truthRangeM, fusionCarriers, frontOffsetsDeg, ...
    seedBase, checkpointFile)
numSnr = numel(snrValues);
numRows = numSnr * numPerSnr;
snrDb = repelem(snrValues, numPerSnr);
frontAngleErrorDeg = zeros(numRows, 1);
frontRangeErrorM = zeros(numRows, 1);
musicAngleErrorDeg = zeros(numRows, 1);
musicRangeErrorM = zeros(numRows, 1);
musicBoundaryPeak = false(numRows, 1);
completedSnrCount = 0;
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    frontAngleErrorDeg = checkpoint.frontAngleErrorDeg;
    frontRangeErrorM = checkpoint.frontRangeErrorM;
    musicAngleErrorDeg = checkpoint.musicAngleErrorDeg;
    musicRangeErrorM = checkpoint.musicRangeErrorM;
    musicBoundaryPeak = checkpoint.musicBoundaryPeak;
    completedSnrCount = checkpoint.completedSnrCount;
end

truthResponse = fsjad.exactSpectralResponse(cfg, ...
    deg2rad(truthThetaDeg), truthRangeM, scan);
signalPower = mean(abs(truthResponse).^2);
for snrIndex = completedSnrCount + 1:numSnr
    stream = RandStream("mt19937ar", Seed=seedBase + snrIndex);
    rows = (snrIndex - 1) * numPerSnr + (1:numPerSnr);
    noiseVariance = signalPower / 10^(snrValues(snrIndex) / 10);
    for trialIndex = 1:numPerSnr
        row = rows(trialIndex);
        beta = exp(1i * 2 * pi * rand(stream));
        noise = sqrt(noiseVariance / 2) * (randn(stream, ...
            cfg.numSubcarriers, 1) + 1i * randn(stream, ...
            cfg.numSubcarriers, 1));
        observation = beta * truthResponse + noise;
        [~, peakPosition] = max(abs(observation).^2);
        peakCarrierIndex = peakPosition - 1;
        front = fsjad.angleMultistartProfileEstimate(cfg, observation, ...
            scan, frontOffsetsDeg);
        carrierIndex = fixedCountWindow(peakCarrierIndex, ...
            fusionCarriers, cfg.numSubcarriers);
        snapshots = jad.simulateSnapshots(cfg, truthThetaDeg, ...
            truthRangeM, snrValues(snrIndex), carrierIndex, stream);
        music = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
            front.thetaDeg, front.rangeM);
        frontAngleErrorDeg(row) = front.thetaDeg - truthThetaDeg;
        frontRangeErrorM(row) = front.rangeM - truthRangeM;
        musicAngleErrorDeg(row) = music.thetaDeg - truthThetaDeg;
        musicRangeErrorM(row) = music.rangeM - truthRangeM;
        musicBoundaryPeak(row) = isBoundaryPeak(music.initialSpectrum);
        fprintf("Adaptive curve SNR %g dB trial %d/%d complete.\n", ...
            snrValues(snrIndex), trialIndex, numPerSnr);
    end
    completedSnrCount = snrIndex;
    save(checkpointFile, "frontAngleErrorDeg", "frontRangeErrorM", ...
        "musicAngleErrorDeg", "musicRangeErrorM", ...
        "musicBoundaryPeak", "completedSnrCount");
end
trials = table(snrDb, frontAngleErrorDeg, frontRangeErrorM, ...
    musicAngleErrorDeg, musicRangeErrorM, musicBoundaryPeak);
end

function summary = evaluateThresholds(trials, thresholdCandidates)
numCandidates = numel(thresholdCandidates);
rangeMusicMaxSnrDb = thresholdCandidates;
angleRmseDeg = zeros(numCandidates, 1);
rangeRmseM = zeros(numCandidates, 1);
rangeImprovementRate = zeros(numCandidates, 1);
for candidateIndex = 1:numCandidates
    useMusicRange = trials.snrDb <= thresholdCandidates(candidateIndex);
    hybridRangeError = trials.frontRangeErrorM;
    hybridRangeError(useMusicRange) = trials.musicRangeErrorM(useMusicRange);
    angleRmseDeg(candidateIndex) = sqrt(mean(trials.musicAngleErrorDeg.^2));
    rangeRmseM(candidateIndex) = sqrt(mean(hybridRangeError.^2));
    rangeImprovementRate(candidateIndex) = mean( ...
        hybridRangeError.^2 < trials.frontRangeErrorM.^2);
end
summary = table(rangeMusicMaxSnrDb, angleRmseDeg, rangeRmseM, ...
    rangeImprovementRate);
end

function published = publishedFigure10()
snrDb = (-10:5:20).';
proposedAngleRmseDeg = [0.10222305; 0.026220697; 0.0077105099; ...
    0.0026459847; 0.0012447656; 0.00084484464; 0.00075050297];
proposedRangeRmseM = [0.099998239; 0.039411058; 0.015372596; ...
    0.0059306791; 0.0022856537; 0.00087991824; 0.00033835853];
published = table(snrDb, proposedAngleRmseDeg, proposedRangeRmseM);
end

function comparison = compareWithPublished(summary, published)
adaptiveName = "Adaptive angle-MUSIC/range-gate";
fixedName = "Fixed narrow MUSIC";
frontName = "Full-spectrum front";
adaptiveRows = summary.method == adaptiveName;
fixedRows = summary.method == fixedName;
frontRows = summary.method == frontName;
snrDb = summary.snrDb(adaptiveRows);
adaptiveAngleRmseDeg = summary.angleRmseDeg(adaptiveRows);
adaptiveRangeRmseM = summary.rangeRmseM(adaptiveRows);
fixedRangeRmseM = summary.rangeRmseM(fixedRows);
frontRangeRmseM = summary.rangeRmseM(frontRows);
publishedAngleRmseDeg = published.proposedAngleRmseDeg;
publishedRangeRmseM = published.proposedRangeRmseM;
angleRatioToPublished = adaptiveAngleRmseDeg ./ publishedAngleRmseDeg;
rangeRatioToPublished = adaptiveRangeRmseM ./ publishedRangeRmseM;
rangeGainVsFixedDb = 20 * log10(fixedRangeRmseM ./ adaptiveRangeRmseM);
rangeGainVsFrontDb = 20 * log10(frontRangeRmseM ./ adaptiveRangeRmseM);
comparison = table(snrDb, adaptiveAngleRmseDeg, ...
    publishedAngleRmseDeg, angleRatioToPublished, adaptiveRangeRmseM, ...
    publishedRangeRmseM, rangeRatioToPublished, rangeGainVsFixedDb, ...
    rangeGainVsFrontDb);
end

function plotComparison(summary, published, localVariable, ...
    publishedVariable, yLabel)
axisHandle = nexttile;
axisHandle.YScale = "log";
hold(axisHandle, "on");
methodNames = ["Full-spectrum front", "Fixed narrow MUSIC", ...
    "Adaptive angle-MUSIC/range-gate"];
lineStyle = ["-o", "-s", "-^"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex);
    semilogy(summary.snrDb(rows), summary.(localVariable)(rows), ...
        lineStyle(methodIndex), LineWidth=1.5, MarkerSize=6);
end
semilogy(published.snrDb, published.(publishedVariable), "--d", ...
    LineWidth=1.5, MarkerSize=6);
hold(axisHandle, "off");
grid on;
xlabel("SNR (dB)");
ylabel(yLabel);
legend([methodNames, "Published Proposed"], Location="best");
end

function index = fixedCountWindow(centerIndex, count, totalCount)
halfCount = floor(count / 2);
startIndex = centerIndex - halfCount;
startIndex = min(max(startIndex, 0), totalCount - count);
index = (startIndex:startIndex + count - 1).';
end

function boundary = isBoundaryPeak(spectrum)
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
boundary = peakRow == 1 || peakRow == size(spectrum, 1) ...
    || peakColumn == 1 || peakColumn == size(spectrum, 2);
end
