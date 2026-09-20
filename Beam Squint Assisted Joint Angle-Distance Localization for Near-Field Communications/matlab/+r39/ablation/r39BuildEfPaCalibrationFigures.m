function manifest = r39BuildEfPaCalibrationFigures(summary, folder)
%R39BUILDEFPAFIGURES Render P_A/E-single/F frozen calibration curves.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures", "efpa_calibration");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
notice = "Frozen R38 calibration evidence - not R34 final validation";
files = strings(4, 1);
files(1) = performanceFigure(summary.all600.methodSummary, ...
    "All 600 calibration rows", figureFolder, ...
    "EFPA_F1_performance_all600.png", notice);
files(2) = performanceFigure(summary.holdout540.methodSummary, ...
    "Fixed holdout 540", figureFolder, ...
    "EFPA_F2_performance_holdout540.png", notice);
files(3) = relativeFigure(summary.all600.methodSummary, ...
    figureFolder, notice);
files(4) = complexityFigure(summary.perUser, figureFolder, notice);
manifest = table((1:4).', files, repmat(notice, 4, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
writetable(selectMethods(summary.all600.methodSummary), ...
    fullfile(figureFolder, "EFPA_method_summary_all600.csv"));
writetable(selectMethods(summary.holdout540.methodSummary), ...
    fullfile(figureFolder, "EFPA_method_summary_holdout540.csv"));
end

function file = performanceFigure(rows, populationTitle, folder, name, notice)
snrValues = unique(rows.snrDb).';
fig = figure(Visible="off", Color="w", Position=[100 100 1420 520]);
tiledlayout(1, 3, TileSpacing="compact", Padding="compact");
metricTile(rows, snrValues, "angleRmseDeg", "Angle RMSE (deg)", true);
metricTile(rows, snrValues, "rangeRmseM", "Range RMSE (m)", true);
metricTile(rows, snrValues, "positionRmseM", "Position RMSE (m)", true);
sgtitle("P_A, Scheme E single-profile, and Scheme F: "+ ...
    populationTitle+newline+notice);
file = exportFigure(fig, folder, name);
end

function metricTile(rows, snrValues, field, yLabel, logScale)
nexttile;
methods = ["P_A", "E_single", "F_raw_vpml"];
labels = ["P_A", "Scheme E single-profile", "Scheme F VPML"];
values = metricMatrix(rows, methods, snrValues, field);
plotMethods(snrValues, values, labels);
xlabel("SNR (dB)");
ylabel(yLabel);
if logScale
    set(gca, YScale="log");
end
grid on;
end

function file = relativeFigure(rows, folder, notice)
snrValues = unique(rows.snrDb).';
methods = ["E_single", "F_raw_vpml"];
labels = ["Scheme E single-profile", "Scheme F VPML"];
metrics = ["angleRmseDeg", "rangeRmseM", "positionRmseM"];
titles = ["Angle", "Range", "Position"];
fig = figure(Visible="off", Color="w", Position=[100 100 1420 520]);
tiledlayout(1, 3, TileSpacing="compact", Padding="compact");
for metricIndex = 1:numel(metrics)
    nexttile;
    pa = metricMatrix(rows, "P_A", snrValues, metrics(metricIndex));
    values = metricMatrix(rows, methods, snrValues, metrics(metricIndex));
    improvement = 100*(1-values./pa);
    hold on;
    plot(snrValues, improvement(:, 1), "-d", LineWidth=1.8, ...
        MarkerSize=7, Color=[0.47 0.67 0.19]);
    plot(snrValues, improvement(:, 2), "-s", LineWidth=1.8, ...
        MarkerSize=7, Color=[0.85 0.33 0.10]);
    yline(0, "k-");
    xticks(snrValues);
    xlabel("SNR (dB)");
    ylabel("RMSE improvement vs P_A (%)");
    title(titles(metricIndex));
    grid on;
    legend(labels, Location="best");
end
sgtitle("Relative performance to P_A; positive is better"+newline+notice);
file = exportFigure(fig, folder, "EFPA_F3_relative_to_PA_all600.png");
end

function file = complexityFigure(perUser, folder, notice)
labels = categorical(["P_A", "E single", "F", "C enhanced"], ...
    ["P_A", "E single", "F", "C enhanced"]);
runtime = [mean(perUser.runtime_P_A), mean(perUser.runtime_E_single), ...
    mean(perUser.runtime_F_raw_vpml), mean(perUser.runtime_C_enhanced)];
responses = [mean(perUser.responseCount_P_A), ...
    mean(perUser.responseCount_E_single), ...
    mean(perUser.responseCount_F_raw_vpml), ...
    mean(perUser.responseCount_C_enhanced)];
profiles = [mean(perUser.profilePasses_P_A), ...
    mean(perUser.profilePasses_E_single), ...
    mean(perUser.profilePasses_F_raw_vpml), nan];
fig = figure(Visible="off", Color="w", Position=[100 100 1420 520]);
tiledlayout(1, 3, TileSpacing="compact", Padding="compact");
metricBar(labels, runtime, "Runtime", "Seconds/user");
metricBar(labels, responses, "Response evaluations", "Count/user");
metricBar(labels, profiles, "Complete range profiles", "Passes/user");
sgtitle("Frozen all-600 complexity comparison"+newline+notice);
file = exportFigure(fig, folder, "EFPA_F4_complexity_all600.png");
end

function output = selectMethods(rows)
output = rows(ismember(rows.method, ...
    ["P_A", "E_single", "F_raw_vpml"]), :);
end

function values = metricMatrix(rows, methods, snrValues, field)
values = zeros(numel(snrValues), numel(methods));
for methodIndex = 1:numel(methods)
    for snrIndex = 1:numel(snrValues)
        selected = rows.method == methods(methodIndex) ...
            & rows.snrDb == snrValues(snrIndex);
        values(snrIndex, methodIndex) = rows.(field)(selected);
    end
end
end

function plotMethods(snrValues, values, labels)
hold on;
colors = [0.00 0.45 0.74; 0.47 0.67 0.19; 0.85 0.33 0.10];
markers = ["o", "d", "s"];
for index = 1:size(values, 2)
    semilogy(snrValues, values(:, index), "-"+markers(index), ...
        Color=colors(index, :), LineWidth=1.8, MarkerSize=7);
end
xticks(snrValues);
legend(labels, Location="best");
end

function metricBar(labels, values, tileTitle, yLabel)
nexttile;
bars = bar(labels, values, FaceColor="flat");
bars.CData = [0.00 0.45 0.74; 0.47 0.67 0.19; ...
    0.85 0.33 0.10; 0.49 0.18 0.56];
ylabel(yLabel);
title(tileTitle);
grid on;
xtickangle(16);
maximum = max(values, [], "omitnan");
ylim([0, 1.2*maximum]);
for index = find(isfinite(values))
    text(index, values(index), sprintf(" %.4g", values(index)), ...
        HorizontalAlignment="center", VerticalAlignment="bottom");
end
end

function file = exportFigure(fig, folder, name)
file = fullfile(folder, name);
exportgraphics(fig, file, Resolution=200);
close(fig);
end
