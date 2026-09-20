%% Beam Squint Assisted JAD Localization - reproducible core
% This script recreates the paper's deterministic trajectory/error plots,
% validates the physical coarse stage, and runs the refined MUSIC estimator.

clearvars;
close all;
clc;

projectDir = fileparts(mfilename("fullpath"));
resultDir = fullfile(projectDir, "results");
if ~isfolder(resultDir)
    mkdir(resultDir);
end

cfg = jad.defaultConfig();
stream = RandStream("mt19937ar", "Seed", cfg.randomSeed);

%% Equations (19)-(20): controllable trajectory and claimed sensing region
index = (0:cfg.numSubcarriers - 1).';
[thetaPath, rangePath] = jad.trajectory(cfg, index);
figure("Color", "w", "Position", [100, 100, 760, 520]);
hTrajectory = plot(thetaPath, rangePath, "LineWidth", 1.8);
hold on;
regionTheta = cfg.thetaLimitsDeg([1, 2, 2, 1, 1]);
regionRange = cfg.rangeLimitsM([1, 1, 2, 2, 1]);
hRegion = plot(regionTheta, regionRange, "--", "LineWidth", 1.2);
hEndpoints = scatter(thetaPath([1, end]), rangePath([1, end]), 45, "filled");
xlabel("Angle (deg)");
ylabel("Range (m)");
title("Controllable beam-squint trajectory from (19)-(20)");
legend([hTrajectory, hRegion, hEndpoints], ...
    "Equation trajectory", "Claimed sensing region", "Endpoints", ...
    "Location", "best");
grid on;
exportgraphics(gcf, fullfile(resultDir, "figure_trajectory.png"), "Resolution", 180);

%% Equation (21): error propagation
angleErrorDeg = linspace(0.01, 0.12, 12);
referenceRangeM = 300; % Reproduces Fig. 4 scale; not stated in the paper.
referenceAngleDeg = 45;
distanceErrorM = 2 * referenceRangeM * tand(referenceAngleDeg) ...
    .* deg2rad(angleErrorDeg);
figure("Color", "w", "Position", [100, 100, 700, 480]);
plot(angleErrorDeg, distanceErrorM, "-o", "LineWidth", 1.6, "MarkerSize", 4);
xlabel("Angle error (deg)");
ylabel("Distance error (m)");
title("Two-step error propagation from (21)");
grid on;
exportgraphics(gcf, fullfile(resultDir, "figure_error_propagation.png"), "Resolution", 180);

%% End-to-end physical consistency of the coarse stage
trueThetaDeg = 15;
trueRangeM = 30;
coarsePhysical = jad.physicalCoarseEstimate( ...
    cfg, trueThetaDeg, trueRangeM, Inf, stream);
figure("Color", "w", "Position", [100, 100, 760, 500]);
plot(index, coarsePhysical.power / max(coarsePhysical.power), "LineWidth", 1.3);
xline(coarsePhysical.carrierIndex, "--", "Peak");
xlabel("Subcarrier index");
ylabel("Normalized received power");
title("Physical coarse-stage power for target (15 deg, 30 m)");
grid on;
exportgraphics(gcf, fullfile(resultDir, "figure_physical_coarse_power.png"), "Resolution", 180);

%% Fig. 6 core: geometry-compensated local MUSIC
% The paper states that the coarse error is within 1 deg and 1 m, but does
% not provide the missing settings required to reproduce that claim.
coarseThetaDeg = trueThetaDeg + 0.35;
coarseRangeM = trueRangeM + 0.40;
centerCarrier = round(cfg.numSubcarriers / 2);
halfCarrierCount = floor(cfg.numFusionCarriers / 2);
carrierIndex = (centerCarrier-halfCarrierCount:centerCarrier+halfCarrierCount).';
snapshots = jad.simulateSnapshots( ...
    cfg, trueThetaDeg, trueRangeM, 10, carrierIndex, stream);
music = jad.localMusicEstimate( ...
    cfg, snapshots, carrierIndex, coarseThetaDeg, coarseRangeM);

figure("Color", "w", "Position", [100, 100, 780, 560]);
imagesc(music.initialThetaGridDeg, music.initialRangeGridM, ...
    10 * log10(music.initialSpectrum));
set(gca, "YDir", "normal");
hold on;
plot(trueThetaDeg, trueRangeM, "wo", "MarkerFaceColor", "w", "MarkerSize", 6);
plot(music.thetaDeg, music.rangeM, "rx", "LineWidth", 1.8, "MarkerSize", 8);
xlabel("Angle (deg)");
ylabel("Range (m)");
title("Geometry-compensated fused MUSIC spectrum (dB)");
legend("True", "Estimated", "Location", "best");
colorbar;
exportgraphics(gcf, fullfile(resultDir, "figure_music_spectrum.png"), "Resolution", 180);

%% Small Monte Carlo check of proposed refinement and printed CRLB
snrDb = cfg.snrDb;
angleSquaredError = zeros(cfg.numMonteCarlo, numel(snrDb));
rangeSquaredError = zeros(cfg.numMonteCarlo, numel(snrDb));
for snrIndex = 1:numel(snrDb)
    for trial = 1:cfg.numMonteCarlo
        trialCoarseTheta = trueThetaDeg + 0.45 * (2 * rand(stream) - 1);
        trialCoarseRange = trueRangeM + 0.45 * (2 * rand(stream) - 1);
        trialSnapshots = jad.simulateSnapshots(cfg, trueThetaDeg, trueRangeM, ...
            snrDb(snrIndex), carrierIndex, stream);
        estimate = jad.localMusicEstimate(cfg, trialSnapshots, carrierIndex, ...
            trialCoarseTheta, trialCoarseRange);
        angleSquaredError(trial, snrIndex) = (estimate.thetaDeg - trueThetaDeg)^2;
        rangeSquaredError(trial, snrIndex) = (estimate.rangeM - trueRangeM)^2;
    end
end
angleRmse = sqrt(mean(angleSquaredError, 1));
rangeRmse = sqrt(mean(rangeSquaredError, 1));
[angleCrlb, rangeCrlb] = jad.paperCrlb( ...
    cfg, trueThetaDeg, trueRangeM, snrDb);
[angleProjectedCrlb, rangeProjectedCrlb] = jad.projectedCrlb( ...
    cfg, trueThetaDeg, trueRangeM, snrDb);

figure("Color", "w", "Position", [100, 100, 980, 420]);
tiledlayout(1, 2, "Padding", "compact");
nexttile;
semilogy(snrDb, angleRmse, "-o", snrDb, angleCrlb, "--", ...
    snrDb, angleProjectedCrlb, ":", "LineWidth", 1.5);
xlabel("SNR (dB)"); ylabel("Angle RMSE (deg)"); grid on;
legend("Local MUSIC", "Printed CRLB", "Amplitude-projected CRLB", ...
    "Location", "southwest");
nexttile;
semilogy(snrDb, rangeRmse, "-o", snrDb, rangeCrlb, "--", ...
    snrDb, rangeProjectedCrlb, ":", "LineWidth", 1.5);
xlabel("SNR (dB)"); ylabel("Range RMSE (m)"); grid on;
legend("Local MUSIC", "Printed CRLB", "Amplitude-projected CRLB", ...
    "Location", "southwest");
exportgraphics(gcf, fullfile(resultDir, "figure_rmse_core.png"), "Resolution", 180);

results = struct();
results.config = cfg;
results.truePosition = [trueThetaDeg, trueRangeM];
results.physicalCoarseEstimate = [coarsePhysical.thetaDeg, coarsePhysical.rangeM];
results.musicEstimate = [music.thetaDeg, music.rangeM];
results.snrDb = snrDb;
results.angleRmseDeg = angleRmse;
results.rangeRmseM = rangeRmse;
results.angleCrlbDeg = angleCrlb;
results.rangeCrlbM = rangeCrlb;
results.angleProjectedCrlbDeg = angleProjectedCrlb;
results.rangeProjectedCrlbM = rangeProjectedCrlb;
save(fullfile(resultDir, "reproduction_results.mat"), "results");
summaryTable = table(snrDb.', angleRmse.', rangeRmse.', angleCrlb.', ...
    rangeCrlb.', angleProjectedCrlb.', rangeProjectedCrlb.', ...
    'VariableNames', {'SNR_dB', 'Angle_RMSE_deg', 'Range_RMSE_m', ...
    'Printed_Angle_CRLB_deg', 'Printed_Range_CRLB_m', ...
    'Projected_Angle_CRLB_deg', 'Projected_Range_CRLB_m'});
writetable(summaryTable, fullfile(resultDir, "reproduction_summary.csv"));

fprintf("True position:                 theta = %.4f deg, r = %.4f m\n", ...
    trueThetaDeg, trueRangeM);
fprintf("Physical coarse estimate:     theta = %.4f deg, r = %.4f m\n", ...
    coarsePhysical.thetaDeg, coarsePhysical.rangeM);
fprintf("Assumption-aided MUSIC result: theta = %.4f deg, r = %.4f m\n", ...
    music.thetaDeg, music.rangeM);
fprintf("Artifacts written to %s\n", resultDir);
