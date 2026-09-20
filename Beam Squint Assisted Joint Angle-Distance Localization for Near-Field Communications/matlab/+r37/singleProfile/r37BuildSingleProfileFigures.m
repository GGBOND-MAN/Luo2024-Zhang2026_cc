function manifest = r37BuildSingleProfileFigures(summary, folder)
%R37BUILDSINGLEPROFILEFIGURES Render fixed performance and cost figures.

arguments
    summary (1, 1) struct
    folder (1, 1) string
end

if ~isfolder(folder)
    mkdir(folder);
end
notice = "Retrospective calibration engineering - not final validation";
files = strings(4, 1);
files(1) = metricFigure(summary.all600.methodSummary, ...
    "angleRmseDeg", "Angle RMSE (deg)", true, folder, ...
    "R37_F1_angle_rmse.png", notice);
files(2) = metricFigure(summary.all600.methodSummary, ...
    "rangeRmseM", "Range RMSE (m)", true, folder, ...
    "R37_F2_range_rmse.png", notice);
files(3) = complexityFigure(summary.perUser, folder, notice);
files(4) = rangeDifferenceFigure(summary.perUser, folder, notice);
manifest = table((1:4).', files, repmat(notice, 4, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
end

function file = metricFigure(rows, field, yLabel, useLog, ...
    folder, name, notice)
methods = ["P_A", "Scheme_E_full", "E_single_profile"];
snrValues = unique(rows.snrDb).';
values = zeros(numel(snrValues), numel(methods));
for methodIndex = 1:numel(methods)
    for snrIndex = 1:numel(snrValues)
        selected = rows.method == methods(methodIndex) ...
            & rows.snrDb == snrValues(snrIndex);
        values(snrIndex, methodIndex) = rows.(field)(selected);
    end
end
fig = figure(Visible="off", Color="w", Position=[100 100 930 520]);
hold on;
colors = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; ...
    0.4660 0.6740 0.1880];
markers = ["o", "s", "d"];
for index = 1:numel(methods)
    if useLog
        semilogy(snrValues, values(:, index), "-"+markers(index), ...
            Color=colors(index, :), LineWidth=1.8, MarkerSize=7);
    else
        plot(snrValues, values(:, index), "-"+markers(index), ...
            Color=colors(index, :), LineWidth=1.8, MarkerSize=7);
    end
end
grid on;
xticks(snrValues);
xlabel("SNR (dB)");
ylabel(yLabel);
legend(["P_A", "Scheme E full", "E single-profile"], ...
    Location="best");
title(yLabel+newline+notice);
file = exportFigure(fig, folder, name);
end

function file = complexityFigure(perUser, folder, notice)
methods = categorical(["P_A", "Scheme E full", "E single-profile"], ...
    ["P_A", "Scheme E full", "E single-profile"]);
runtime = [mean(perUser.runtime_P_A), mean(perUser.runtime_E_full), ...
    mean(perUser.runtime_E_single)];
responses = [mean(perUser.responseCount_P_A), ...
    mean(perUser.responseCount_E_full), ...
    mean(perUser.responseCount_E_single)];
passes = [mean(perUser.profilePasses_P_A), ...
    mean(perUser.profilePasses_E_full), ...
    mean(perUser.profilePasses_E_single)];
evaluations = [mean(perUser.profileEvaluations_P_A), ...
    mean(perUser.profileEvaluations_E_full), ...
    mean(perUser.profileEvaluations_E_single)];
fig = figure(Visible="off", Color="w", Position=[100 100 1080 720]);
tiledlayout(2, 2, TileSpacing="compact", Padding="compact");
metricTile(methods, runtime, "Standalone runtime", "Seconds/user");
metricTile(methods, responses, "Response evaluations", "Count/user");
metricTile(methods, passes, "Complete range profiles", "Passes/user");
metricTile(methods, evaluations, "Range-profile evaluations", "Count/user");
sgtitle("R37 complexity comparison"+newline+notice);
file = exportFigure(fig, folder, "R37_F3_complexity.png");
end

function file = rangeDifferenceFigure(perUser, folder, notice)
snrValues = unique(perUser.snrDb).';
fig = figure(Visible="off", Color="w", Position=[100 100 930 520]);
hold on;
for snrDb = snrValues
    values = sort(abs(perUser.singleMinusFullRangeM( ...
        perUser.snrDb == snrDb)));
    probability = (1:numel(values)).'/numel(values);
    semilogx(max(values, 1e-12), probability, LineWidth=1.6, ...
        DisplayName=sprintf("%g dB", snrDb));
end
set(gca, XScale="log");
grid on;
xlabel("|single-profile range - full-profile range| (m)");
ylabel("Empirical CDF");
legend(Location="southeast");
title("Range approximation error"+newline+notice);
file = exportFigure(fig, folder, "R37_F4_range_difference_cdf.png");
end

function metricTile(labels, values, tileTitle, yLabel)
nexttile;
bars = bar(labels, values, FaceColor="flat");
bars.CData = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; ...
    0.4660 0.6740 0.1880];
ylabel(yLabel);
title(tileTitle);
grid on;
maximum = max(values);
if maximum <= 0
    maximum = 1;
end
ylim([0, 1.22*maximum]);
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
