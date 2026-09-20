function run_frequency_selective_gain
%RUN_FREQUENCY_SELECTIVE_GAIN Test common and structured gain assumptions.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
bank = fsjad.prepareCandidateBank(cfg, (-60:5:60).', (15:2.5:50).', scan);
powerBank = abs(bank.response).^2;
powerEnergy = sum(powerBank.^2, 1).';
frequencyCoordinate = linspace(-1, 1, cfg.numSubcarriers).';
commonBasis = ones(cfg.numSubcarriers, 1);
linearBasis = [commonBasis, frequencyCoordinate];
linearCoefficient = [1; 0.3 * exp(1i * 0.7)];

location = ["Weak EFIM"; "Strong EFIM"; "Known counterexample"; ...
    "Left boundary"; "Right boundary"; "Interior"];
truthThetaDeg = [0; -55; 15; -60; 60; 30];
truthRangeM = [15; 22.5; 30; 15; 50; 40];
snrDbValues = [0, 10, 20];
gainScenarioNames = ["Common"; "Linear smooth"; "Independent phase"];
methodNames = ["Peak index"; "Full power spectrum"; ...
    "Common-gain complex"; "Linear-gain complex"];
numTrials = 100;
numMethods = numel(methodNames);
numRows = numMethods * numel(location) * numel(snrDbValues) ...
    * numel(gainScenarioNames);

method = strings(numRows, 1);
locationColumn = strings(numRows, 1);
gainScenario = strings(numRows, 1);
snrDb = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
captureRate = zeros(numRows, 1);
rowIndex = 0;
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 151);

for locationIndex = 1:numel(location)
    truthIndex = find(bank.thetaDeg == truthThetaDeg(locationIndex) ...
        & bank.rangeM == truthRangeM(locationIndex), 1);
    truthResponse = bank.response(:, truthIndex);

    for scenarioIndex = 1:numel(gainScenarioNames)
        for snrIndex = 1:numel(snrDbValues)
            switch gainScenarioNames(scenarioIndex)
                case "Common"
                    gain = ones(cfg.numSubcarriers, numTrials);
                case "Linear smooth"
                    gain = repmat(linearBasis * linearCoefficient, 1, numTrials);
                case "Independent phase"
                    gain = exp(1i * 2 * pi * rand( ...
                        stream, cfg.numSubcarriers, numTrials));
            end
            commonPhase = 2 * pi * rand(stream, 1, numTrials);
            signal = truthResponse .* gain .* exp(1i * commonPhase);
            signalPower = mean(abs(signal).^2, 1);
            noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
            noise = sqrt(noiseVariance / 2) .* ( ...
                randn(stream, cfg.numSubcarriers, numTrials) ...
                + 1i * randn(stream, cfg.numSubcarriers, numTrials));
            observation = signal + noise;

            [~, peakIndex] = max(abs(observation).^2, [], 1);
            peakThetaDeg = scan.focusThetaDeg(peakIndex);
            peakRangeM = scan.focusRangeM(peakIndex);

            centeredPower = abs(observation).^2 - noiseVariance;
            powerCorrelation = real(powerBank' * centeredPower);
            powerScore = max(powerCorrelation, 0).^2 ./ powerEnergy;
            [~, powerIndex] = max(powerScore, [], 1);
            powerThetaDeg = bank.thetaDeg(powerIndex);
            powerRangeM = bank.rangeM(powerIndex);

            commonScore = fsjad.structuredProfileScore( ...
                bank.response, observation, commonBasis);
            [~, commonIndex] = max(commonScore, [], 1);
            commonThetaDeg = bank.thetaDeg(commonIndex);
            commonRangeM = bank.rangeM(commonIndex);

            linearScore = fsjad.structuredProfileScore( ...
                bank.response, observation, linearBasis);
            [~, linearIndex] = max(linearScore, [], 1);
            linearThetaDeg = bank.thetaDeg(linearIndex);
            linearRangeM = bank.rangeM(linearIndex);

            estimateThetaDeg = [peakThetaDeg(:).'; powerThetaDeg(:).'; ...
                commonThetaDeg(:).'; linearThetaDeg(:).'];
            estimateRangeM = [peakRangeM(:).'; powerRangeM(:).'; ...
                commonRangeM(:).'; linearRangeM(:).'];
            angleError = estimateThetaDeg - truthThetaDeg(locationIndex);
            rangeError = estimateRangeM - truthRangeM(locationIndex);
            captured = abs(angleError) <= 1 & abs(rangeError) <= 1;

            rows = rowIndex + (1:numMethods);
            method(rows) = methodNames;
            locationColumn(rows) = location(locationIndex);
            gainScenario(rows) = gainScenarioNames(scenarioIndex);
            snrDb(rows) = snrDbValues(snrIndex);
            angleRmseDeg(rows) = sqrt(mean(angleError.^2, 2));
            rangeRmseM(rows) = sqrt(mean(rangeError.^2, 2));
            captureRate(rows) = mean(captured, 2);
            rowIndex = rowIndex + numMethods;
        end
    end
end

details = table(method, locationColumn, gainScenario, snrDb, ...
    angleRmseDeg, rangeRmseM, captureRate);
summary = groupsummary(details, ["method", "gainScenario", "snrDb"], ...
    "mean", ["angleRmseDeg", "rangeRmseM", "captureRate"]);

representativeThetaDeg = 15;
representativeRangeM = 30;
[representativeQ, representativeDerivative] = ...
    fsjad.exactSpectralResponse(cfg, deg2rad(representativeThetaDeg), ...
    representativeRangeM, scan);
commonInformation = fsjad.projectedEfim(representativeQ, ...
    representativeDerivative, 1, 1, representativeQ);
linearGain = linearBasis * linearCoefficient;
linearNuisance = representativeQ .* linearBasis;
linearInformation = fsjad.projectedEfim(representativeQ, ...
    representativeDerivative, linearGain, 1, linearNuisance);
parameterScale = diag([deg2rad(1), 1]);
commonInformation = parameterScale.' * commonInformation * parameterScale;
linearInformation = parameterScale.' * linearInformation * parameterScale;
informationSummary = table( ...
    ["Common matched"; "Linear matched"; "Independent oracle"], ...
    [min(eig(commonInformation)); min(eig(linearInformation)); 0], ...
    [det(commonInformation); det(linearInformation); 0], ...
    VariableNames=["GainModel", "LambdaMin", "Determinant"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round2");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, "frequency_gain_points.csv"));
writetable(summary, fullfile(outputFolder, "frequency_gain_summary.csv"));
writetable(informationSummary, ...
    fullfile(outputFolder, "frequency_gain_information.csv"));
save(fullfile(outputFolder, "frequency_gain.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "gainScenarioNames", "methodNames", "numTrials", ...
    "linearBasis", "linearCoefficient", "details", "summary", ...
    "informationSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1100, 760]);
layout = tiledlayout(2, 2, TileSpacing="compact", Padding="compact");
plotGainScenario(summary, methodNames, "Common", "Common true gain");
plotGainScenario(summary, methodNames, "Linear smooth", ...
    "Linear smooth true gain");
plotGainScenario(summary, methodNames, "Independent phase", ...
    "Independent per-carrier phase");
nexttile;
plotValue = max(informationSummary.LambdaMin, 1e-3);
semilogy(1:height(informationSummary), plotValue, "o", ...
    LineWidth=1.5, MarkerSize=8, MarkerFaceColor=[0.1, 0.45, 0.75]);
xticks(1:height(informationSummary));
xticklabels(informationSummary.GainModel);
xtickangle(15);
ylim([5e-4, 50]);
text(3, 1.3e-3, "true value = 0", HorizontalAlignment="center");
grid on;
ylabel("Minimum EFIM eigenvalue"); title("Nuisance-model information");
title(layout, sprintf("Frequency-selective gain, %d trials", numTrials));
exportgraphics(figureHandle, fullfile(outputFolder, "frequency_gain.png"), ...
    Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "frequency_gain.fig"));
close(figureHandle);

disp(summary);
disp(informationSummary);
end

function plotGainScenario(summary, methodNames, scenario, plotTitle)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^", "-d"];
for methodIndex = 1:numel(methodNames)
    rows = summary.method == methodNames(methodIndex) ...
        & summary.gainScenario == scenario;
    plot(summary.snrDb(rows), summary.mean_captureRate(rows), ...
        lineStyle(methodIndex), LineWidth=1.5, MarkerSize=5);
end
hold off;
ylim([0, 1.02]); grid on;
xlabel("Output SNR (dB)"); ylabel("Capture probability"); title(plotTitle);
legend(methodNames, Location="best");
end
