function manifest = r35BuildSchemeDFigures( ...
    summary, allWeights, frequencyHz, folder)
%R35BUILDSCHEMEdFIGURES Build the five declared development figures.

arguments
    summary (1, 1) struct
    allWeights (1, 1) struct
    frequencyHz (:, :) double
    folder (1, 1) string
end

figureFolder = fullfile(folder, "figures");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
notice = "Development study – not R34 final confirmation";
files = strings(5, 1);
snrValues = unique(summary.perUser.snrDb).';
methods = ["D0_uniform", "D1_gap", "D2_information", "D3_mix"];

fig = figure(Visible="off", Color="w", Position=[100 100 780 560]);
values = zeros(numel(snrValues), numel(methods));
for methodIndex = 1:numel(methods)
    rows = summary.methodSummary( ...
        summary.methodSummary.method == methods(methodIndex), :);
    rows = sortrows(rows, "snrDb");
    values(:, methodIndex) = rows.angleRmseDeg;
end
bar(categorical(string(snrValues)), values);
xlabel("SNR (dB)"); ylabel("Angle RMSE (deg)");
title("Uniform and weighted all-carrier MUSIC angle RMSE");
subtitle(notice); grid on;
legend(["D0 uniform", "D1 gap", "D2 information", "D3 mix"], ...
    Location="best");
files(1) = exportFigure(fig, figureFolder, "D_F1_angle_rmse.png");

fig = figure(Visible="off", Color="w", Position=[100 100 980 760]);
tiledlayout(3, 3, TileSpacing="compact", Padding="compact");
weightedMethods = ["D1_gap", "D2_information", "D3_mix"];
colors = lines(3);
for snrIndex = 1:numel(snrValues)
    snrRows = find(summary.perUser.snrDb == snrValues(snrIndex));
    for methodIndex = 1:numel(weightedMethods)
        nexttile;
        method = weightedMethods(methodIndex);
        diagnostics = summary.weightDiagnostics( ...
            summary.weightDiagnostics.method == method ...
            & summary.weightDiagnostics.snrDb == snrValues(snrIndex), :);
        [~, medianIndex] = min(abs(diagnostics.effectiveCarrierCount ...
            -median(diagnostics.effectiveCarrierCount)));
        user = snrRows(medianIndex);
        frequency = frequencyHz(:, min(user, size(frequencyHz, 2)));
        plot(frequency/1e9, allWeights.(method)(:, user), ...
            Color=colors(methodIndex, :), LineWidth=1);
        title(sprintf("%s, %g dB", method, snrValues(snrIndex)), ...
            Interpreter="none");
        xlabel("Frequency (GHz)"); ylabel("Weight"); grid on;
    end
end
sgtitle("Representative median-K_{eff} carrier weights"+newline+notice);
files(2) = exportFigure(fig, figureFolder, ...
    "D_F2_representative_weights.png");

fig = figure(Visible="off", Color="w", Position=[100 100 820 560]);
weighted = summary.weightDiagnostics( ...
    summary.weightDiagnostics.method ~= "D0_uniform", :);
groups = categorical(replace(weighted.method, "_", " ") ...
    +" / "+string(weighted.snrDb)+" dB");
boxchart(groups, weighted.effectiveCarrierCount);
ylabel("Effective carrier count K_{eff}"); xtickangle(30);
title("Effective carrier count by weighting rule and SNR");
subtitle(notice); grid on;
files(3) = exportFigure(fig, figureFolder, "D_F3_keff_distribution.png");

fig = figure(Visible="off", Color="w", Position=[100 100 820 560]);
gainRows = stack(summary.perUser, ...
    {'truthSquaredErrorGain_D1', 'truthSquaredErrorGain_D2', ...
    'truthSquaredErrorGain_D3'}, NewDataVariableName="gain", ...
    IndexVariableName="method");
gainRows.method = categorical(erase(string(gainRows.method), ...
    "truthSquaredErrorGain_"));
boxchart(gainRows.method, gainRows.gain, GroupByColor= ...
    categorical(gainRows.snrDb));
yline(0, "k--"); xlabel("Scheme");
ylabel("D0 squared error - D squared error (deg^2)");
title("Paired truth-angle squared-error gain"); subtitle(notice);
legend(string(snrValues)+" dB", Location="best"); grid on;
files(4) = exportFigure(fig, figureFolder, "D_F4_paired_angle_gain.png");

fig = figure(Visible="off", Color="w", Position=[100 100 760 560]);
scatter(weighted.normalizedEntropy, ...
    weighted.truthSquaredErrorGainDeg2, 34, weighted.snrDb, "filled");
yline(0, "k--"); xlabel("Normalized weight entropy");
ylabel("D0 squared error - D squared error (deg^2)");
title("Weight entropy vs truth-angle gain"); subtitle(notice);
colorbar; grid on;
files(5) = exportFigure(fig, figureFolder, ...
    "D_F5_entropy_vs_angle_gain.png");

manifest = table((1:5).', files, repmat(notice, 5, 1), ...
    'VariableNames', {'figureId', 'file', 'notice'});
writetable(manifest, fullfile(figureFolder, "figure_manifest.csv"));
end

function file = exportFigure(fig, folder, name)
file = fullfile(folder, name);
exportgraphics(fig, file, Resolution=200);
close(fig);
end
