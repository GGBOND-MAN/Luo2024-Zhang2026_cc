function manifest = r39BuildAblationFigures(summary, folder)
%R39BUILDABLATIONFIGURES Render the fixed aperture-likelihood ablation.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
notice = "R39 existing-60 mechanism evidence - not final validation";
files = strings(4, 1);
files(1) = performanceFigure(summary.methodSummary, figureFolder, notice);
files(2) = factorFigure(summary.factorial, figureFolder, notice);
files(3) = rangeFigure(summary.methodSummary, figureFolder, notice);
files(4) = complexityFigure(summary.perUser, figureFolder, notice);
manifest = table((1:4).', files, repmat(notice, 4, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function file = performanceFigure(rows, folder, notice)
methods = ["P_A", "L160_uniform", "L160_vpml", ...
    "N256_uniform", "N256_vpml"];
labels = ["P_A", "L160 uniform", "L160 VPML", ...
    "N256 uniform", "N256 VPML (F)"];
snrValues = unique(rows.snrDb).';
values = metricMatrix(rows, methods, snrValues, "angleRmseDeg");
fig = figure(Visible="off", Color="w", Position=[100 100 1040 580]);
plotMethods(snrValues, values, labels);
xlabel("SNR (dB)");
ylabel("Angle RMSE (deg)");
title("Aperture-likelihood factorial: angle RMSE"+newline+notice);
set(gca, YScale="log");
grid on;
file = exportFigure(fig, folder, "R39_F1_angle_factorial.png");
end

function file = factorFigure(rows, folder, notice)
row = rows(rows.scope == "equal-SNR", :);
labels = categorical(["Aperture|uniform", "Aperture|VPML", ...
    "VPML|L160", "VPML|N256"]);
labels = reordercats(labels, ["Aperture|uniform", "Aperture|VPML", ...
    "VPML|L160", "VPML|N256"]);
values = [row.apertureRmseImprovementUnderUniformPercent, ...
    row.apertureRmseImprovementUnderVpmlPercent, ...
    row.likelihoodRmseImprovementAtL160Percent, ...
    row.likelihoodRmseImprovementAtN256Percent];
fig = figure(Visible="off", Color="w", Position=[100 100 960 560]);
bars = bar(labels, values, FaceColor="flat");
bars.CData = [0.20 0.49 0.72; 0.12 0.63 0.47; ...
    0.93 0.69 0.13; 0.84 0.37 0.00];
yline(0, "k-");
ylabel("Equal-SNR angle RMSE improvement (%)");
title("Marginal mechanism contributions"+newline+notice);
grid on;
for index = 1:numel(values)
    text(index, values(index), sprintf(" %.3f%%", values(index)), ...
        HorizontalAlignment="center", ...
        VerticalAlignment=verticalAlignment(values(index)));
end
file = exportFigure(fig, folder, "R39_F2_factor_contributions.png");
end

function alignment = verticalAlignment(value)
if value >= 0
    alignment = "bottom";
else
    alignment = "top";
end
end

function file = rangeFigure(rows, folder, notice)
methods = ["P_A", "L160_uniform", "L160_vpml", ...
    "N256_uniform", "N256_vpml"];
labels = ["P_A", "L160 uniform", "L160 VPML", ...
    "N256 uniform", "N256 VPML (F)"];
snrValues = unique(rows.snrDb).';
values = metricMatrix(rows, methods, snrValues, "rangeRmseM");
fig = figure(Visible="off", Color="w", Position=[100 100 1040 580]);
plotMethods(snrValues, values, labels);
xlabel("SNR (dB)");
ylabel("Range RMSE (m)");
title("Frozen profile after each angle variant"+newline+notice);
set(gca, YScale="log");
grid on;
file = exportFigure(fig, folder, "R39_F3_range_factorial.png");
end

function file = complexityFigure(perUser, folder, notice)
methods = ["P_A", "L160_uniform", "L160_vpml", ...
    "N256_uniform", "N256_vpml", "C_enhanced"];
labels = categorical(["P_A", "L160 U", "L160 ML", ...
    "N256 U", "N256 ML", "C enh."], ...
    ["P_A", "L160 U", "L160 ML", "N256 U", "N256 ML", "C enh."]);
runtime = zeros(1, numel(methods));
responses = zeros(1, numel(methods));
for index = 1:numel(methods)
    runtime(index) = mean(perUser.("runtime_"+methods(index)));
    responses(index) = mean(perUser.("responseCount_"+methods(index)));
end
fig = figure(Visible="off", Color="w", Position=[100 100 1180 560]);
tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
metricTile(labels, runtime, "Standalone runtime", "Seconds/user");
metricTile(labels, responses, "Response-equivalent evaluations", ...
    "Count/user");
sgtitle("Ablation complexity"+newline+notice);
file = exportFigure(fig, folder, "R39_F4_complexity.png");
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
colors = [0.00 0.45 0.74; 0.30 0.30 0.30; 0.49 0.18 0.56; ...
    0.47 0.67 0.19; 0.85 0.33 0.10];
markers = ["o", "^", "d", "v", "s"];
for index = 1:size(values, 2)
    semilogy(snrValues, values(:, index), "-"+markers(index), ...
        Color=colors(index, :), LineWidth=1.8, MarkerSize=7);
end
xticks(snrValues);
legend(labels, Location="best");
end

function metricTile(labels, values, tileTitle, yLabel)
nexttile;
bars = bar(labels, values, FaceColor="flat");
bars.CData = lines(numel(values));
ylabel(yLabel);
title(tileTitle);
grid on;
xtickangle(18);
ylim([0, 1.18*max(values)]);
for index = 1:numel(values)
    text(index, values(index), sprintf(" %.4g", values(index)), ...
        HorizontalAlignment="center", VerticalAlignment="bottom");
end
end

function file = exportFigure(fig, folder, name)
file = fullfile(folder, name);
exportgraphics(fig, file, Resolution=200);
close(fig);
end
