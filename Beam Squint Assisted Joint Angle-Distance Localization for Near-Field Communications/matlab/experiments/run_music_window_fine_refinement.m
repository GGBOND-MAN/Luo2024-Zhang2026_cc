function run_music_window_fine_refinement
%RUN_MUSIC_WINDOW_FINE_REFINEMENT Fine scan near the narrow useful window.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
cfg.subarraySize = 96;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.gridSizes = [61, 41, 31];
fusionCarriers = 513;
carrierIndex = fixedCountWindow(floor(cfg.numSubcarriers / 2), ...
    fusionCarriers, cfg.numSubcarriers);
angleCandidatesDeg = [0, 0.02, 0.05, 0.1, 0.15, 0.25, 0.5];
rangeCandidatesM = [0.005, 0.01, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05];

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round6");
dataset = load(fullfile(outputFolder, "carrier_refinement_dataset.mat"));
frontAngleError = dataset.frontThetaDeg - dataset.truthThetaDeg;
frontRangeError = dataset.frontRangeM - dataset.truthRangeM;
frontBaseline = table(sqrt(mean(frontAngleError.^2)), ...
    sqrt(mean(frontRangeError.^2)), ...
    VariableNames=["angleRmseDeg", "rangeRmseM"]);

angleCheckpointFile = fullfile(outputFolder, ...
    "window_fine_angle_checkpoint.mat");
angleDetails = cell(numel(angleCandidatesDeg), 1);
completedAngleCandidates = 0;
if isfile(angleCheckpointFile)
    checkpoint = load(angleCheckpointFile);
    angleDetails = checkpoint.angleDetails;
    completedAngleCandidates = checkpoint.completedAngleCandidates;
end
for angleIndex = completedAngleCandidates + 1:numel(angleCandidatesDeg)
    candidateCfg = cfg;
    candidateCfg.localHalfWidthDeg = angleCandidatesDeg(angleIndex);
    candidateCfg.localHalfWidthM = 0.02;
    angleDetails{angleIndex} = evaluateConfiguration(candidateCfg, ...
        dataset, carrierIndex, "Fine angle");
    completedAngleCandidates = angleIndex;
    save(angleCheckpointFile, "angleDetails", "completedAngleCandidates");
    fprintf("Fine angle-window %d/%d: %.3g deg complete.\n", ...
        angleIndex, numel(angleCandidatesDeg), angleCandidatesDeg(angleIndex));
end
angleSummary = summarizeConfigurations(angleDetails, ...
    angleCandidatesDeg(:), 0.02 * ones(numel(angleCandidatesDeg), 1));
positiveAngleRows = angleSummary.angleHalfWidthDeg > 0;
positiveAngleRanking = sortrows(angleSummary(positiveAngleRows, :), ...
    ["rangeRmseM", "angleRmseDeg"], ["ascend", "ascend"]);
bestPositiveAngleDeg = positiveAngleRanking.angleHalfWidthDeg(1);

rangeCheckpointFile = fullfile(outputFolder, ...
    "window_fine_range_checkpoint.mat");
rangeDetails = cell(numel(rangeCandidatesM), 1);
completedRangeCandidates = 0;
if isfile(rangeCheckpointFile)
    checkpoint = load(rangeCheckpointFile);
    rangeDetails = checkpoint.rangeDetails;
    completedRangeCandidates = checkpoint.completedRangeCandidates;
end
for rangeIndex = completedRangeCandidates + 1:numel(rangeCandidatesM)
    candidateCfg = cfg;
    candidateCfg.localHalfWidthDeg = bestPositiveAngleDeg;
    candidateCfg.localHalfWidthM = rangeCandidatesM(rangeIndex);
    rangeDetails{rangeIndex} = evaluateConfiguration(candidateCfg, ...
        dataset, carrierIndex, "Fine range");
    completedRangeCandidates = rangeIndex;
    save(rangeCheckpointFile, "rangeDetails", "completedRangeCandidates");
    fprintf("Fine range-window %d/%d: %.3g m complete.\n", ...
        rangeIndex, numel(rangeCandidatesM), rangeCandidatesM(rangeIndex));
end
rangeSummary = summarizeConfigurations(rangeDetails, ...
    bestPositiveAngleDeg * ones(numel(rangeCandidatesM), 1), ...
    rangeCandidatesM(:));
rangeRanking = sortrows(rangeSummary, ...
    ["rangeRmseM", "angleRmseDeg"], ["ascend", "ascend"]);
bestRangeM = rangeRanking.rangeHalfWidthM(1);

allDetails = [vertcat(angleDetails{:}); vertcat(rangeDetails{:})];
snrSummary = groupsummary(allDetails, ...
    ["stage", "angleHalfWidthDeg", "rangeHalfWidthM", "snrDb"], ...
    "mean", ["angleErrorSquared", "rangeErrorSquared", ...
    "captured", "rangeImproved", "boundaryPeak"]);
snrSummary.angleRmseDeg = sqrt(snrSummary.mean_angleErrorSquared);
snrSummary.rangeRmseM = sqrt(snrSummary.mean_rangeErrorSquared);
selectedParameter = ["fusionCarriers"; "angleHalfWidthDeg"; ...
    "rangeHalfWidthM"];
selectedValue = [fusionCarriers; bestPositiveAngleDeg; bestRangeM];
selected = table(selectedParameter, selectedValue);

writetable(angleSummary, fullfile(outputFolder, ...
    "window_fine_angle_summary.csv"));
writetable(positiveAngleRanking, fullfile(outputFolder, ...
    "window_fine_angle_ranking.csv"));
writetable(rangeSummary, fullfile(outputFolder, ...
    "window_fine_range_summary.csv"));
writetable(rangeRanking, fullfile(outputFolder, ...
    "window_fine_range_ranking.csv"));
writetable(snrSummary, fullfile(outputFolder, ...
    "window_fine_snr_summary.csv"));
writetable(selected, fullfile(outputFolder, ...
    "window_fine_selected.csv"));
save(fullfile(outputFolder, "window_fine_refinement.mat"), ...
    "cfg", "fusionCarriers", "angleCandidatesDeg", ...
    "rangeCandidatesM", "frontBaseline", "angleSummary", ...
    "positiveAngleRanking", "rangeSummary", "rangeRanking", ...
    "snrSummary", "selected");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
plot(angleSummary.angleHalfWidthDeg, angleSummary.rangeRmseM, ...
    "-o", LineWidth=1.5, MarkerSize=6);
yline(frontBaseline.rangeRmseM, "--", "Front-end baseline");
grid on;
xlabel("Angle half-width (deg)");
ylabel("Range RMSE (m)");
title("Fine angle-window scan");
nexttile;
plot(rangeSummary.rangeHalfWidthM, rangeSummary.rangeRmseM, ...
    "-o", LineWidth=1.5, MarkerSize=6);
yline(frontBaseline.rangeRmseM, "--", "Front-end baseline");
grid on;
xlabel("Range half-width (m)");
ylabel("Range RMSE (m)");
title("Fine range-window scan");
title(layout, "Fine MUSIC window refinement");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "window_fine_refinement.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "window_fine_refinement.fig"));
close(figureHandle);

disp(frontBaseline);
disp(positiveAngleRanking);
disp(rangeRanking);
disp(selected);
end

function details = evaluateConfiguration(cfg, dataset, carrierIndex, stageName)
numRows = numel(dataset.snrDb);
stage = repmat(string(stageName), numRows, 1);
angleHalfWidthDeg = cfg.localHalfWidthDeg * ones(numRows, 1);
rangeHalfWidthM = cfg.localHalfWidthM * ones(numRows, 1);
snrDb = dataset.snrDb;
angleErrorDeg = zeros(numRows, 1);
rangeErrorM = zeros(numRows, 1);
frontRangeErrorM = dataset.frontRangeM - dataset.truthRangeM;
captured = false(numRows, 1);
rangeImproved = false(numRows, 1);
boundaryPeak = false(numRows, 1);
for row = 1:numRows
    [available, columns] = ismember(carrierIndex, ...
        dataset.unionCarrierIndex{row});
    assert(all(available), "Selected carrier is missing from dataset.");
    result = jad.localMusicEstimate(cfg, ...
        dataset.snapshots{row}(:, columns), carrierIndex, ...
        dataset.frontThetaDeg(row), dataset.frontRangeM(row));
    angleErrorDeg(row) = result.thetaDeg - dataset.truthThetaDeg(row);
    rangeErrorM(row) = result.rangeM - dataset.truthRangeM(row);
    captured(row) = abs(angleErrorDeg(row)) <= 1 ...
        && abs(rangeErrorM(row)) <= 1;
    rangeImproved(row) = abs(rangeErrorM(row)) ...
        < abs(frontRangeErrorM(row));
    boundaryPeak(row) = isBoundaryPeak(result.initialSpectrum);
end
angleErrorSquared = angleErrorDeg.^2;
rangeErrorSquared = rangeErrorM.^2;
details = table(stage, angleHalfWidthDeg, rangeHalfWidthM, snrDb, ...
    angleErrorDeg, rangeErrorM, frontRangeErrorM, angleErrorSquared, ...
    rangeErrorSquared, captured, rangeImproved, boundaryPeak);
end

function summary = summarizeConfigurations(details, angleWidth, rangeWidth)
numConfigurations = numel(details);
angleHalfWidthDeg = angleWidth;
rangeHalfWidthM = rangeWidth;
captureRate = zeros(numConfigurations, 1);
angleRmseDeg = zeros(numConfigurations, 1);
rangeRmseM = zeros(numConfigurations, 1);
rangeImprovementRate = zeros(numConfigurations, 1);
rangeMseChangeM2 = zeros(numConfigurations, 1);
boundaryRate = zeros(numConfigurations, 1);
for configuration = 1:numConfigurations
    current = details{configuration};
    captureRate(configuration) = mean(current.captured);
    angleRmseDeg(configuration) = sqrt(mean(current.angleErrorDeg.^2));
    rangeRmseM(configuration) = sqrt(mean(current.rangeErrorM.^2));
    rangeImprovementRate(configuration) = mean(current.rangeImproved);
    rangeMseChangeM2(configuration) = mean(current.rangeErrorM.^2 ...
        - current.frontRangeErrorM.^2);
    boundaryRate(configuration) = mean(current.boundaryPeak);
end
summary = table(angleHalfWidthDeg, rangeHalfWidthM, captureRate, ...
    angleRmseDeg, rangeRmseM, rangeImprovementRate, ...
    rangeMseChangeM2, boundaryRate);
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
