function manifest = r36BuildSchemeEFigures(summary, folder)
%R36BUILDSCHEMEEFIGURES Build five labeled development figures.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
notice = "Development study – not R34 final confirmation";
perUser = summary.perUser;
files = strings(5, 1);
snrValues = unique(perUser.snrDb).';

fig = figure(Visible="off", Color="w", Position=[100 100 760 540]);
values = zeros(numel(snrValues), 2);
for index = 1:numel(snrValues)
    values(index, 1) = summary.summary.angleRmseDeg( ...
        summary.summary.method == "P_A" ...
        & summary.summary.snrDb == snrValues(index));
    values(index, 2) = summary.summary.angleRmseDeg( ...
        summary.summary.method == "E_one_step" ...
        & summary.summary.snrDb == snrValues(index));
end
bar(categorical(string(snrValues)), values);
xlabel("SNR (dB)"); ylabel("Angle RMSE (deg)");
title("P_A and range-orthogonal one-step angle RMSE");
subtitle(notice); legend(["P_A", "E one-step"], Location="best"); grid on;
files(1) = exportFigure(fig, figureFolder, "E_F1_angle_rmse.png");

fig = figure(Visible="off", Color="w", Position=[100 100 760 540]);
boxchart(categorical(string(perUser.snrDb)+" dB"), ...
    perUser.angleDisplacementDeg);
yline(0, "k--"); xlabel("SNR"); ylabel("theta_E - theta_A (deg)");
title("Range-orthogonal one-step displacement"); subtitle(notice); grid on;
files(2) = exportFigure(fig, figureFolder, "E_F2_displacement.png");

fig = figure(Visible="off", Color="w", Position=[100 100 760 540]);
scatter(perUser.angleRangeCouplingCoefficient, ...
    perUser.truthSquaredErrorGainDeg2, 38, perUser.snrDb, "filled");
yline(0, "k--"); xlabel("Angle-range tangent coupling");
ylabel("P_A squared error - E squared error (deg^2)");
title("Tangent coupling vs truth-angle gain"); subtitle(notice);
colorbar; grid on;
files(3) = exportFigure(fig, figureFolder, "E_F3_coupling_vs_gain.png");

fig = figure(Visible="off", Color="w", Position=[100 100 760 540]);
scatter(perUser.predictedCostReduction, perUser.actualCostReduction, ...
    38, perUser.snrDb, "filled");
xline(0, "k--"); yline(0, "k--");
xlabel("Predicted raw-MUSIC cost reduction");
ylabel("Actual raw-MUSIC cost reduction");
title("One-step model prediction vs realized cost reduction");
subtitle(notice); colorbar; grid on;
files(4) = exportFigure(fig, figureFolder, "E_F4_predicted_vs_actual.png");

fig = figure(Visible="off", Color="w", Position=[100 100 760 540]);
boxchart(categorical(string(perUser.snrDb)+" dB"), ...
    perUser.truthSquaredErrorGainDeg2);
yline(0, "k--"); xlabel("SNR");
ylabel("P_A squared error - E squared error (deg^2)");
title("Paired truth-angle squared-error gain"); subtitle(notice); grid on;
files(5) = exportFigure(fig, figureFolder, "E_F5_paired_truth_gain.png");

manifest = table((1:5).', files, repmat(notice, 5, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function file = exportFigure(fig, folder, name)
file = fullfile(folder, name);
exportgraphics(fig, file, Resolution=200);
close(fig);
end
