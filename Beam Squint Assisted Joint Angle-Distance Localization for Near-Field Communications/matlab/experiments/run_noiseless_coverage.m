function run_noiseless_coverage
%RUN_NOISELESS_COVERAGE Compare peak-index and full-complex-spectrum coverage.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
thetaGridDeg = (-60:5:60).';
rangeGridM = (15:2.5:50).';
[thetaMeshDeg, rangeMeshM] = meshgrid(thetaGridDeg, rangeGridM);
truthThetaDeg = thetaMeshDeg(:);
truthRangeM = rangeMeshM(:);
numLocations = numel(truthThetaDeg);

responseBank = complex(zeros(cfg.numSubcarriers, numLocations));
for locationIndex = 1:numLocations
    responseBank(:, locationIndex) = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(truthThetaDeg(locationIndex)), ...
        truthRangeM(locationIndex), scan);
end

[~, peakIndex] = max(abs(responseBank).^2, [], 1);
peakThetaDeg = scan.focusThetaDeg(peakIndex);
peakRangeM = scan.focusRangeM(peakIndex);

responseEnergy = real(sum(abs(responseBank).^2, 1));
coherence = abs(responseBank' * responseBank).^2 ...
    ./ (responseEnergy.' * responseEnergy);
[fullScore, fullIndex] = max(coherence, [], 1);
fullThetaDeg = truthThetaDeg(fullIndex);
fullRangeM = truthRangeM(fullIndex);

peakAngleErrorDeg = abs(peakThetaDeg(:) - truthThetaDeg);
peakRangeErrorM = abs(peakRangeM(:) - truthRangeM);
fullAngleErrorDeg = abs(fullThetaDeg(:) - truthThetaDeg);
fullRangeErrorM = abs(fullRangeM(:) - truthRangeM);
peakCaptured = peakAngleErrorDeg <= 1 & peakRangeErrorM <= 1;
fullCaptured = fullAngleErrorDeg <= 1 & fullRangeErrorM <= 1;

pointResults = table(truthThetaDeg, truthRangeM, ...
    peakThetaDeg(:), peakRangeM(:), peakAngleErrorDeg, peakRangeErrorM, ...
    peakCaptured, fullThetaDeg(:), fullRangeM(:), fullScore(:), ...
    fullAngleErrorDeg, fullRangeErrorM, fullCaptured, ...
    VariableNames=["TruthThetaDeg", "TruthRangeM", ...
    "PeakThetaDeg", "PeakRangeM", "PeakAngleErrorDeg", "PeakRangeErrorM", ...
    "PeakCaptured", "FullThetaDeg", "FullRangeM", "FullScore", ...
    "FullAngleErrorDeg", "FullRangeErrorM", "FullCaptured"]);

method = ["Peak index"; "Full complex spectrum"];
meanAngleErrorDeg = [mean(peakAngleErrorDeg); mean(fullAngleErrorDeg)];
maxAngleErrorDeg = [max(peakAngleErrorDeg); max(fullAngleErrorDeg)];
meanRangeErrorM = [mean(peakRangeErrorM); mean(fullRangeErrorM)];
maxRangeErrorM = [max(peakRangeErrorM); max(fullRangeErrorM)];
captureRate = [mean(peakCaptured); mean(fullCaptured)];
summary = table(method, meanAngleErrorDeg, maxAngleErrorDeg, ...
    meanRangeErrorM, maxRangeErrorM, captureRate);

outputFolder = fullfile(projectFolder, "results", "full_spectrum");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(pointResults, fullfile(outputFolder, "noiseless_coverage_points.csv"));
writetable(summary, fullfile(outputFolder, "noiseless_coverage_summary.csv"));
save(fullfile(outputFolder, "noiseless_coverage.mat"), ...
    "cfg", "thetaGridDeg", "rangeGridM", "pointResults", "summary", ...
    "coherence");

figureHandle = figure(Color="w", Position=[100, 100, 1200, 680]);
layout = tiledlayout(2, 3, TileSpacing="compact", Padding="compact");
plotErrorMap(thetaGridDeg, rangeGridM, peakAngleErrorDeg, ...
    "Peak index: angle error", "degrees");
plotErrorMap(thetaGridDeg, rangeGridM, peakRangeErrorM, ...
    "Peak index: range error", "m");
plotCaptureMap(thetaGridDeg, rangeGridM, peakCaptured, ...
    sprintf("Peak capture: %.1f%%", 100 * mean(peakCaptured)));
plotErrorMap(thetaGridDeg, rangeGridM, fullAngleErrorDeg, ...
    "Full spectrum: angle error", "degrees");
plotErrorMap(thetaGridDeg, rangeGridM, fullRangeErrorM, ...
    "Full spectrum: range error", "m");
plotCaptureMap(thetaGridDeg, rangeGridM, fullCaptured, ...
    sprintf("Full capture: %.1f%%", 100 * mean(fullCaptured)));
title(layout, "Noiseless 2-D coverage on the matched exact spherical-wave model");
exportgraphics(figureHandle, ...
    fullfile(outputFolder, "noiseless_coverage.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "noiseless_coverage.fig"));
close(figureHandle);

disp(summary);
end

function plotErrorMap(thetaGridDeg, rangeGridM, errorVector, plotTitle, unit)
nexttile;
imagesc(thetaGridDeg, rangeGridM, reshape(errorVector, ...
    numel(rangeGridM), numel(thetaGridDeg)));
set(gca, YDir="normal");
xlabel("Angle (degrees)");
ylabel("Range (m)");
title(plotTitle);
colorbarHandle = colorbar;
colorbarHandle.Label.String = unit;
end

function plotCaptureMap(thetaGridDeg, rangeGridM, captureVector, plotTitle)
nexttile;
imagesc(thetaGridDeg, rangeGridM, reshape(double(captureVector), ...
    numel(rangeGridM), numel(thetaGridDeg)), [0, 1]);
set(gca, YDir="normal");
xlabel("Angle (degrees)");
ylabel("Range (m)");
title(plotTitle);
colormap(gca, [0.75, 0.18, 0.14; 0.13, 0.55, 0.32]);
colorbar(Ticks=[0, 1], TickLabels=["miss", "capture"]);
end
