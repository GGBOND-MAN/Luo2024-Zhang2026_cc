function manifest = r36BuildSchemeECalibrationFigures(summary, folder)
%R36BUILDSCHEMEECALIBRATIONFIGURES Build five calibration figures.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
notice = "Calibration study – not R34 final confirmation";
files = strings(5, 1);

fig = figure(Visible="off", Color="w", Position=[100 100 980 480]);
tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotRmsePanel(summary.all600.summary, "All 600 calibration rows");
plotRmsePanel(summary.holdout540.summary, "Fixed holdout 540 rows");
sgtitle("Scheme E angle RMSE calibration"+newline+notice);
files(1) = exportFigure(fig, figureFolder, "E_CAL_F1_angle_rmse.png");

fig = figure(Visible="off", Color="w", Position=[100 100 860 540]);
gain = summary.perUser.truthSquaredErrorGainDeg2;
subsetLabel = repmat("Holdout540", height(summary.perUser), 1);
subsetLabel(summary.perUser.subset == "development-overlap60") = "Dev60";
groups = categorical(subsetLabel+" / " ...
    +string(summary.perUser.snrDb)+" dB");
boxchart(groups, gain); yline(0, "k--"); xtickangle(20);
ylabel("P_A squared error - E squared error (deg^2)");
title("Paired truth-angle gain by fixed calibration subset");
subtitle(notice); grid on;
files(2) = exportFigure(fig, figureFolder, "E_CAL_F2_paired_gain.png");

fig = figure(Visible="off", Color="w", Position=[100 100 780 540]);
holdout = summary.holdout540.perUser;
scatter(holdout.actualCostReduction, ...
    holdout.truthSquaredErrorGainDeg2, 28, holdout.snrDb, "filled");
yline(0, "k--"); xlabel("Actual raw-MUSIC cost reduction");
ylabel("P_A squared error - E squared error (deg^2)");
title("Holdout-540 objective reduction vs truth gain");
subtitle(notice); colorbar; grid on;
files(3) = exportFigure(fig, figureFolder, ...
    "E_CAL_F3_cost_vs_truth_gain.png");

fig = figure(Visible="off", Color="w", Position=[100 100 780 540]);
snrValues = unique(summary.perUser.snrDb).';
clipped = zeros(numel(snrValues), 2);
for index = 1:numel(snrValues)
    allSelected = summary.perUser.snrDb == snrValues(index);
    holdoutSelected = holdout.snrDb == snrValues(index);
    clipped(index, 1) = mean(summary.perUser.clippedToBracket(allSelected));
    clipped(index, 2) = mean(holdout.clippedToBracket(holdoutSelected));
end
bar(categorical(string(snrValues)), clipped);
xlabel("SNR (dB)"); ylabel("Bracket-clipped fraction");
title("Frozen bracket clipping stability"); subtitle(notice);
legend(["All 600", "Holdout 540"], Location="best"); grid on;
files(4) = exportFigure(fig, figureFolder, ...
    "E_CAL_F4_bracket_clipping.png");

fig = figure(Visible="off", Color="w", Position=[100 100 780 540]);
ratios = zeros(numel(snrValues), 2);
for index = 1:numel(snrValues)
    ratios(index, 1) = ratioAt( ...
        summary.all600.summary, snrValues(index), "rangeMseRatioToPA");
    ratios(index, 2) = ratioAt( ...
        summary.holdout540.summary, snrValues(index), "rangeMseRatioToPA");
end
bar(categorical(string(snrValues)), ratios); yline(1.02, "r--");
xlabel("SNR (dB)"); ylabel("Scheme E / P_A range MSE ratio");
title("Refreshed range preservation"); subtitle(notice);
legend(["All 600", "Holdout 540", "Gate 1.02"], Location="best");
grid on;
files(5) = exportFigure(fig, figureFolder, ...
    "E_CAL_F5_range_preservation.png");

manifest = table((1:5).', files, repmat(notice, 5, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function plotRmsePanel(methodSummary, panelTitle)
nexttile;
snrValues = unique(methodSummary.snrDb).';
values = zeros(numel(snrValues), 2);
for index = 1:numel(snrValues)
    values(index, 1) = methodSummary.angleRmseDeg( ...
        methodSummary.method == "P_A" ...
        & methodSummary.snrDb == snrValues(index));
    values(index, 2) = methodSummary.angleRmseDeg( ...
        methodSummary.method == "E_one_step" ...
        & methodSummary.snrDb == snrValues(index));
end
bar(categorical(string(snrValues)), values);
xlabel("SNR (dB)"); ylabel("Angle RMSE (deg)");
title(panelTitle); legend(["P_A", "E one-step"], Location="best"); grid on;
end

function value = ratioAt(summary, snrDb, field)
row = summary(summary.method == "E_one_step" ...
    & summary.snrDb == snrDb, :);
value = row.(field);
end

function file = exportFigure(fig, folder, name)
file = fullfile(folder, name);
exportgraphics(fig, file, Resolution=200);
close(fig);
end
