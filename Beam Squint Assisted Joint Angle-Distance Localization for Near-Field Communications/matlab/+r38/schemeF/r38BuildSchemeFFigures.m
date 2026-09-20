function manifest = r38BuildSchemeFFigures(summary, folder)
%R38BUILDSCHEMEFFIGURES Render the fixed Scheme F development figures.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
notice = "Development study - not R34 final validation";
files = strings(5, 1);
files(1) = angleFigure(summary.methodSummary, figureFolder, notice);
files(2) = pairedGainFigure(summary.perUser, figureFolder, notice);
files(3) = scoreTruthFigure(summary.perUser, figureFolder, notice);
files(4) = displacementFigure(summary.perUser, figureFolder, notice);
files(5) = complexityFigure(summary.perUser, figureFolder, notice);
manifest = table((1:5).', files, repmat(notice, 5, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function file = angleFigure(rows, folder, notice)
methods = ["P_A", "E_reference", "F_raw_vpml"];
snrValues = unique(rows.snrDb).';
values = zeros(numel(snrValues), numel(methods));
for methodIndex = 1:numel(methods)
    for snrIndex = 1:numel(snrValues)
        selected = rows.method == methods(methodIndex) ...
            & rows.snrDb == snrValues(snrIndex);
        values(snrIndex, methodIndex) = rows.angleRmseDeg(selected);
    end
end
fig = figure(Visible="off", Color="w", Position=[100 100 900 520]);
hold on;
colors = [0 0.4470 0.7410; 0.4660 0.6740 0.1880; ...
    0.8500 0.3250 0.0980];
markers = ["o", "d", "s"];
for index = 1:numel(methods)
    semilogy(snrValues, values(:, index), "-"+markers(index), ...
        Color=colors(index, :), LineWidth=1.8, MarkerSize=7);
end
xticks(snrValues);
xlabel("SNR (dB)");
ylabel("Angle RMSE (deg)");
legend(["P_A", "Scheme E reference", "Scheme F raw VPML"], ...
    Location="best");
title("Raw-array VPML angle performance"+newline+notice);
grid on;
file = exportFigure(fig, folder, "F_F1_angle_rmse.png");
end

function file = pairedGainFigure(perUser, folder, notice)
fig = figure(Visible="off", Color="w", Position=[100 100 800 520]);
boxchart(categorical(string(perUser.snrDb)+" dB"), ...
    perUser.truthSquaredErrorGainDeg2);
yline(0, "k--");
xlabel("SNR");
ylabel("P_A squared error - Scheme F squared error (deg^2)");
title("Paired truth-angle gain"+newline+notice);
grid on;
file = exportFigure(fig, folder, "F_F2_paired_truth_gain.png");
end

function file = scoreTruthFigure(perUser, folder, notice)
fig = figure(Visible="off", Color="w", Position=[100 100 800 520]);
scatter(perUser.scoreGain, perUser.truthSquaredErrorGainDeg2, ...
    42, perUser.snrDb, "filled");
xline(0, "k--");
yline(0, "k--");
xlabel("Concentrated VPML score gain");
ylabel("P_A squared error - Scheme F squared error (deg^2)");
title("Likelihood gain versus truth-angle gain"+newline+notice);
colorbar;
grid on;
file = exportFigure(fig, folder, "F_F3_score_vs_truth_gain.png");
end

function file = displacementFigure(perUser, folder, notice)
fig = figure(Visible="off", Color="w", Position=[100 100 800 520]);
boxchart(categorical(string(perUser.snrDb)+" dB"), ...
    perUser.angleDisplacementDeg);
yline(0, "k--");
xlabel("SNR");
ylabel("theta_F - theta_A (deg)");
title("Raw-array VPML angle displacement"+newline+notice);
grid on;
file = exportFigure(fig, folder, "F_F4_displacement.png");
end

function file = complexityFigure(perUser, folder, notice)
labels = categorical(["P_A", "Scheme E", "Scheme F", "C enhanced"], ...
    ["P_A", "Scheme E", "Scheme F", "C enhanced"]);
runtime = [mean(perUser.runtime_P_A), ...
    mean(perUser.runtime_E_reference), ...
    mean(perUser.runtime_F_raw_vpml), ...
    mean(perUser.runtime_C_enhanced)];
responses = [mean(perUser.responseCount_P_A), ...
    mean(perUser.responseCount_E_reference), ...
    mean(perUser.responseCount_F_raw_vpml), ...
    mean(perUser.responseCount_C_enhanced)];
fig = figure(Visible="off", Color="w", Position=[100 100 1050 500]);
tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
metricTile(labels, runtime, "Standalone runtime", "Seconds/user");
metricTile(labels, responses, "Response-equivalent evaluations", ...
    "Count/user");
sgtitle("Scheme F complexity"+newline+notice);
file = exportFigure(fig, folder, "F_F5_complexity.png");
end

function metricTile(labels, values, tileTitle, yLabel)
nexttile;
bars = bar(labels, values, FaceColor="flat");
bars.CData = [0 0.4470 0.7410; 0.4660 0.6740 0.1880; ...
    0.8500 0.3250 0.0980; 0.4940 0.1840 0.5560];
ylabel(yLabel);
title(tileTitle);
grid on;
ylim([0, 1.22*max(values)]);
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
