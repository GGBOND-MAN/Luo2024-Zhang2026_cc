function manifest = r38BuildSchemeFCalibrationFigures(summary, folder)
%R38BUILDSCHEMEFCALIBRATIONFIGURES Render fixed calibration comparisons.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
notice = "Calibration study - not R34 final validation";
files = strings(5, 1);
files(1) = angleFigure(summary.all600.methodSummary, ...
    "All 600 calibration rows", figureFolder, ...
    "FC_F1_angle_all600.png", notice);
files(2) = angleFigure(summary.holdout540.methodSummary, ...
    "Fixed holdout 540", figureFolder, ...
    "FC_F2_angle_holdout540.png", notice);
files(3) = rangeFigure(summary.all600.methodSummary, ...
    figureFolder, notice);
files(4) = complexityFigure(summary.perUser, figureFolder, notice);
files(5) = endpointFigure(summary.all600.diagnostics, ...
    summary.holdout540.diagnostics, figureFolder, notice);
manifest = table((1:5).', files, repmat(notice, 5, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function file = angleFigure(rows, populationTitle, folder, name, notice)
methods = ["P_A", "E_single", "F_raw_vpml"];
snrValues = unique(rows.snrDb).';
values = metricMatrix(rows, methods, snrValues, "angleRmseDeg");
fig = figure(Visible="off", Color="w", Position=[100 100 920 520]);
plotMethods(snrValues, values);
xlabel("SNR (dB)");
ylabel("Angle RMSE (deg)");
legend(["P_A", "E single-profile", "F raw VPML"], ...
    Location="best");
title("Scheme F angle calibration: "+populationTitle+newline+notice);
grid on;
set(gca, YScale="log");
file = exportFigure(fig, folder, name);
end

function file = rangeFigure(rows, folder, notice)
methods = ["P_A", "E_single", "F_raw_vpml"];
snrValues = unique(rows.snrDb).';
values = metricMatrix(rows, methods, snrValues, "rangeRmseM");
fig = figure(Visible="off", Color="w", Position=[100 100 920 520]);
plotMethods(snrValues, values);
xlabel("SNR (dB)");
ylabel("Range RMSE (m)");
legend(["P_A", "E single-profile", "F raw VPML"], ...
    Location="best");
title("Range performance after frozen profile"+newline+notice);
grid on;
set(gca, YScale="log");
file = exportFigure(fig, folder, "FC_F3_range_all600.png");
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

function plotMethods(snrValues, values)
hold on;
colors = [0 0.4470 0.7410; 0.4660 0.6740 0.1880; ...
    0.8500 0.3250 0.0980];
markers = ["o", "d", "s"];
for index = 1:size(values, 2)
    semilogy(snrValues, values(:, index), "-"+markers(index), ...
        Color=colors(index, :), LineWidth=1.8, MarkerSize=7);
end
xticks(snrValues);
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
fig = figure(Visible="off", Color="w", Position=[100 100 1200 600]);
tiledlayout(1, 3, TileSpacing="compact", Padding="compact");
metricTile(labels, runtime, "Standalone runtime", "Seconds/user");
metricTile(labels, responses, "Response-equivalent evaluations", ...
    "Count/user");
metricTile(labels, profiles, "Complete range profiles", "Passes/user");
sgtitle("Scheme F calibration complexity"+newline+notice);
file = exportFigure(fig, folder, "FC_F4_complexity.png");
end

function file = endpointFigure(allDiagnostics, holdoutDiagnostics, ...
    folder, notice)
allRows = allDiagnostics(allDiagnostics.scope == "per-SNR", :);
holdoutRows = holdoutDiagnostics( ...
    holdoutDiagnostics.scope == "per-SNR", :);
snrValues = allRows.snrDb;
values = 100*[allRows.bracketEndpointSelectedCount./allRows.n, ...
    holdoutRows.bracketEndpointSelectedCount./holdoutRows.n];
fig = figure(Visible="off", Color="w", Position=[100 100 850 500]);
bar(categorical(string(snrValues), string(snrValues)), values);
xlabel("SNR (dB)");
ylabel("Bracket endpoint selection (%)");
legend(["All 600", "Holdout 540"], Location="best");
title("Frozen-bracket saturation"+newline+notice);
grid on;
file = exportFigure(fig, folder, "FC_F5_endpoint_rate.png");
end

function metricTile(labels, values, tileTitle, yLabel)
nexttile;
bars = bar(labels, values, FaceColor="flat");
bars.CData = [0 0.4470 0.7410; 0.4660 0.6740 0.1880; ...
    0.8500 0.3250 0.0980; 0.4940 0.1840 0.5560];
ylabel(yLabel);
title(tileTitle);
grid on;
xtickangle(18);
maximum = max(values, [], "omitnan");
ylim([0, 1.22*maximum]);
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
