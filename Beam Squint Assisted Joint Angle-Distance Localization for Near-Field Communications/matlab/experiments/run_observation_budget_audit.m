function run_observation_budget_audit
%RUN_OBSERVATION_BUDGET_AUDIT Compare acquisition and energy assumptions.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
numSelectedCarriers = cfg.numFusionCarriers;
numScalarScanSamples = cfg.numSubcarriers;
numSelectedArraySamples = cfg.numAntennas * numSelectedCarriers;
numFullArraySamples = cfg.numAntennas * cfg.numSubcarriers;
numCbsLowSymbols = 6;

architecture = [ ...
    "Zhang literal one-scan claim"; ...
    "Zhang feasible fully digital"; ...
    "Zhang feasible one-RF switching"; ...
    "Current split-data simulation"; ...
    "Luo CBS-Low reimplementation"];
rfChains = [1; cfg.numAntennas; 1; NaN; 1];
trainingSymbols = [1; 1; cfg.numAntennas; NaN; numCbsLowSymbols];
rawAdcComplexSamples = [numScalarScanSamples; numFullArraySamples; ...
    numFullArraySamples; numScalarScanSamples + numSelectedArraySamples; ...
    numCbsLowSymbols * numScalarScanSamples];
scalarSpectrumSamplesUsed = [numScalarScanSamples; numScalarScanSamples; ...
    numScalarScanSamples; numScalarScanSamples; ...
    numCbsLowSymbols * numScalarScanSamples];
selectedArraySamplesUsed = [numSelectedArraySamples; ...
    numSelectedArraySamples; numSelectedArraySamples; ...
    numSelectedArraySamples; 0];
arraySnapshotPhysicallyAvailable = [false; true; true; false; false];
relativeTransmitEnergyAtFixedSymbolPower = [1; 1; cfg.numAntennas; ...
    NaN; numCbsLowSymbols];
perSymbolEnergyAtFixedTotal = 1 ...
    ./ relativeTransmitEnergyAtFixedSymbolPower;
perMeasurementSnrPenaltyDbAtFixedTotal = 10 ...
    * log10(perSymbolEnergyAtFixedTotal);

budget = table(architecture, rfChains, trainingSymbols, ...
    rawAdcComplexSamples, scalarSpectrumSamplesUsed, ...
    selectedArraySamplesUsed, arraySnapshotPhysicallyAvailable, ...
    relativeTransmitEnergyAtFixedSymbolPower, perSymbolEnergyAtFixedTotal, ...
    perMeasurementSnrPenaltyDbAtFixedTotal);

numAntennas = [64; 128; 256; 512; 1024];
oneRfTrainingSymbols = numAntennas;
fullyDigitalRfChains = numAntennas;
rawSamplesPerWidebandScan = numAntennas * cfg.numSubcarriers;
snrPenaltyDbAtFixedTotal = -10 * log10(numAntennas);
scaling = table(numAntennas, oneRfTrainingSymbols, fullyDigitalRfChains, ...
    rawSamplesPerWidebandScan, snrPenaltyDbAtFixedTotal);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round3");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(budget, fullfile(outputFolder, "observation_budget.csv"));
writetable(scaling, fullfile(outputFolder, "observation_budget_scaling.csv"));
save(fullfile(outputFolder, "observation_budget.mat"), ...
    "cfg", "numSelectedCarriers", "budget", "scaling");

figureHandle = figure(Color="w", Position=[100, 100, 1060, 410]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
loglog(numAntennas, oneRfTrainingSymbols, "-o", ...
    numAntennas, fullyDigitalRfChains, "-s", ...
    LineWidth=1.5, MarkerSize=6);
grid on;
xlabel("Number of antennas"); ylabel("Required hardware/time resource");
legend("One-RF training symbols", "One-scan RF chains", ...
    Location="northwest");
title("Array-vector acquisition tradeoff");
nexttile;
semilogx(numAntennas, snrPenaltyDbAtFixedTotal, "-o", ...
    LineWidth=1.5, MarkerSize=6);
grid on;
xlabel("Number of antennas");
ylabel("Per-symbol SNR penalty (dB)");
title("One-RF switching at fixed total energy");
title(layout, "Observation budget required by local MUSIC");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "observation_budget.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "observation_budget.fig"));
close(figureHandle);

disp(budget);
disp(scaling);
end
