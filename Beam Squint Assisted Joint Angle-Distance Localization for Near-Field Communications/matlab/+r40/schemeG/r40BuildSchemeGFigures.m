function manifest = r40BuildSchemeGFigures(summary, folder, notice)
%R40BUILDSCHEMEGFIGURES Render the seven fixed Scheme G figures.

arguments
    summary (1, 1) struct
    folder (1, 1) string
    notice (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
files = strings(7, 1);
files(1) = angleFigure(summary, figureFolder, notice);
files(2) = pairedFigure(summary, figureFolder, notice);
files(3) = couplingFigure(summary, figureFolder, notice);
files(4) = stepFigure(summary, figureFolder, notice);
files(5) = rangeStepFigure(summary, figureFolder, notice);
files(6) = runtimeFigure(summary, figureFolder, notice);
files(7) = tradeoffFigure(summary, figureFolder, notice);
manifest = table((1:7).', files, repmat(notice, 7, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function file = angleFigure(summary, folder, notice)
rows = summary.methodSummary;
methods = ["P_A", "C_enhanced", "E_single", "F", ...
    "G_fixed", "G_schur"];
labels = ["P_A", "C enhanced", "E single", "F", ...
    "G fixed", "G Schur"];
snrValues = unique(rows.snrDb).';
values = metricMatrix(rows, methods, snrValues, "angleRmseDeg");
fig = figure(Visible="off", Color="w", Position=[100 100 1080 600]);
plotMethods(snrValues, values, labels);
xlabel("SNR (dB)"); ylabel("Angle RMSE (deg)");
set(gca, YScale="log"); grid on;
title("Scheme G angle performance"+newline+notice);
file = exportFigure(fig, folder, "G_F1_angle_RMSE_vs_methods.png");
end

function file = pairedFigure(summary, folder, notice)
p = summary.perUser;
references = ["C_enhanced", "P_A", "F"];
titles = ["G Schur vs C", "G Schur vs P_A", "G Schur vs F"];
fig = figure(Visible="off", Color="w", Position=[100 100 1400 520]);
tiledlayout(1, 3, TileSpacing="compact", Padding="compact");
for index = 1:3
    nexttile;
    candidateError = (p.theta_G_schur-p.truthThetaDeg).^2;
    referenceError = (p.("theta_"+references(index)) ...
        -p.truthThetaDeg).^2;
    boxchart(categorical(string(p.snrDb)+" dB"), ...
        referenceError-candidateError);
    yline(0, "k-"); grid on;
    xlabel("SNR"); ylabel("Reference SE - G SE (deg^2)");
    title(titles(index));
end
sgtitle("Paired angle gain"+newline+notice);
file = exportFigure(fig, folder, "G_F2_paired_angle_gain.png");
end

function file = couplingFigure(summary, folder, notice)
p = summary.perUser;
fig = figure(Visible="off", Color="w", Position=[100 100 900 540]);
boxchart(categorical(string(p.snrDb)+" dB"), p.normalizedCoupling);
yline(0, "k-"); grid on;
xlabel("SNR"); ylabel("Normalized coupling rho_G");
title("Full-array angle-range information coupling"+newline+notice);
file = exportFigure(fig, folder, "G_F3_normalized_range_coupling.png");
end

function file = stepFigure(summary, folder, notice)
p = summary.perUser;
fig = figure(Visible="off", Color="w", Position=[100 100 1200 540]);
tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
scatter(p.selectedStepDeg_G_fixed, p.selectedStepDeg_G_schur, ...
    48, p.snrDb, "filled"); hold on;
limit = max(abs([p.selectedStepDeg_G_fixed; ...
    p.selectedStepDeg_G_schur]));
plot([-limit, limit], [-limit, limit], "k--"); axis equal; grid on;
xlabel("G fixed step (deg)"); ylabel("G Schur step (deg)");
title("Accepted/clipped steps"); colorbar;
nexttile;
boxchart(categorical(string(p.snrDb)+" dB"), p.stepDifferenceDeg);
yline(0, "k-"); grid on;
xlabel("SNR"); ylabel("G Schur - G fixed (deg)");
title("Schur correction");
sgtitle("Schur versus fixed-range control"+newline+notice);
file = exportFigure(fig, folder, "G_F4_Schur_vs_fixed_step.png");
end

function file = rangeStepFigure(summary, folder, notice)
p = summary.perUser;
fig = figure(Visible="off", Color="w", Position=[100 100 1100 540]);
tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
scatter(p.arrayDeltaRangeRaw_G_schur, p.qDeltaRangeRaw_G_schur, ...
    48, p.snrDb, "filled");
xline(0, "k-"); yline(0, "k-"); grid on; colorbar;
xlabel("Array nuisance delta r (m)");
ylabel("Exact q-profile delta r (m)");
title("Raw local range directions");
nexttile;
ratio = abs(p.arrayDeltaRangeRaw_G_schur) ...
    ./max(abs(p.qDeltaRangeRaw_G_schur), realmin);
boxchart(categorical(string(p.snrDb)+" dB"), ratio);
set(gca, YScale="log"); grid on;
xlabel("SNR"); ylabel("|delta r array| / |delta r q|");
title("Magnitude disagreement");
sgtitle("Array nuisance versus q-profile transport"+newline+notice);
file = exportFigure(fig, folder, "G_F5_array_vs_q_range_step.png");
end

function file = runtimeFigure(summary, folder, notice)
p = summary.perUser;
components = [mean(p.runtime_P_A), 0, 0, 0; ...
    mean(p.runtime_P_A), mean(p.contextSeconds_G_schur), ...
    mean(p.linearizationSeconds_G_schur ...
    +p.safeguardSeconds_G_schur), mean(p.qTransportSeconds_G_schur)];
labels = categorical(["P_A", "G Schur"], ["P_A", "G Schur"]);
fig = figure(Visible="off", Color="w", Position=[100 100 1200 540]);
tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
bar(labels, components, "stacked"); grid on;
ylabel("Seconds/user");
legend(["P_A frozen path", "raw context", ...
    "VP derivative+safeguard", "q transport"], Location="best");
title("G complete runtime breakdown");
nexttile;
methodLabels = categorical(["P_A", "G Schur", "F", "C enh."], ...
    ["P_A", "G Schur", "F", "C enh."]);
totals = [mean(p.runtime_P_A), mean(p.runtime_G_schur), ...
    mean(p.runtime_F), mean(p.runtime_C_enhanced)];
bars = bar(methodLabels, totals, FaceColor="flat");
bars.CData = [0.00 0.45 0.74; 0.85 0.33 0.10; ...
    0.47 0.67 0.19; 0.49 0.18 0.56];
grid on; ylabel("Seconds/user"); title("Complete online runtime");
for index = 1:numel(totals)
    text(index, totals(index), sprintf(" %.4g", totals(index)), ...
        HorizontalAlignment="center", VerticalAlignment="bottom");
end
sgtitle("Runtime and incremental cost"+newline+notice);
file = exportFigure(fig, folder, "G_F6_runtime_breakdown.png");
end

function file = tradeoffFigure(summary, folder, notice)
rows = summary.methodSummary;
methods = ["P_A", "C_enhanced", "E_single", "F", "G_schur"];
labels = ["P_A", "C enhanced", "E single", "F", "G Schur"];
snrValues = unique(rows.snrDb).';
fig = figure(Visible="off", Color="w", Position=[100 100 1420 540]);
tiledlayout(1, 3, TileSpacing="compact", Padding="compact");
fields = ["angleMseDeg2", "rangeMseM2", "positionRmseM"];
titles = ["Angle MSE ratio to C", "Range MSE ratio to C", ...
    "Position RMSE ratio to C"];
for fieldIndex = 1:3
    nexttile; hold on;
    values = metricMatrix(rows, methods, snrValues, fields(fieldIndex));
    reference = metricMatrix(rows, "C_enhanced", snrValues, ...
        fields(fieldIndex));
    ratio = values./reference;
    plotMethodsLinear(snrValues, ratio, labels);
    yline(1, "k-"); grid on;
    xlabel("SNR (dB)"); ylabel("Ratio"); title(titles(fieldIndex));
end
sgtitle("Angle-range-accuracy tradeoff"+newline+notice);
file = exportFigure(fig, folder, ...
    "G_F7_angle_range_accuracy_complexity_tradeoff.png");
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
colors = lines(size(values, 2));
markers = ["o", "^", "d", "s", "v", ">"];
for index = 1:size(values, 2)
    semilogy(snrValues, values(:, index), "-"+markers(index), ...
        Color=colors(index, :), LineWidth=1.7, MarkerSize=7);
end
xticks(snrValues); legend(labels, Location="best");
end

function plotMethodsLinear(snrValues, values, labels)
colors = lines(size(values, 2));
markers = ["o", "^", "d", "s", "v"];
for index = 1:size(values, 2)
    plot(snrValues, values(:, index), "-"+markers(index), ...
        Color=colors(index, :), LineWidth=1.6, MarkerSize=6);
end
xticks(snrValues); legend(labels, Location="best");
end

function file = exportFigure(fig, folder, name)
file = fullfile(folder, name);
exportgraphics(fig, file, Resolution=200);
close(fig);
end
