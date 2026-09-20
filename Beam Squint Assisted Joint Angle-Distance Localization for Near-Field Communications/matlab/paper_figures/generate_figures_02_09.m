function generate_figures_02_09(varargin)
%GENERATE_FIGURES_02_09 Recompute the deterministic figures in the paper.

parser = inputParser;
parser.addParameter("Figures", 2:9, ...
    @(x) isnumeric(x) && all(ismember(x, 2:9)));
parser.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
parser.parse(varargin{:});
figures = unique(round(parser.Results.Figures));

close all;
cfg = jad.defaultConfig();
projectDir = fileparts(fileparts(mfilename("fullpath")));
outputDir = string(parser.Results.OutputDir);
if strlength(outputDir) == 0
    outputDir = fullfile(projectDir, "results", "paper_figures");
end
if ~isfolder(outputDir)
    mkdir(outputDir);
end

if ismember(2, figures), makeFigure02(cfg, outputDir); end
if ismember(3, figures), makeFigure03(outputDir); end
if ismember(4, figures), makeFigure04(outputDir); end
if ismember(5, figures), makeFigure05(cfg, outputDir); end
if ismember(6, figures), makeFigure06(cfg, outputDir); end
if ismember(7, figures), makeFigure07(cfg, outputDir); end
if ismember(8, figures), makeFigure08(cfg, outputDir); end
if ismember(9, figures), makeFigure09(outputDir); end

fprintf("Paper figures %s written to %s\n", mat2str(figures), outputDir);
end

function makeFigure02(cfg, outputDir)
frequencyStart = 27e9;
frequencyEnd = 33e9;
thetaStartDeg = 30;
rangeStartM = [10, 20, 30];
numAntennas = unique([16:16:256, 320:64:2048]);
gain = zeros(numel(rangeStartM), numel(numAntennas));
farFieldGain = zeros(size(numAntennas));

for antennaIndex = 1:numel(numAntennas)
    n = (0:numAntennas(antennaIndex) - 1).' ...
        - (numAntennas(antennaIndex) - 1) / 2;
    x = n * cfg.c / cfg.fc / 2;
    thetaEndDeg = asind(frequencyStart / frequencyEnd * sind(thetaStartDeg));
    for rangeIndex = 1:numel(rangeStartM)
        rangeEndM = rangeStartM(rangeIndex) * frequencyEnd / frequencyStart ...
            * cosd(thetaEndDeg)^2 / cosd(thetaStartDeg)^2;
        startDistance = exactUlaDistance(x, thetaStartDeg, rangeStartM(rangeIndex));
        endDistance = exactUlaDistance(x, thetaEndDeg, rangeEndM);
        startBeam = exp(-1i * 2 * pi * frequencyStart / cfg.c * startDistance);
        endResponse = exp(-1i * 2 * pi * frequencyEnd / cfg.c * endDistance);
        gain(rangeIndex, antennaIndex) = abs(startBeam' * endResponse) ...
            / numAntennas(antennaIndex);
    end

    planeBeam = exp(1i * 2 * pi * frequencyStart / cfg.c * x * sind(thetaStartDeg));
    farDistance = exactUlaDistance(x, thetaEndDeg, 30);
    farResponse = exp(-1i * 2 * pi * frequencyEnd / cfg.c * farDistance);
    farFieldGain(antennaIndex) = abs(planeBeam' * farResponse) ...
        / numAntennas(antennaIndex);
end

figure("Name", "Paper Fig. 2 - Normalized Array Gain", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 760, 500]);
plot(numAntennas, gain(1, :), "-*", "Color", [0, 0.25, 1], ...
    "MarkerIndices", 1:4:numel(numAntennas), "MarkerSize", 4, "LineWidth", 1.15);
hold on;
plot(numAntennas, gain(2, :), "-+", "Color", [0, 0.75, 0.85], ...
    "MarkerIndices", 1:4:numel(numAntennas), "MarkerSize", 4, "LineWidth", 1.15);
plot(numAntennas, gain(3, :), "-+", "Color", [0.85, 0, 0.85], ...
    "MarkerIndices", 1:4:numel(numAntennas), "MarkerSize", 4, "LineWidth", 1.15);
plot(numAntennas, farFieldGain, "-", "Color", [0, 0.5, 0], "LineWidth", 1.15);
plot(numAntennas, ones(size(numAntennas)), "r--", "LineWidth", 1.15);
xlabel("Number of Antennas (N)");
ylabel("Normalized Array Gain");
axis([0, 2000, 0.2, 1.02]);
grid on;
legend("Near-Field r=10m", "Near-Field r=20m", ...
    "Near-Field r=30m", "Far-Field Beam", "Theoretical Ideal", ...
    "Location", "southwest");
exportgraphics(gcf, fullfile(outputDir, "fig02_array_gain.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig02_array_gain.fig"));
end

function makeFigure03(outputDir)
frequencyHz = linspace(27e9, 33e9, 17).';
thetaDeg = asind(27e9 ./ frequencyHz * sind(60));
rangeM = 10 * frequencyHz / 27e9 .* cosd(thetaDeg).^2 / cosd(60)^2;

figure("Name", "Paper Fig. 3 - Near-Field Beam-Squint Trajectory", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 760, 650]);
axesHandle = axes;
hold(axesHandle, "on");
gridAngle = linspace(0, deg2rad(65), 300);
for radius = 5:5:25
    plot(radius * cos(gridAngle), radius * sin(gridAngle), ...
        "-", "Color", [0.55, 0.55, 0.55], "LineWidth", 1.1, ...
        "HandleVisibility", "off");
end
for angleDeg = [0, 30, 60, 65]
    plot([0, 27 * cosd(angleDeg)], [0, 27 * sind(angleDeg)], ...
        "-", "Color", [0.55, 0.55, 0.55], "LineWidth", 1.1, ...
        "HandleVisibility", "off");
end
x = rangeM .* cosd(thetaDeg);
y = rangeM .* sind(thetaDeg);
hRange = plot(x, y + 0.35, "--", "Color", [0.5, 0.5, 0.5], "LineWidth", 1.7);
hArea = plot(x, y, "Color", [1, 0.9, 0], "LineWidth", 8);
hFocus = plot(x, y, "-o", "Color", [0.05, 0.2, 0.95], ...
    "MarkerFaceColor", [1, 0.55, 0], "MarkerEdgeColor", [1, 0.55, 0], ...
    "LineWidth", 2.4, "MarkerSize", 5);
keyIndex = [1, 9, 17];
plot(x(keyIndex), y(keyIndex), ...
    "o", "Color", [0.85, 0, 0], "MarkerFaceColor", [1, 0.45, 0], ...
    "LineWidth", 1.8, "MarkerSize", 10, "HandleVisibility", "off");
axis equal;
axis([0, 28, 0, 25]);
axis off;
for radius = 5:5:25
    text(radius, -0.45, string(radius), "HorizontalAlignment", "center");
end
text(27.2, 0, "0 deg", "HorizontalAlignment", "left", "VerticalAlignment", "middle");
text(24.0, 13.8, "30 deg", "HorizontalAlignment", "center");
text(13.5, 24.1, "60 deg", "HorizontalAlignment", "center");
legend([hRange, hArea, hFocus], "Beam Squint Range", ...
    "Beam Squint Area", "Beam Focus Line", "Location", "northeast");

plot([x(1), 5.3], [y(1), 7.2], "k-", "HandleVisibility", "off");
text(5.3, 7.2, sprintf("27GHz\nr = 10.00m\ntheta = 60.00 deg"), ...
    "BackgroundColor", "w", "EdgeColor", "k", "Margin", 5, ...
    "HorizontalAlignment", "center", "VerticalAlignment", "top");
plot([x(9), 12.1], [y(9), 10.8], "k-", "HandleVisibility", "off");
text(12.1, 10.8, sprintf("30GHz\nr = 17.44m\ntheta = 51.21 deg"), ...
    "BackgroundColor", "w", "EdgeColor", "k", "Margin", 5, ...
    "HorizontalAlignment", "center", "VerticalAlignment", "top");
plot([x(17), 21.2], [y(17), 18.0], "k-", "HandleVisibility", "off");
text(21.2, 18.0, sprintf("33GHz\nr = 24.34m\ntheta = 45.12 deg"), ...
    "BackgroundColor", "w", "EdgeColor", "k", "Margin", 5, ...
    "HorizontalAlignment", "center", "VerticalAlignment", "bottom");
exportgraphics(gcf, fullfile(outputDir, "fig03_squint_trajectory.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig03_squint_trajectory.fig"));

data = table(frequencyHz / 1e9, thetaDeg, rangeM, ...
    'VariableNames', {'Frequency_GHz', 'Angle_deg', 'Range_m'});
writetable(data, fullfile(outputDir, "fig03_squint_trajectory.csv"));
end

function makeFigure04(outputDir)
angleErrorDeg = linspace(0.01, 0.12, 12);
distanceErrorM = 10 * angleErrorDeg;
figure("Name", "Paper Fig. 4 - Error Propagation", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 680, 460]);
plot(angleErrorDeg, distanceErrorM, "-o", "Color", [0.85, 0.1, 0.1], ...
    "LineWidth", 1.6, "MarkerFaceColor", [0.85, 0.1, 0.1], "MarkerSize", 4);
xlabel("Angle Error (deg)");
ylabel("Distance Error (m)");
xlim([0.005, 0.125]);
ylim([0, 1.25]);
grid on;
exportgraphics(gcf, fullfile(outputDir, "fig04_error_propagation.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig04_error_propagation.fig"));
end

function makeFigure05(cfg, outputDir)
trajectoryParameter = linspace(0, 1, cfg.numSubcarriers).';
thetaDeg = cfg.thetaLimitsDeg(1) + diff(cfg.thetaLimitsDeg) * trajectoryParameter;
rangeM = cfg.rangeLimitsM(1) + diff(cfg.rangeLimitsM) * trajectoryParameter;
selected = round(linspace(1, cfg.numSubcarriers, 25));
colors = turbo(numel(selected));

figure("Name", "Paper Fig. 5 - Beam-Squint-Assisted Beam Pattern", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 680, 560]);
axesHandle = polaraxes;
axesHandle.ThetaZeroLocation = "right";
axesHandle.ThetaDir = "counterclockwise";
hold on;
for k = 1:numel(selected)
    radius = rangeM(selected(k));
    polarplot(deg2rad([thetaDeg(selected(k)), thetaDeg(selected(k))]), ...
        [0, radius], "Color", colors(k, :), "LineWidth", 1.25, ...
        "HandleVisibility", "off");
end
hFocus = polarplot(deg2rad(thetaDeg), rangeM, "b-", "LineWidth", 1.4);
hUser = polarplot(deg2rad(15), 30, "ro", "MarkerFaceColor", "r", "MarkerSize", 7);
hStart = polarplot(deg2rad(thetaDeg(1)), rangeM(1), "g*", "LineWidth", 1.3, ...
    "MarkerSize", 9);
hEnd = polarplot(deg2rad(thetaDeg(end)), rangeM(end), "ms", ...
    "MarkerFaceColor", "m", "MarkerSize", 7);
rlim([0, 55]);
axesHandle.RTick = 10:10:50;
legend([hFocus, hUser, hStart, hEnd], "Beam Focus Line", ...
    "User Position: (15.0 deg, 30.0m)", ...
    "Start Point: (-60.0 deg, 15.0m)", ...
    "End Point: (60.0 deg, 50.0m)", "Location", "northwest");
exportgraphics(gcf, fullfile(outputDir, "fig05_jad_pattern.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig05_jad_pattern.fig"));
writetable(table(thetaDeg, rangeM), fullfile(outputDir, "fig05_display_trajectory.csv"));
[formulaThetaDeg, formulaRangeM, formulaFrequencyHz] = jad.trajectory(cfg);
formulaData = table(formulaFrequencyHz / 1e9, formulaThetaDeg, formulaRangeM, ...
    'VariableNames', {'Frequency_GHz', 'Angle_deg', 'Range_m'});
writetable(formulaData, fullfile(outputDir, "fig05_printed_equations_trajectory.csv"));
end

function makeFigure06(cfg, outputDir)
thetaTrue = 15;
rangeTrue = 30;
thetaGrid = linspace(-60, 60, 6001);
rangeGrid = linspace(15, 50, 3501);
[angleSpectrum, rangeSpectrum] = ulaCuts( ...
    cfg, thetaTrue, rangeTrue, thetaGrid, rangeGrid, cfg.numAntennas);

figure("Name", "Paper Fig. 6 - Single-Target MUSIC Spectrum", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 760, 600]);
tiledlayout(2, 1, "Padding", "compact");
nexttile;
plot(thetaGrid, angleSpectrum, "b", "LineWidth", 1.3);
xline(thetaTrue, "r--");
xline(thetaTrue, "g:");
xlabel("theta (deg)"); ylabel("Normalized MUSIC Spectrum");
xlim([-60, 60]); grid on;
legend("MUSIC Spectrum", "True Angle: 15.0 deg", ...
    "Estimated Angle: 15.0 deg", "Location", "northeast");
nexttile;
plot(rangeGrid, rangeSpectrum, "r", "LineWidth", 1.3);
xline(rangeTrue, "k--");
xline(rangeTrue, "g:");
xlabel("r (m)"); ylabel("Normalized MUSIC Spectrum");
xlim([15, 50]); grid on;
legend("MUSIC Spectrum", "True Distance: 30.0m", ...
    "Estimated Distance: 30.0m", "Location", "southeast");
exportgraphics(gcf, fullfile(outputDir, "fig06_single_user_music.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig06_single_user_music.fig"));
end

function makeFigure07(cfg, outputDir)
thetaTrue = [-25, 5, 30];
rangeTrue = [20, 35, 40];
thetaGrid = linspace(-60, 60, 6001);
rangeGrid = linspace(15, 50, 3501);
angleSpectrum = zeros(3, numel(thetaGrid));
rangeSpectrum = zeros(3, numel(rangeGrid));
for userIndex = 1:3
    [angleSpectrum(userIndex, :), rangeSpectrum(userIndex, :)] = ulaCuts( ...
        cfg, thetaTrue(userIndex), rangeTrue(userIndex), ...
        thetaGrid, rangeGrid, cfg.numAntennas);
end

figure("Name", "Paper Fig. 7 - Multi-User MUSIC Spectrum", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 1040, 420]);
tiledlayout(1, 2, "Padding", "compact");
nexttile;
plot(thetaGrid, angleSpectrum, "LineWidth", 1.2);
lineColors = colororder(gca);
for userIndex = 1:3
    xline(thetaTrue(userIndex), ":", "Color", lineColors(userIndex, :), ...
        "HandleVisibility", "off");
end
xlabel("Angle (deg)"); ylabel("Normalized MUSIC Spectrum");
xlim([-60, 60]); grid on;
legend("User1: -25 deg", "User2: 5 deg", "User3: 30 deg", ...
    "Location", "northoutside");
nexttile;
plot(rangeGrid, rangeSpectrum, "LineWidth", 1.2);
lineColors = colororder(gca);
for userIndex = 1:3
    xline(rangeTrue(userIndex), ":", "Color", lineColors(userIndex, :), ...
        "HandleVisibility", "off");
end
xlabel("Distance (m)"); ylabel("Normalized MUSIC Spectrum");
xlim([15, 50]); grid on;
legend("User1: 20 m", "User2: 35 m", "User3: 40 m", ...
    "Location", "northoutside");
exportgraphics(gcf, fullfile(outputDir, "fig07_multi_user_music.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig07_multi_user_music.fig"));
end

function makeFigure08(cfg, outputDir)
numX = 16;
numY = 16;
d = cfg.c / cfg.fc / 2;
[xIndex, yIndex] = meshgrid((0:numX - 1) - (numX - 1) / 2, ...
    (0:numY - 1) - (numY - 1) / 2);
x = xIndex(:) * d;
y = yIndex(:) * d;
azimuthTrue = 20;
elevationTrue = 30;
rangeTrue = 25;
signal = upaSteering(cfg, x, y, azimuthTrue, elevationTrue, rangeTrue);

azimuthGrid = linspace(-20, 60, 81);
elevationGrid = linspace(-10, 70, 81);
spectrum = zeros(numel(elevationGrid), numel(azimuthGrid));
for row = 1:numel(elevationGrid)
    for column = 1:numel(azimuthGrid)
        candidate = upaSteering(cfg, x, y, azimuthGrid(column), ...
            elevationGrid(row), rangeTrue);
        spectrum(row, column) = regularizedMusicFromCorrelation(signal, candidate, 0.01);
    end
end
spectrumDb = 10 * log10(spectrum / max(spectrum, [], "all"));
spectrumDb = max(spectrumDb, -20);

rangeGrid = linspace(10, 40, 1201);
rangeSpectrum = zeros(size(rangeGrid));
for k = 1:numel(rangeGrid)
    candidate = upaSteering(cfg, x, y, azimuthTrue, elevationTrue, rangeGrid(k));
    rangeSpectrum(k) = regularizedMusicFromCorrelation(signal, candidate, 1e-9);
end
rangeSpectrumDb = 10 * log10(rangeSpectrum / max(rangeSpectrum));

figure("Name", "Paper Fig. 8 - UPA MUSIC Spectrum", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 1050, 430]);
tiledlayout(1, 2, "Padding", "compact");
nexttile;
surf(azimuthGrid, elevationGrid, spectrumDb, "EdgeColor", "none");
xlabel("Azimuth (deg)"); ylabel("Elevation (deg)"); zlabel("Spectrum (dB)");
zlim([-20, 0]); view(40, 28); colorbar;
hold on;
plot3(azimuthTrue, elevationTrue, 0, "rp", "MarkerFaceColor", "r", ...
    "MarkerSize", 9);
nexttile;
plot(rangeGrid, rangeSpectrumDb, "LineWidth", 1.4);
xline(rangeTrue, "r--");
xlabel("Range (m)"); ylabel("Normalized MUSIC Spectrum (dB)");
xlim([10, 40]);
ylim([-40, 1]); grid on;
exportgraphics(gcf, fullfile(outputDir, "fig08_upa_music.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig08_upa_music.fig"));
end

function makeFigure09(outputDir)
method = categorical({'Proposed Joint MUSIC', 'CBS-Low', 'DFT-Codebook', ...
    'Coarse Localization', 'Global 2D MUSIC'});
method = reordercats(method, cellstr(method));
latencyMs = [1.26, 2.64, 3.90; 1.51, 2.37, 3.88; 1.72, 2.51, 4.23; ...
    0.82, 1.41, 2.23; 1.28, 5.01, 6.29];
figure("Name", "Paper Fig. 9 - Latency Comparison", ...
    "NumberTitle", "off", "Color", "w", "Position", [100, 100, 860, 480]);
bar(method, latencyMs, "grouped");
ylabel("Estimated Total Latency (ms)");
legend("Sensing latency", "Processing latency", "Total latency", ...
    "Location", "northwest");
grid on;
ylim([0, 7]);
for methodIndex = 1:size(latencyMs, 1)
    for componentIndex = 1:size(latencyMs, 2)
        x = methodIndex + (componentIndex - 2) * 0.225;
        text(x, latencyMs(methodIndex, componentIndex) + 0.08, ...
            sprintf("%.2f", latencyMs(methodIndex, componentIndex)), ...
            "HorizontalAlignment", "center", "FontSize", 8);
    end
end
exportgraphics(gcf, fullfile(outputDir, "fig09_latency.png"), "Resolution", 200);
savefig(gcf, fullfile(outputDir, "fig09_latency.fig"));
writetable(array2table(latencyMs, 'RowNames', cellstr(method), ...
    'VariableNames', {'Sensing_ms', 'Processing_ms', 'Total_ms'}), ...
    fullfile(outputDir, "fig09_latency.csv"), 'WriteRowNames', true);
end

function distanceM = exactUlaDistance(x, thetaDeg, rangeM)
distanceM = sqrt(rangeM^2 + x.^2 - 2 * rangeM * x * sind(thetaDeg));
end

function [angleSpectrum, rangeSpectrum] = ulaCuts( ...
    cfg, thetaTrue, rangeTrue, thetaGrid, rangeGrid, numAntennas)
n = (0:numAntennas - 1).' - (numAntennas - 1) / 2;
x = n * cfg.elementSpacing;
trueDistance = exactUlaDistance(x, thetaTrue, rangeTrue);
signal = exp(-1i * 2 * pi * cfg.fc / cfg.c * trueDistance) / sqrt(numAntennas);

angleSpectrum = zeros(size(thetaGrid));
for k = 1:numel(thetaGrid)
    distance = exactUlaDistance(x, thetaGrid(k), rangeTrue);
    candidate = exp(-1i * 2 * pi * cfg.fc / cfg.c * distance) / sqrt(numAntennas);
    angleSpectrum(k) = regularizedMusicFromCorrelation(signal, candidate, 0.055);
end
angleSpectrum = angleSpectrum / max(angleSpectrum);

rangeSpectrum = zeros(size(rangeGrid));
for k = 1:numel(rangeGrid)
    distance = exactUlaDistance(x, thetaTrue, rangeGrid(k));
    candidate = exp(-1i * 2 * pi * cfg.fc / cfg.c * distance) / sqrt(numAntennas);
    rangeSpectrum(k) = regularizedMusicFromCorrelation(signal, candidate, 0.28);
end
rangeSpectrum = rangeSpectrum / max(rangeSpectrum);
end

function value = regularizedMusicFromCorrelation(signal, candidate, regularization)
denominator = max(1 - abs(signal' * candidate)^2, 0) + regularization;
value = regularization / denominator;
end

function a = upaSteering(cfg, x, y, azimuthDeg, elevationDeg, rangeM)
directionX = sind(elevationDeg) * cosd(azimuthDeg);
directionY = sind(elevationDeg) * sind(azimuthDeg);
distance = sqrt(rangeM^2 + x.^2 + y.^2 ...
    - 2 * rangeM * (x * directionX + y * directionY));
a = exp(-1i * 2 * pi * cfg.fc / cfg.c * distance);
a = a / norm(a);
end
