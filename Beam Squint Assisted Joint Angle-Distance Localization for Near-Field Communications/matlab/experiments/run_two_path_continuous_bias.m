function run_two_path_continuous_bias
%RUN_TWO_PATH_CONTINUOUS_BIAS Audit sub-resolution multipath bias floors.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
location = ["Interior positive"; "Interior negative"];
mainThetaDeg = [15; -30];
mainRangeM = [30; 35];
separation = ["Range 0.5 m"; "Range 1 m"; "Range 2 m"; ...
    "Angle 0.5 deg"; "Angle 1 deg"; "Angle 2 deg"; ...
    "Joint 1 deg, 1 m"];
secondaryThetaOffsetDeg = [0; 0; 0; 0.5; 1; 2; 1];
secondaryRangeOffsetM = [0.5; 1; 2; 0; 0; 0; 1];
relativePowerDbValues = [-20, -10, -6, -3, 0];
relativePhaseRadValues = 2 * pi * (0:15) / 16;

numRows = numel(location) * numel(separation) ...
    * numel(relativePowerDbValues) * numel(relativePhaseRadValues);
locationColumn = strings(numRows, 1);
separationColumn = strings(numRows, 1);
relativePowerDb = zeros(numRows, 1);
relativePhaseRad = zeros(numRows, 1);
estimateThetaDeg = zeros(numRows, 1);
estimateRangeM = zeros(numRows, 1);
angleBiasDeg = zeros(numRows, 1);
rangeBiasM = zeros(numRows, 1);
absoluteAngleBiasDeg = zeros(numRows, 1);
absoluteRangeBiasM = zeros(numRows, 1);
outsideFixedWindow = false(numRows, 1);
profileScore = zeros(numRows, 1);
iterations = zeros(numRows, 1);
converged = false(numRows, 1);
rowIndex = 0;

for locationIndex = 1:numel(location)
    mainResponse = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(mainThetaDeg(locationIndex)), mainRangeM(locationIndex), scan);
    for separationIndex = 1:numel(separation)
        secondaryThetaDeg = mainThetaDeg(locationIndex) ...
            + secondaryThetaOffsetDeg(separationIndex);
        secondaryRangeM = mainRangeM(locationIndex) ...
            + secondaryRangeOffsetM(separationIndex);
        secondaryResponse = fsjad.exactSpectralResponse(cfg, ...
            deg2rad(secondaryThetaDeg), secondaryRangeM, scan);
        for powerIndex = 1:numel(relativePowerDbValues)
            relativeAmplitude = 10^(relativePowerDbValues(powerIndex) / 20);
            for phaseIndex = 1:numel(relativePhaseRadValues)
                observation = mainResponse + relativeAmplitude ...
                    * exp(1i * relativePhaseRadValues(phaseIndex)) ...
                    * secondaryResponse;
                estimate = fsjad.refineProfileEstimate(cfg, observation, ...
                    mainThetaDeg(locationIndex), mainRangeM(locationIndex), ...
                    scan, 20);
                rowIndex = rowIndex + 1;
                locationColumn(rowIndex) = location(locationIndex);
                separationColumn(rowIndex) = separation(separationIndex);
                relativePowerDb(rowIndex) = ...
                    relativePowerDbValues(powerIndex);
                relativePhaseRad(rowIndex) = ...
                    relativePhaseRadValues(phaseIndex);
                estimateThetaDeg(rowIndex) = estimate.thetaDeg;
                estimateRangeM(rowIndex) = estimate.rangeM;
                angleBiasDeg(rowIndex) = estimate.thetaDeg ...
                    - mainThetaDeg(locationIndex);
                rangeBiasM(rowIndex) = estimate.rangeM ...
                    - mainRangeM(locationIndex);
                absoluteAngleBiasDeg(rowIndex) = abs(angleBiasDeg(rowIndex));
                absoluteRangeBiasM(rowIndex) = abs(rangeBiasM(rowIndex));
                outsideFixedWindow(rowIndex) = abs(angleBiasDeg(rowIndex)) > 1 ...
                    || abs(rangeBiasM(rowIndex)) > 1;
                profileScore(rowIndex) = estimate.score;
                iterations(rowIndex) = estimate.iterations;
                converged(rowIndex) = estimate.converged;
            end
        end
    end
    fprintf("Completed continuous multipath audit at %s.\n", ...
        location(locationIndex));
end

trials = table(locationColumn, separationColumn, relativePowerDb, ...
    relativePhaseRad, estimateThetaDeg, estimateRangeM, angleBiasDeg, ...
    rangeBiasM, absoluteAngleBiasDeg, absoluteRangeBiasM, ...
    outsideFixedWindow, profileScore, iterations, converged);
summary = groupsummary(trials, ["separationColumn", "relativePowerDb"], ...
    {"mean", "max"}, ["angleBiasDeg", "rangeBiasM", ...
    "absoluteAngleBiasDeg", "absoluteRangeBiasM", ...
    "outsideFixedWindow", "profileScore", "iterations", "converged"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round3");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(trials, fullfile(outputFolder, ...
    "two_path_continuous_bias_trials.csv"));
writetable(summary, fullfile(outputFolder, ...
    "two_path_continuous_bias_summary.csv"));
save(fullfile(outputFolder, "two_path_continuous_bias.mat"), ...
    "cfg", "location", "mainThetaDeg", "mainRangeM", "separation", ...
    "secondaryThetaOffsetDeg", "secondaryRangeOffsetM", ...
    "relativePowerDbValues", "relativePhaseRadValues", ...
    "trials", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
hold on;
for separationIndex = 1:3
    rows = summary.separationColumn == separation(separationIndex);
    plot(summary.relativePowerDb(rows), ...
        summary.mean_outsideFixedWindow(rows), "-o", ...
        LineWidth=1.5, MarkerSize=5);
end
hold off; grid on; ylim([0, 1.02]);
xlabel("Relative second-path power (dB)");
ylabel("Outside fixed window probability");
title("Range-separated path");
legend(separation(1:3), Location="best");
nexttile;
hold on;
for separationIndex = 4:6
    rows = summary.separationColumn == separation(separationIndex);
    plot(summary.relativePowerDb(rows), ...
        summary.mean_outsideFixedWindow(rows), "-o", ...
        LineWidth=1.5, MarkerSize=5);
end
hold off; grid on; ylim([0, 1.02]);
xlabel("Relative second-path power (dB)");
ylabel("Outside fixed window probability");
title("Angle-separated path");
legend(separation(4:6), Location="best");
title(layout, "Noiseless continuous bias under a single-LoS fit");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "two_path_continuous_bias.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "two_path_continuous_bias.fig"));
close(figureHandle);

disp(summary);
end
