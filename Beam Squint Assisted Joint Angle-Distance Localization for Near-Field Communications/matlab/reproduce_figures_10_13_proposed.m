function reproduce_figures_10_13_proposed()
%REPRODUCE_FIGURES_10_13_PROPOSED Reconstruct the paper's proposed curves.
% The coordinates below are recovered from the vector paths embedded in the
% IEEE accepted-version PDF. They reproduce the published proposed-method
% curves only. They are not a rerun of the unavailable author Monte Carlo
% code and do not include any baseline curves.

close all;
rootDir = fileparts(mfilename("fullpath"));
outputDir = fullfile(rootDir, "results", "paper_figures");
if ~isfolder(outputDir)
    mkdir(outputDir);
end

makeFigure10(outputDir);
makeFigure11(outputDir);
makeFigure12(outputDir);
makeFigure13(outputDir);
fprintf("Paper Figs. 10-13 proposed-only curves written to %s\n", outputDir);
end

function makeFigure10(outputDir)
snrDb = -10:5:20;
angleRmseDeg = [0.10222305, 0.026220697, 0.0077105099, ...
    0.0026459847, 0.0012447656, 0.00084484464, 0.00075050297];
rangeRmseM = [0.099998239, 0.039411058, 0.015372596, ...
    0.0059306791, 0.0022856537, 0.00087991824, 0.00033835853];

figure("Name", "Paper Fig. 10 - Proposed Method Only", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 1050, 430]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile;
semilogy(snrDb, angleRmseDeg, "-o", "Color", [0, 0, 1], ...
    "MarkerFaceColor", [0, 0, 1], "LineWidth", 1.5, "MarkerSize", 5);
xlabel("SNR (dB)");
ylabel("RMSE theta (deg)");
xlim([-10, 20]);
grid on;
legend("Proposed Joint MUSIC", "Location", "southwest");
nexttile;
semilogy(snrDb, rangeRmseM, "-o", "Color", [0, 0, 1], ...
    "MarkerFaceColor", [0, 0, 1], "LineWidth", 1.5, "MarkerSize", 5);
xlabel("SNR (dB)");
ylabel("RMSE r (m)");
xlim([-10, 20]);
grid on;
legend("Proposed Joint MUSIC", "Location", "southwest");
savePaperFigure(gcf, outputDir, "fig10_proposed_only");

data = table(snrDb.', angleRmseDeg.', rangeRmseM.', ...
    'VariableNames', {'SNR_dB', 'Proposed_Angle_RMSE_deg', ...
    'Proposed_Range_RMSE_m'});
writetable(data, fullfile(outputDir, "fig10_proposed_only.csv"));
end

function makeFigure11(outputDir)
snrDb = -10:5:20;
anglesDeg = [10, 30, 50];
rangesM = [10, 30, 50];
angleRmseDeg = [ ...
    0.10000054, 0.032145184, 0.010682044, 0.0039654289, 0.0018706047, 0.0012080282, 0.00098909744; ...
    0.12000098, 0.040781554, 0.014352097, 0.0055964868, 0.0027225748, 0.0017697486, 0.0014422876; ...
    0.14000072, 0.050200060, 0.018598315, 0.0075519607, 0.0037475285, 0.0024151377, 0.0019340435];
rangeRmseM = [ ...
    0.11999714, 0.030238381, 0.009793350, 0.0041759610, 0.0023090864, 0.0015829322, 0.0012752394; ...
    0.17999772, 0.042442460, 0.012371313, 0.0048558557, 0.0026217165, 0.0018306120, 0.0015004835; ...
    0.22999796, 0.053923579, 0.015048380, 0.0055940860, 0.0029608071, 0.0020844601, 0.0017327637];
lineColors = [0.12207, 0.467041, 0.705078; ...
    1.0, 0.498047, 0.054993; 0.173096, 0.626953, 0.173096];

figure("Name", "Paper Fig. 11 - Proposed Method Only", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 1080, 430]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile;
hold on;
set(gca, "YScale", "log");
for index = 1:numel(anglesDeg)
    semilogy(snrDb, angleRmseDeg(index, :), "-o", ...
        "Color", lineColors(index, :), "MarkerFaceColor", lineColors(index, :), ...
        "LineWidth", 1.4, "MarkerSize", 4.5);
end
xlabel("SNR (dB)");
ylabel("RMSE theta (deg)");
xlim([-10, 20]);
ylim([8e-4, 0.2]);
grid on;
legend("Proposed Joint MUSIC theta = 10 deg", ...
    "Proposed Joint MUSIC theta = 30 deg", ...
    "Proposed Joint MUSIC theta = 50 deg", "Location", "southwest");
nexttile;
hold on;
set(gca, "YScale", "log");
for index = 1:numel(rangesM)
    semilogy(snrDb, rangeRmseM(index, :), "-o", ...
        "Color", lineColors(index, :), "MarkerFaceColor", lineColors(index, :), ...
        "LineWidth", 1.4, "MarkerSize", 4.5);
end
xlabel("SNR (dB)");
ylabel("RMSE r (m)");
xlim([-10, 20]);
ylim([1e-3, 0.3]);
grid on;
legend("Proposed Joint MUSIC r = 10 m", ...
    "Proposed Joint MUSIC r = 30 m", ...
    "Proposed Joint MUSIC r = 50 m", "Location", "southwest");
savePaperFigure(gcf, outputDir, "fig11_proposed_only");

data = table(snrDb.', angleRmseDeg(1, :).', angleRmseDeg(2, :).', ...
    angleRmseDeg(3, :).', rangeRmseM(1, :).', rangeRmseM(2, :).', ...
    rangeRmseM(3, :).', 'VariableNames', {'SNR_dB', ...
    'Angle10_RMSE_deg', 'Angle30_RMSE_deg', 'Angle50_RMSE_deg', ...
    'Range10_RMSE_m', 'Range30_RMSE_m', 'Range50_RMSE_m'});
writetable(data, fullfile(outputDir, "fig11_proposed_only.csv"));
end

function makeFigure12(outputDir)
numUsers = [1, 5, 10, 15, 20];
angleRmseDeg = [0.00069995949, 0.0011999365, 0.0016999164, ...
    0.0019998906, 0.0021998860];
rangeRmseM = [0.00050005613, 0.00090008715, 0.0016001483, ...
    0.0021001947, 0.0024001994];

figure("Name", "Paper Fig. 12 - Proposed Method Only", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 1050, 430]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile;
semilogy(numUsers, angleRmseDeg, "-o", "Color", [0, 0, 1], ...
    "MarkerFaceColor", [0, 0, 1], "LineWidth", 1.5, "MarkerSize", 5);
xlabel("Number of Users (K)");
ylabel("RMSE theta (deg)");
xlim([1, 20]);
xticks(numUsers);
grid on;
legend("Proposed Joint MUSIC", "Location", "northwest");
nexttile;
semilogy(numUsers, rangeRmseM, "-o", "Color", [0, 0, 1], ...
    "MarkerFaceColor", [0, 0, 1], "LineWidth", 1.5, "MarkerSize", 5);
xlabel("Number of Users (K)");
ylabel("RMSE r (m)");
xlim([1, 20]);
xticks(numUsers);
grid on;
legend("Proposed Joint MUSIC", "Location", "northwest");
savePaperFigure(gcf, outputDir, "fig12_proposed_only");

data = table(numUsers.', angleRmseDeg.', rangeRmseM.', ...
    'VariableNames', {'Num_Users', 'Proposed_Angle_RMSE_deg', ...
    'Proposed_Range_RMSE_m'});
writetable(data, fullfile(outputDir, "fig12_proposed_only.csv"));
end

function makeFigure13(outputDir)
numAntennas = [64, 128, 192, 256, 384, 512, 640, 768, 896, 1024];
angle10RmseDeg = [0.0062495752, 0.0029771232, 0.0021233954, ...
    0.0016650221, 0.0012691583, 0.0011092732, 0.0009969757, ...
    0.00094453389, 0.00089606954, 0.00086816776];
angle50RmseDeg = [0.013034215, 0.0068951923, 0.0050303487, ...
    0.0039600594, 0.0030258980, 0.0025968759, 0.0023161376, ...
    0.0021742916, 0.0020538843, 0.0019744825];
range10RmseM = [0.0045460326, 0.0026029401, 0.0021272951, ...
    0.0018499735, 0.0016216554, 0.0015619626, 0.0015348607, ...
    0.0015165644, 0.0014982809, 0.0014887748];
range50RmseM = [0.0082839083, 0.0047047699, 0.0036800939, ...
    0.0030599819, 0.0025464269, 0.0023248224, 0.0022088490, ...
    0.0021718500, 0.0021274520, 0.0020857632];
lineColor = [0.12207, 0.467041, 0.705078];

figure("Name", "Paper Fig. 13 - Proposed Method Only", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 1080, 430]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile;
semilogy(numAntennas, angle10RmseDeg, "-o", "Color", lineColor, ...
    "MarkerFaceColor", lineColor, "LineWidth", 1.4, "MarkerSize", 4.5);
hold on;
semilogy(numAntennas, angle50RmseDeg, "--o", "Color", lineColor, ...
    "MarkerFaceColor", "w", "LineWidth", 1.4, "MarkerSize", 4.5);
xlabel("Number of antennas (N)");
ylabel("RMSE theta (deg)");
xlim([64, 1024]);
xticks(numAntennas);
grid on;
legend("Proposed Joint MUSIC, 10 deg", ...
    "Proposed Joint MUSIC, 50 deg", "Location", "southwest");
nexttile;
semilogy(numAntennas, range10RmseM, "-o", "Color", lineColor, ...
    "MarkerFaceColor", lineColor, "LineWidth", 1.4, "MarkerSize", 4.5);
hold on;
semilogy(numAntennas, range50RmseM, "--o", "Color", lineColor, ...
    "MarkerFaceColor", "w", "LineWidth", 1.4, "MarkerSize", 4.5);
xlabel("Number of antennas (N)");
ylabel("RMSE r (m)");
xlim([64, 1024]);
xticks(numAntennas);
grid on;
legend("Proposed Joint MUSIC, 10 m", ...
    "Proposed Joint MUSIC, 50 m", "Location", "southwest");
savePaperFigure(gcf, outputDir, "fig13_proposed_only");

data = table(numAntennas.', angle10RmseDeg.', angle50RmseDeg.', ...
    range10RmseM.', range50RmseM.', 'VariableNames', {'Num_Antennas', ...
    'Angle10_RMSE_deg', 'Angle50_RMSE_deg', ...
    'Range10_RMSE_m', 'Range50_RMSE_m'});
writetable(data, fullfile(outputDir, "fig13_proposed_only.csv"));
end

function savePaperFigure(figureHandle, outputDir, baseName)
exportgraphics(figureHandle, fullfile(outputDir, baseName + ".png"), ...
    "Resolution", 200);
savefig(figureHandle, fullfile(outputDir, baseName + ".fig"));
end
