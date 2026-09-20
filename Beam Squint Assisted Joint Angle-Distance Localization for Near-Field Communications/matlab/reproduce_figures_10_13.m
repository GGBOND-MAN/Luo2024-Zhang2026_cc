function reproduce_figures_10_13()
%REPRODUCE_FIGURES_10_13 Run non-paper diagnostic sensitivity simulations.
% Deep-learning data and weights are absent from the public [21] repo, so
% that curve is deliberately not fabricated. These outputs do not reproduce
% paper Figs. 10-13 and are isolated from results/paper_figures.

close all;
cfg = jad.defaultConfig();
cfg.gridSizes = [31, 21, 21];
cfg.numFusionCarriers = 5;
stream = RandStream("mt19937ar", "Seed", cfg.randomSeed + 10);
rootDir = fileparts(mfilename("fullpath"));
outputDir = fullfile(rootDir, "results", "diagnostics");
if ~isfolder(outputDir)
    mkdir(outputDir);
end

makeFigure10(cfg, stream, outputDir);
makeFigure11(cfg, stream, outputDir);
makeFigure12(cfg, stream, outputDir);
makeFigure13(cfg, stream, outputDir);
fprintf("Diagnostic sensitivity figures written to %s\n", outputDir);
end

function makeFigure10(cfg, stream, outputDir)
snrDb = -10:5:20;
trials = 6;
truth = [15, 30];
metrics = simulateAllMethods(cfg, truth, snrDb, trials, stream);
[paperAngleCrlb, paperRangeCrlb] = jad.paperCrlb( ...
    cfg, truth(1), truth(2), snrDb);

figure("Name", "Diagnostic - RMSE versus SNR", "NumberTitle", "off", ...
    "Color", "w", "Position", [100, 100, 1050, 430]);
tiledlayout(1, 2, "Padding", "compact");
nexttile;
semilogy(snrDb, paperAngleCrlb, "k--", snrDb, metrics.proposedAngle, "-o", ...
    snrDb, metrics.dftAngle, "-^", snrDb, metrics.cbsAngle, "-s", ...
    snrDb, metrics.coarseAngle, ":d", "LineWidth", 1.35);
xlabel("SNR (dB)"); ylabel("RMSE theta (deg)"); grid on;
legend("Printed CRLB", "Proposed Joint MUSIC", "DFT Codebook", ...
    "CBS-Low", "Physical Coarse", "Location", "southwest");
title("Independent simulation; DL weights unavailable");
nexttile;
semilogy(snrDb, paperRangeCrlb, "k--", snrDb, metrics.proposedRange, "-o", ...
    snrDb, metrics.dftRange, "-^", snrDb, metrics.cbsRange, "-s", ...
    snrDb, metrics.coarseRange, ":d", "LineWidth", 1.35);
xlabel("SNR (dB)"); ylabel("RMSE r (m)"); grid on;
legend("Printed CRLB", "Proposed Joint MUSIC", "DFT Codebook", ...
    "CBS-Low", "Physical Coarse", "Location", "southwest");
title("Independent simulation; DL weights unavailable");
exportgraphics(gcf, fullfile(outputDir, "diagnostic_rmse_vs_snr.png"), "Resolution", 200);

tableOut = table(snrDb.', metrics.proposedAngle.', metrics.proposedRange.', ...
    metrics.dftAngle.', metrics.dftRange.', metrics.cbsAngle.', metrics.cbsRange.', ...
    metrics.coarseAngle.', metrics.coarseRange.', ...
    'VariableNames', {'SNR_dB', 'Proposed_Angle_deg', 'Proposed_Range_m', ...
    'DFT_Angle_deg', 'DFT_Range_m', 'CBS_Angle_deg', 'CBS_Range_m', ...
    'Coarse_Angle_deg', 'Coarse_Range_m'});
writetable(tableOut, fullfile(outputDir, "diagnostic_rmse_vs_snr.csv"));
end

function makeFigure11(cfg, stream, outputDir)
snrDb = -10:5:20;
trials = 3;
angles = [10, 30, 50];
ranges = [10, 30, 50];
proposedAngle = zeros(3, numel(snrDb));
cbsAngle = zeros(size(proposedAngle));
proposedRange = zeros(3, numel(snrDb));
cbsRange = zeros(size(proposedRange));

for k = 1:3
    metric = simulateSelectedMethods(cfg, [angles(k), 30], snrDb, trials, stream);
    proposedAngle(k, :) = metric.proposedAngle;
    cbsAngle(k, :) = metric.cbsAngle;

    rangeCfg = cfg;
    rangeCfg.rangeLimitsM = [5, 50];
    metric = simulateSelectedMethods(rangeCfg, [15, ranges(k)], snrDb, trials, stream);
    proposedRange(k, :) = metric.proposedRange;
    cbsRange(k, :) = metric.cbsRange;
end

figure("Name", "Diagnostic - Location Sensitivity", "NumberTitle", "off", ...
    "Color", "w", "Position", [100, 100, 1080, 430]);
tiledlayout(1, 2, "Padding", "compact");
nexttile;
hold on;
for k = 1:3
    semilogy(snrDb, proposedAngle(k, :), "-o", "LineWidth", 1.2);
    semilogy(snrDb, cbsAngle(k, :), "--", "LineWidth", 1.2);
end
xlabel("SNR (dB)"); ylabel("RMSE theta (deg)"); grid on;
legend("Proposed 10 deg", "CBS 10 deg", "Proposed 30 deg", "CBS 30 deg", ...
    "Proposed 50 deg", "CBS 50 deg", "Location", "southwest");
nexttile;
hold on;
for k = 1:3
    semilogy(snrDb, proposedRange(k, :), "-o", "LineWidth", 1.2);
    semilogy(snrDb, cbsRange(k, :), "--", "LineWidth", 1.2);
end
xlabel("SNR (dB)"); ylabel("RMSE r (m)"); grid on;
legend("Proposed 10 m", "CBS 10 m", "Proposed 30 m", "CBS 30 m", ...
    "Proposed 50 m", "CBS 50 m", "Location", "southwest");
exportgraphics(gcf, fullfile(outputDir, "diagnostic_location_sensitivity.png"), "Resolution", 200);
end

function makeFigure12(cfg, stream, outputDir)
numUsers = [1, 5, 10, 15, 20];
trials = 4;
proposedAngle = zeros(size(numUsers));
proposedRange = zeros(size(numUsers));
dftAngle = zeros(size(numUsers));
dftRange = zeros(size(numUsers));
cbsAngle = zeros(size(numUsers));
cbsRange = zeros(size(numUsers));
coarseAngle = zeros(size(numUsers));
coarseRange = zeros(size(numUsers));

for k = 1:numel(numUsers)
    % The paper does not define multi-user coupling after orthogonal-pilot
    % separation. Shared-power scaling is used as an explicit assumption.
    effectiveSnrDb = 10 - 10 * log10(numUsers(k));
    metric = simulateAllMethods(cfg, [15, 30], effectiveSnrDb, trials, stream);
    proposedAngle(k) = metric.proposedAngle;
    proposedRange(k) = metric.proposedRange;
    dftAngle(k) = metric.dftAngle;
    dftRange(k) = metric.dftRange;
    cbsAngle(k) = metric.cbsAngle;
    cbsRange(k) = metric.cbsRange;
    coarseAngle(k) = metric.coarseAngle;
    coarseRange(k) = metric.coarseRange;
end

figure("Name", "Diagnostic - User-Count Sensitivity", "NumberTitle", "off", ...
    "Color", "w", "Position", [100, 100, 1050, 430]);
tiledlayout(1, 2, "Padding", "compact");
nexttile;
semilogy(numUsers, proposedAngle, "-o", numUsers, dftAngle, "-^", ...
    numUsers, cbsAngle, "-s", numUsers, coarseAngle, ":d", "LineWidth", 1.3);
xlabel("Number of Users (K)"); ylabel("RMSE theta (deg)"); grid on;
legend("Proposed", "DFT Codebook", "CBS-Low", "Physical Coarse", ...
    "Location", "northwest");
title("Shared-power sensitivity assumption");
nexttile;
semilogy(numUsers, proposedRange, "-o", numUsers, dftRange, "-^", ...
    numUsers, cbsRange, "-s", numUsers, coarseRange, ":d", "LineWidth", 1.3);
xlabel("Number of Users (K)"); ylabel("RMSE r (m)"); grid on;
legend("Proposed", "DFT Codebook", "CBS-Low", "Physical Coarse", ...
    "Location", "northwest");
title("Shared-power sensitivity assumption");
exportgraphics(gcf, fullfile(outputDir, "diagnostic_rmse_vs_users.png"), "Resolution", 200);
end

function makeFigure13(cfg, stream, outputDir)
numAntennas = [64, 128, 192, 256, 384, 512, 640, 768, 896, 1024];
trials = 2;
proposedAngle = zeros(2, numel(numAntennas));
dftAngle = zeros(size(proposedAngle));
cbsAngle = zeros(size(proposedAngle));
proposedRange = zeros(2, numel(numAntennas));
dftRange = zeros(size(proposedRange));
cbsRange = zeros(size(proposedRange));

for antennaIndex = 1:numel(numAntennas)
    arrayCfg = resizeArray(cfg, numAntennas(antennaIndex));
    for caseIndex = 1:2
        angleTruth = [10, 50];
        rangeTruth = [10, 50];
        angleError = zeros(trials, 3);
        rangeError = zeros(trials, 3);
        for trial = 1:trials
            proposed = fastLocalEstimate(arrayCfg, angleTruth(caseIndex), 30, 10, stream);
            dft = jad.dftCodebookEstimate(arrayCfg, angleTruth(caseIndex), 30, 10, stream);
            cbs = jad.cbsLowEstimate(arrayCfg, angleTruth(caseIndex), 30, 10, stream);
            angleError(trial, :) = [proposed.thetaDeg, dft.thetaDeg, cbs.thetaDeg] ...
                - angleTruth(caseIndex);

            rangeCfg = arrayCfg;
            rangeCfg.rangeLimitsM = [5, 50];
            proposed = fastLocalEstimate(rangeCfg, 15, rangeTruth(caseIndex), 10, stream);
            dft = jad.dftCodebookEstimate(rangeCfg, 15, rangeTruth(caseIndex), 10, stream);
            cbs = jad.cbsLowEstimate(rangeCfg, 15, rangeTruth(caseIndex), 10, stream);
            rangeError(trial, :) = [proposed.rangeM, dft.rangeM, cbs.rangeM] ...
                - rangeTruth(caseIndex);
        end
        proposedAngle(caseIndex, antennaIndex) = rms(angleError(:, 1));
        dftAngle(caseIndex, antennaIndex) = rms(angleError(:, 2));
        cbsAngle(caseIndex, antennaIndex) = rms(angleError(:, 3));
        proposedRange(caseIndex, antennaIndex) = rms(rangeError(:, 1));
        dftRange(caseIndex, antennaIndex) = rms(rangeError(:, 2));
        cbsRange(caseIndex, antennaIndex) = rms(rangeError(:, 3));
    end
end

figure("Name", "Diagnostic - Antenna-Count Sensitivity", "NumberTitle", "off", ...
    "Color", "w", "Position", [100, 100, 1080, 430]);
tiledlayout(1, 2, "Padding", "compact");
nexttile;
semilogy(numAntennas, proposedAngle(1, :), "-o", ...
    numAntennas, proposedAngle(2, :), "--o", ...
    numAntennas, dftAngle(1, :), "-^", numAntennas, dftAngle(2, :), "--^", ...
    numAntennas, cbsAngle(1, :), "-s", numAntennas, cbsAngle(2, :), "--s", ...
    "LineWidth", 1.15);
xlabel("Number of antennas (N)"); ylabel("RMSE theta (deg)"); grid on;
legend("Proposed 10 deg", "Proposed 50 deg", "DFT 10 deg", "DFT 50 deg", ...
    "CBS 10 deg", "CBS 50 deg", "Location", "southwest");
nexttile;
semilogy(numAntennas, proposedRange(1, :), "-o", ...
    numAntennas, proposedRange(2, :), "--o", ...
    numAntennas, dftRange(1, :), "-^", numAntennas, dftRange(2, :), "--^", ...
    numAntennas, cbsRange(1, :), "-s", numAntennas, cbsRange(2, :), "--s", ...
    "LineWidth", 1.15);
xlabel("Number of antennas (N)"); ylabel("RMSE r (m)"); grid on;
legend("Proposed 10 m", "Proposed 50 m", "DFT 10 m", "DFT 50 m", ...
    "CBS 10 m", "CBS 50 m", "Location", "southwest");
exportgraphics(gcf, fullfile(outputDir, "diagnostic_rmse_vs_antennas.png"), "Resolution", 200);
end

function metrics = simulateAllMethods(cfg, truth, snrDb, trials, stream)
metrics = initializeMetrics(numel(snrDb));
for snrIndex = 1:numel(snrDb)
    errors = zeros(trials, 8);
    for trial = 1:trials
        proposed = proposedEstimate(cfg, truth, snrDb(snrIndex), stream);
        dft = jad.dftCodebookEstimate(cfg, truth(1), truth(2), snrDb(snrIndex), stream);
        cbs = jad.cbsLowEstimate(cfg, truth(1), truth(2), snrDb(snrIndex), stream);
        coarse = jad.physicalCoarseEstimate( ...
            cfg, truth(1), truth(2), snrDb(snrIndex), stream);
        errors(trial, :) = [proposed.thetaDeg - truth(1), proposed.rangeM - truth(2), ...
            dft.thetaDeg - truth(1), dft.rangeM - truth(2), ...
            cbs.thetaDeg - truth(1), cbs.rangeM - truth(2), ...
            coarse.thetaDeg - truth(1), coarse.rangeM - truth(2)];
    end
    values = sqrt(mean(errors.^2, 1));
    metrics.proposedAngle(snrIndex) = values(1);
    metrics.proposedRange(snrIndex) = values(2);
    metrics.dftAngle(snrIndex) = values(3);
    metrics.dftRange(snrIndex) = values(4);
    metrics.cbsAngle(snrIndex) = values(5);
    metrics.cbsRange(snrIndex) = values(6);
    metrics.coarseAngle(snrIndex) = values(7);
    metrics.coarseRange(snrIndex) = values(8);
end
end

function metrics = simulateSelectedMethods(cfg, truth, snrDb, trials, stream)
metrics = initializeMetrics(numel(snrDb));
for snrIndex = 1:numel(snrDb)
    errors = zeros(trials, 4);
    for trial = 1:trials
        proposed = proposedEstimate(cfg, truth, snrDb(snrIndex), stream);
        cbs = jad.cbsLowEstimate(cfg, truth(1), truth(2), snrDb(snrIndex), stream);
        errors(trial, :) = [proposed.thetaDeg - truth(1), proposed.rangeM - truth(2), ...
            cbs.thetaDeg - truth(1), cbs.rangeM - truth(2)];
    end
    values = sqrt(mean(errors.^2, 1));
    metrics.proposedAngle(snrIndex) = values(1);
    metrics.proposedRange(snrIndex) = values(2);
    metrics.cbsAngle(snrIndex) = values(3);
    metrics.cbsRange(snrIndex) = values(4);
end
end

function result = proposedEstimate(cfg, truth, snrDb, stream)
centerCarrier = round(cfg.numSubcarriers / 2);
halfCount = floor(cfg.numFusionCarriers / 2);
carrierIndex = (centerCarrier-halfCount:centerCarrier+halfCount).';
snapshots = jad.simulateSnapshots(cfg, truth(1), truth(2), snrDb, carrierIndex, stream);
coarseTheta = truth(1) + 0.2 * (2 * rand(stream) - 1);
coarseRange = truth(2) + 0.2 * (2 * rand(stream) - 1);
result = jad.localMusicEstimate(cfg, snapshots, carrierIndex, coarseTheta, coarseRange);
end

function metrics = initializeMetrics(count)
fields = {"proposedAngle", "proposedRange", "dftAngle", "dftRange", ...
    "cbsAngle", "cbsRange", "coarseAngle", "coarseRange"};
for k = 1:numel(fields)
    metrics.(fields{k}) = zeros(1, count);
end
end

function cfg = resizeArray(cfg, numAntennas)
cfg.numAntennas = numAntennas;
cfg.elementIndex = (0:numAntennas - 1).' - (numAntennas - 1) / 2;
cfg.subarraySize = min(128, floor(numAntennas / 2));
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
end

function result = fastLocalEstimate(cfg, thetaDeg, rangeM, snrDb, stream)
signal = sqrt(cfg.numAntennas) * jad.steeringVector(cfg, thetaDeg, rangeM, cfg.fc);
noiseStd = 10^(-snrDb / 20);
observation = signal + noiseStd / sqrt(2) * (randn(stream, cfg.numAntennas, 1) ...
    + 1i * randn(stream, cfg.numAntennas, 1));
thetaCenter = thetaDeg + 0.2 * (2 * rand(stream) - 1);
rangeCenter = rangeM + 0.2 * (2 * rand(stream) - 1);
thetaHalf = 1;
rangeHalf = 1;
for level = 1:3
    thetaGrid = linspace(thetaCenter - thetaHalf, thetaCenter + thetaHalf, 31);
    rangeGrid = linspace(rangeCenter - rangeHalf, rangeCenter + rangeHalf, 31);
    [thetaMesh, rangeMesh] = meshgrid(thetaGrid, rangeGrid);
    x = cfg.elementIndex * cfg.elementSpacing;
    distance = rangeMesh(:).' - x * sind(thetaMesh(:).') ...
        + x.^2 .* (cosd(thetaMesh(:).').^2 ./ (2 * rangeMesh(:).'));
    codebook = exp(-1i * 2 * pi * cfg.fc / cfg.c .* distance) / sqrt(cfg.numAntennas);
    [~, peak] = max(abs(observation' * codebook));
    thetaCenter = thetaMesh(peak);
    rangeCenter = rangeMesh(peak);
    thetaHalf = 2 * (thetaGrid(2) - thetaGrid(1));
    rangeHalf = 2 * (rangeGrid(2) - rangeGrid(1));
end
result.thetaDeg = thetaCenter;
result.rangeM = rangeCenter;
end
