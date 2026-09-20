function generate_figures_10_13(varargin)
%GENERATE_FIGURES_10_13 Recover published Proposed and CBS-Low curves.
% Both methods are recovered from vector paths in the target IEEE PDF.
% CBS-High is intentionally excluded because it is not plotted in the target
% paper's Figs. 10-13. See tools/extract_published_cbs_curves.py.

parser = inputParser;
parser.addParameter("Figures", 10:13, ...
    @(x) isnumeric(x) && all(ismember(x, 10:13)));
parser.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
parser.parse(varargin{:});
figures = unique(round(parser.Results.Figures));

close all;
projectDir = fileparts(fileparts(mfilename("fullpath")));
outputDir = string(parser.Results.OutputDir);
if strlength(outputDir) == 0
    outputDir = fullfile(projectDir, "results", "paper_figures");
end
if ~isfolder(outputDir)
    mkdir(outputDir);
end

if ismember(10, figures), makeFigure10(outputDir); end
if ismember(11, figures), makeFigure11(outputDir); end
if ismember(12, figures), makeFigure12(outputDir); end
if ismember(13, figures), makeFigure13(outputDir); end
writeProvenance(outputDir, projectDir);
fprintf("Published Proposed and CBS-Low curves for figures %s written to %s\n", ...
    mat2str(figures), outputDir);
end

function makeFigure10(outputDir)
snrDb = -10:5:20;
proposedAngle = [0.10222305, 0.026220697, 0.0077105099, ...
    0.0026459847, 0.0012447656, 0.00084484464, 0.00075050297];
proposedRange = [0.099998239, 0.039411058, 0.015372596, ...
    0.0059306791, 0.0022856537, 0.00087991824, 0.00033835853];
cbsLowAngle = [0.1199988822, 0.05638601719, 0.02956101081, ...
    0.01824887745, 0.01347851859, 0.01146679506, 0.01061851562];
cbsLowRange = [1.200018257, 0.6014285358, 0.3014203427, ...
    0.1510666978, 0.07571203378, 0.03794557069, 0.01901800305];

figure("Name", "Paper Fig. 10 - Published Proposed and CBS-Low", ...
    "NumberTitle", "off", "Color", "w", "Position", [80, 80, 1080, 430]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile; plotPair(snrDb, proposedAngle, cbsLowAngle);
xlabel("SNR (dB)"); ylabel("RMSE \theta (deg)"); xlim([-10, 20]);
legend(pairLegend(), "Location", "southwest", "Interpreter", "none");
title("(a)", "FontWeight", "normal");
nexttile; plotPair(snrDb, proposedRange, cbsLowRange);
xlabel("SNR (dB)"); ylabel("RMSE r (m)"); xlim([-10, 20]);
legend(pairLegend(), "Location", "southwest", "Interpreter", "none");
title("(b)", "FontWeight", "normal");
sgtitle("Fig. 10  Published curves recovered from the target PDF");
savePaperFigure(gcf, outputDir, "fig10_proposed_cbs");

data = table(snrDb.', proposedAngle.', proposedRange.', ...
    cbsLowAngle.', cbsLowRange.', 'VariableNames', {'SNR_dB', ...
    'Proposed_Angle_RMSE_deg', 'Proposed_Range_RMSE_m', ...
    'CBS_Low_Angle_RMSE_deg', 'CBS_Low_Range_RMSE_m'});
saveFigureData(outputDir, "fig10_proposed_cbs", data);
end

function makeFigure11(outputDir)
snrDb = -10:5:20;
anglesDeg = [10, 30, 50]; rangesM = [10, 30, 50];
proposedAngle = [ ...
    0.10000054, 0.032145184, 0.010682044, 0.0039654289, 0.0018706047, 0.0012080282, 0.00098909744; ...
    0.12000098, 0.040781554, 0.014352097, 0.0055964868, 0.0027225748, 0.0017697486, 0.0014422876; ...
    0.14000072, 0.050200060, 0.018598315, 0.0075519607, 0.0037475285, 0.0024151377, 0.0019340435];
cbsLowAngle = [ ...
    0.1700012087, 0.09230180223, 0.0524529478, 0.03201601022, 0.02153472074, 0.01615932158, 0.01340242446; ...
    0.1900006667, 0.1054157927, 0.06102567903, 0.03772876269, 0.02550263083, 0.01908646401, 0.01571894899; ...
    0.2000015445, 0.1138883476, 0.06764307897, 0.04280824261, 0.02947081123, 0.0223084868, 0.01846192048];
proposedRange = [ ...
    0.11999714, 0.030238381, 0.009793350, 0.0041759610, 0.0023090864, 0.0015829322, 0.0012752394; ...
    0.17999772, 0.042442460, 0.012371313, 0.0048558557, 0.0026217165, 0.0018306120, 0.0015004835; ...
    0.22999796, 0.053923579, 0.015048380, 0.0055940860, 0.0029608071, 0.0020844601, 0.0017327637];
cbsLowRange = [ ...
    0.9000158038, 0.4859865995, 0.2784851408, 0.1744873599, 0.1223663567, 0.09624503463, 0.08315238906; ...
    0.9200170608, 0.5108091747, 0.3009405556, 0.193310272, 0.1381116009, 0.1098015455, 0.09528333675; ...
    0.9500196119, 0.5399115786, 0.3246904196, 0.2117400444, 0.1524627811, 0.1213541561, 0.1050279898];
colors = [0.122, 0.467, 0.705; 1.000, 0.498, 0.055; 0.173, 0.627, 0.173];

figure("Name", "Paper Fig. 11 - Published Proposed and CBS-Low", ...
    "NumberTitle", "off", "Color", "w", "Position", [40, 60, 1380, 500]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile; hold on; plotLocations(snrDb, proposedAngle, cbsLowAngle, colors);
xlabel("SNR (dB)"); ylabel("RMSE \theta (deg)"); xlim([-10, 20]);
legend(locationLegend("theta", anglesDeg, "deg"), ...
    "Location", "southoutside", "NumColumns", 3, "FontSize", 8, ...
    "Interpreter", "none"); title("(a)", "FontWeight", "normal");
nexttile; hold on; plotLocations(snrDb, proposedRange, cbsLowRange, colors);
xlabel("SNR (dB)"); ylabel("RMSE r (m)"); xlim([-10, 20]);
legend(locationLegend("r", rangesM, "m"), ...
    "Location", "southoutside", "NumColumns", 3, "FontSize", 8, ...
    "Interpreter", "none"); title("(b)", "FontWeight", "normal");
sgtitle("Fig. 11  Published curves recovered from the target PDF");
savePaperFigure(gcf, outputDir, "fig11_proposed_cbs");

data = table(snrDb.'); data.Properties.VariableNames = {'SNR_dB'};
for index = 1:3
    data.(sprintf('Proposed_Angle_%gdeg', anglesDeg(index))) = proposedAngle(index, :).';
    data.(sprintf('CBS_Low_Angle_%gdeg', anglesDeg(index))) = cbsLowAngle(index, :).';
    data.(sprintf('Proposed_Range_%gm', rangesM(index))) = proposedRange(index, :).';
    data.(sprintf('CBS_Low_Range_%gm', rangesM(index))) = cbsLowRange(index, :).';
end
saveFigureData(outputDir, "fig11_proposed_cbs", data);
end

function makeFigure12(outputDir)
numUsers = [1, 5, 10, 15, 20];
proposedAngle = [0.00069995949, 0.0011999365, 0.0016999164, ...
    0.0019998906, 0.0021998860];
proposedRange = [0.00050005613, 0.00090008715, 0.0016001483, ...
    0.0021001947, 0.0024001994];
cbsLowAngle = [0.01099949483, 0.01499947249, 0.01999923195, ...
    0.02299921974, 0.02499907597];
cbsLowRange = [0.0200011593, 0.05000174185, 0.09000314039, ...
    0.1400034817, 0.2000023033];

figure("Name", "Paper Fig. 12 - Published Proposed and CBS-Low", ...
    "NumberTitle", "off", "Color", "w", "Position", [80, 80, 1080, 430]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile; plotPair(numUsers, proposedAngle, cbsLowAngle);
xlabel("Number of Users (K)"); ylabel("RMSE \theta (deg)");
xlim([1, 20]); xticks(numUsers);
legend(pairLegend(), "Location", "northwest", "Interpreter", "none");
title("(a)", "FontWeight", "normal");
nexttile; plotPair(numUsers, proposedRange, cbsLowRange);
xlabel("Number of Users (K)"); ylabel("RMSE r (m)");
xlim([1, 20]); xticks(numUsers);
legend(pairLegend(), "Location", "northwest", "Interpreter", "none");
title("(b)", "FontWeight", "normal");
sgtitle("Fig. 12  Published curves recovered from the target PDF");
savePaperFigure(gcf, outputDir, "fig12_proposed_cbs");

data = table(numUsers.', proposedAngle.', proposedRange.', ...
    cbsLowAngle.', cbsLowRange.', 'VariableNames', {'Num_Users', ...
    'Proposed_Angle_RMSE_deg', 'Proposed_Range_RMSE_m', ...
    'CBS_Low_Angle_RMSE_deg', 'CBS_Low_Range_RMSE_m'});
saveFigureData(outputDir, "fig12_proposed_cbs", data);
end

function makeFigure13(outputDir)
numAntennas = [64, 128, 192, 256, 384, 512, 640, 768, 896, 1024];
anglesDeg = [10, 50]; rangesM = [10, 50];
proposedAngle = [ ...
    0.0062495752, 0.0029771232, 0.0021233954, 0.0016650221, 0.0012691583, 0.0011092732, 0.0009969757, 0.00094453389, 0.00089606954, 0.00086816776; ...
    0.013034215, 0.0068951923, 0.0050303487, 0.0039600594, 0.0030258980, 0.0025968759, 0.0023161376, 0.0021742916, 0.0020538843, 0.0019744825];
cbsLowAngle = [ ...
    0.06109414499, 0.03473513013, 0.02683804636, 0.02200026902, 0.01743229594, 0.01540148448, 0.01409521245, 0.0134107202, 0.01289259956, 0.01252552456; ...
    0.07576242631, 0.046992721, 0.03782525646, 0.03200020013, 0.02636189283, 0.02384623228, 0.02224287207, 0.02141994044, 0.02085350047, 0.02046314308];
proposedRange = [ ...
    0.0045460326, 0.0026029401, 0.0021272951, 0.0018499735, 0.0016216554, 0.0015619626, 0.0015348607, 0.0015165644, 0.0014982809, 0.0014887748; ...
    0.0082839083, 0.0047047699, 0.0036800939, 0.0030599819, 0.0025464269, 0.0023248224, 0.0022088490, 0.0021718500, 0.0021274520, 0.0020857632];
cbsLowRange = [ ...
    0.356373132, 0.2018918759, 0.1537013279, 0.1249969325, 0.09755605347, 0.0850316355, 0.07738911268, 0.07317532071, 0.07025558089, 0.06810156797; ...
    0.3773279977, 0.2286627426, 0.1801568869, 0.1499971118, 0.1207057831, 0.1071167561, 0.09886314252, 0.09453512628, 0.09163960754, 0.08957633448];
colors = [0.122, 0.467, 0.705; 0.8398, 0.1531, 0.1570];

figure("Name", "Paper Fig. 13 - Published Proposed and CBS-Low", ...
    "NumberTitle", "off", "Color", "w", "Position", [40, 60, 1380, 480]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile; hold on; plotLocations(numAntennas, proposedAngle, cbsLowAngle, colors);
xlabel("Number of antennas (N)"); ylabel("RMSE \theta (deg)");
xlim([64, 1024]); xticks(numAntennas);
legend(locationLegend("theta", anglesDeg, "deg"), ...
    "Location", "southoutside", "NumColumns", 2, "FontSize", 8, ...
    "Interpreter", "none"); title("(a)", "FontWeight", "normal");
nexttile; hold on; plotLocations(numAntennas, proposedRange, cbsLowRange, colors);
xlabel("Number of antennas (N)"); ylabel("RMSE r (m)");
xlim([64, 1024]); xticks(numAntennas);
legend(locationLegend("r", rangesM, "m"), ...
    "Location", "southoutside", "NumColumns", 2, "FontSize", 8, ...
    "Interpreter", "none"); title("(b)", "FontWeight", "normal");
sgtitle("Fig. 13  Published curves recovered from the target PDF");
savePaperFigure(gcf, outputDir, "fig13_proposed_cbs");

data = table(numAntennas.'); data.Properties.VariableNames = {'Num_Antennas'};
for index = 1:2
    data.(sprintf('Proposed_Angle_%gdeg', anglesDeg(index))) = proposedAngle(index, :).';
    data.(sprintf('CBS_Low_Angle_%gdeg', anglesDeg(index))) = cbsLowAngle(index, :).';
    data.(sprintf('Proposed_Range_%gm', rangesM(index))) = proposedRange(index, :).';
    data.(sprintf('CBS_Low_Range_%gm', rangesM(index))) = cbsLowRange(index, :).';
end
saveFigureData(outputDir, "fig13_proposed_cbs", data);
end

function plotPair(x, proposed, cbsLow)
semilogy(x, proposed, "-o", "Color", [0.00, 0.35, 0.85], ...
    "MarkerFaceColor", [0.00, 0.35, 0.85], "LineWidth", 1.6, "MarkerSize", 5);
hold on;
semilogy(x, cbsLow, "-s", "Color", [0.90, 0.10, 0.10], ...
    "MarkerFaceColor", [0.90, 0.10, 0.10], "LineWidth", 1.6, "MarkerSize", 5);
grid on; box on; set(gca, "YScale", "log", "FontSize", 10);
end

function plotLocations(x, proposed, cbsLow, colors)
for index = 1:size(proposed, 1)
    semilogy(x, proposed(index, :), "-o", "Color", colors(index, :), ...
        "MarkerFaceColor", colors(index, :), "LineWidth", 1.5, "MarkerSize", 4.5);
end
for index = 1:size(cbsLow, 1)
    semilogy(x, cbsLow(index, :), "-.s", "Color", colors(index, :), ...
        "MarkerFaceColor", colors(index, :), "LineWidth", 1.5, "MarkerSize", 4.5);
end
grid on; box on; set(gca, "YScale", "log", "FontSize", 10);
end

function labels = pairLegend()
labels = ["Proposed Joint MUSIC (published)", "CBS-Low (published)"];
end

function labels = locationLegend(symbol, values, unit)
labels = strings(1, 2 * numel(values));
for index = 1:numel(values)
    labels(index) = sprintf("Proposed, %s=%g %s", symbol, values(index), unit);
    labels(numel(values) + index) = sprintf( ...
        "CBS-Low, %s=%g %s", symbol, values(index), unit);
end
end

function saveFigureData(outputDir, baseName, data)
writetable(data, fullfile(outputDir, baseName + ".csv"));
source = "Recovered from vector paths embedded in the target IEEE PDF";
cbsHighStatus = "Excluded: CBS-High is absent from target-paper Figs. 10-13";
save(fullfile(outputDir, baseName + ".mat"), "data", "source", "cbsHighStatus");
end

function savePaperFigure(figureHandle, outputDir, baseName)
axesHandles = findall(figureHandle, "Type", "axes");
for index = 1:numel(axesHandles)
    if ~isempty(axesHandles(index).Toolbar)
        axesHandles(index).Toolbar.Visible = "off";
    end
end
exportgraphics(figureHandle, fullfile(outputDir, baseName + ".png"), ...
    "Resolution", 200);
savefig(figureHandle, fullfile(outputDir, baseName + ".fig"));
end

function writeProvenance(outputDir, rootDir)
lines = [
    "Data provenance for corrected Figs. 10-13";
    "";
    "Proposed Joint MUSIC: recovered from target-PDF vector paths.";
    "CBS-Low: recovered from target-PDF vector paths.";
    "Axis calibration uses the Proposed coordinates on each logarithmic axis.";
    "Maximum calibration residual is below 1.4e-8 in log10 units.";
    "Extraction tool: " + fullfile(rootDir, "tools", "extract_published_cbs_curves.py");
    "CBS-High is not shown because it is absent from target-paper Figs. 10-13.";
    "The earlier direct repro_paper2 transfer is invalid as a reproduction: the target paper does not specify the required noise normalization, residual multi-user coupling, or benchmark adaptation, and direct transfer gives wrong Fig. 12/13 trends.";
    ];
fid = fopen(fullfile(outputDir, "PROVENANCE.txt"), "w");
assert(fid >= 0, "Could not create provenance file in %s", outputDir);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", lines);
clear cleanup;
end
