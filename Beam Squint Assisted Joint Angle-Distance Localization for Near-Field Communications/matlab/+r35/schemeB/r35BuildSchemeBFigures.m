function manifest = r35BuildSchemeBFigures(summary, folder)
%R35BUILDSCHEMEBFIGURES Build the five declared development figures.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
perUser = summary.perUser;
notice = "Development study - not R34 final confirmation";
colors = lines(3);
files = strings(5, 1);

fig = figure(Visible="off", Color="w", Position=[100 100 720 560]);
scatter(perUser.theta_P_A-perUser.truthThetaDeg, ...
    perUser.theta_B-perUser.truthThetaDeg, 35, perUser.snrDb, "filled");
hold on;
limits = max(abs([xlim, ylim]));
plot([-limits, limits], [-limits, limits], "k--", LineWidth=1);
axis equal; xlim([-limits, limits]); ylim([-limits, limits]);
xlabel("P_A angle error (deg)"); ylabel("B angle error (deg)");
title("Frozen P_A angle error vs spectral refinement"); subtitle(notice);
colorbar; grid on;
files(1) = exportFigure(fig, figureFolder, "B_F1_angle_error_scatter.png");

fig = figure(Visible="off", Color="w", Position=[100 100 720 560]);
hold on;
snrValues = unique(perUser.snrDb).';
for index = 1:numel(snrValues)
    selected = perUser.snrDb == snrValues(index);
    histogram(perUser.bDisplacementDeg(selected), 12, ...
        DisplayStyle="stairs", LineWidth=1.5, EdgeColor=colors(index, :), ...
        DisplayName=sprintf("%g dB", snrValues(index)));
end
xlabel("theta_B - theta_A (deg)"); ylabel("Count");
title("Full-spectrum angular displacement by SNR"); subtitle(notice);
legend(Location="best"); grid on;
files(2) = exportFigure(fig, figureFolder, "B_F2_displacement_histogram.png");

fig = figure(Visible="off", Color="w", Position=[100 100 720 560]);
scatter(perUser.bScoreAfter-perUser.bScoreBefore, ...
    perUser.bTruthAngleGainDeg2, 38, perUser.snrDb, "filled");
yline(0, "k--", LineWidth=1);
xlabel("Spectral log-score gain");
ylabel("Truth squared-error reduction (deg^2)");
title("Spectral objective gain vs truth-angle gain"); subtitle(notice);
colorbar; grid on;
files(3) = exportFigure(fig, figureFolder, "B_F3_score_vs_truth_gain.png");

fig = figure(Visible="off", Color="w", Position=[100 100 720 560]);
scatter(perUser.schemeADisplacementDeg, perUser.bDisplacementDeg, ...
    38, perUser.snrDb, "filled");
hold on;
limits = max(abs([xlim, ylim]));
plot([-limits, limits], [-limits, limits], "k--", LineWidth=1);
xline(0, "Color", [0.4 0.4 0.4]);
yline(0, "Color", [0.4 0.4 0.4]);
axis equal; xlim([-limits, limits]); ylim([-limits, limits]);
xlabel("Scheme A MUSIC displacement (deg)");
ylabel("Scheme B spectral displacement (deg)");
title("Spectral displacement vs frozen Scheme A diagnostic");
subtitle(notice); colorbar; grid on;
files(4) = exportFigure(fig, figureFolder, "B_F4_vs_schemeA_displacement.png");

fig = figure(Visible="off", Color="w", Position=[100 100 760 560]);
methodNames = ["P_A", "B_primary", "C_enhanced"];
values = zeros(numel(snrValues), numel(methodNames));
for methodIndex = 1:numel(methodNames)
    rows = summary.summary(summary.summary.method == methodNames(methodIndex), :);
    rows = sortrows(rows, "snrDb");
    values(:, methodIndex) = rows.angleRmseDeg;
end
bar(categorical(string(snrValues)), values);
xlabel("SNR (dB)"); ylabel("Angle RMSE (deg)");
title("Frozen baselines and Scheme B angle RMSE"); subtitle(notice);
legend(["P_A", "B primary", "C enhanced"], Location="best"); grid on;
files(5) = exportFigure(fig, figureFolder, "B_F5_angle_rmse.png");

manifest = table((1:5).', files, repmat(notice, 5, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function file = exportFigure(fig, folder, name)
file = fullfile(folder, name);
exportgraphics(fig, file, Resolution=200);
close(fig);
end
