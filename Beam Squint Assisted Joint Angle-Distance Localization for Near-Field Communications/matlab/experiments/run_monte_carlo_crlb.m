function run_monte_carlo_crlb
%RUN_MONTE_CARLO_CRLB Compare continuous complex ML errors with the EFIM.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
thetaGridDeg = (-60:5:60).';
rangeGridM = (15:2.5:50).';
[thetaMeshDeg, rangeMeshM] = meshgrid(thetaGridDeg, rangeGridM);
candidateThetaDeg = thetaMeshDeg(:);
candidateRangeM = rangeMeshM(:);
numCandidates = numel(candidateThetaDeg);
responseBank = complex(zeros(cfg.numSubcarriers, numCandidates));
for candidateIndex = 1:numCandidates
    responseBank(:, candidateIndex) = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(candidateThetaDeg(candidateIndex)), ...
        candidateRangeM(candidateIndex), scan);
end
responseEnergy = real(sum(abs(responseBank).^2, 1)).';

location = ["Weak interior EFIM"; "Strong interior EFIM"];
truthThetaDeg = [0; -55];
truthRangeM = [30; 30];
snrDbValues = [-10, 0, 10, 20];
numTrials = 100;
numRows = numel(location) * numel(snrDbValues);

locationColumn = strings(numRows, 1);
thetaDeg = zeros(numRows, 1);
rangeM = zeros(numRows, 1);
snrDb = zeros(numRows, 1);
angleBiasDeg = zeros(numRows, 1);
rangeBiasM = zeros(numRows, 1);
angleRmseDeg = zeros(numRows, 1);
rangeRmseM = zeros(numRows, 1);
angleStdDeg = zeros(numRows, 1);
rangeStdM = zeros(numRows, 1);
angleCrbDeg = zeros(numRows, 1);
rangeCrbM = zeros(numRows, 1);
angleStdToCrb = zeros(numRows, 1);
rangeStdToCrb = zeros(numRows, 1);
covarianceRelativeError = zeros(numRows, 1);
convergenceRate = zeros(numRows, 1);

stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 47);
parameterScale = diag([deg2rad(1), 1]);
rowIndex = 0;
for locationIndex = 1:numel(location)
    truthIndex = find(candidateThetaDeg == truthThetaDeg(locationIndex) ...
        & candidateRangeM == truthRangeM(locationIndex), 1);
    truthResponse = responseBank(:, truthIndex);
    [~, truthDerivative] = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(truthThetaDeg(locationIndex)), ...
        truthRangeM(locationIndex), scan);
    signalPower = mean(abs(truthResponse).^2);

    for snrIndex = 1:numel(snrDbValues)
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        commonPhase = 2 * pi * rand(stream, 1, numTrials);
        noise = sqrt(noiseVariance / 2) * ( ...
            randn(stream, cfg.numSubcarriers, numTrials) ...
            + 1i * randn(stream, cfg.numSubcarriers, numTrials));
        observation = truthResponse .* exp(1i * commonPhase) + noise;
        complexScore = abs(responseBank' * observation).^2 ./ responseEnergy;
        [~, initialIndex] = max(complexScore, [], 1);

        estimateThetaDeg = zeros(numTrials, 1);
        estimateRangeM = zeros(numTrials, 1);
        converged = false(numTrials, 1);
        for trialIndex = 1:numTrials
            estimate = fsjad.refineProfileEstimate(cfg, ...
                observation(:, trialIndex), ...
                candidateThetaDeg(initialIndex(trialIndex)), ...
                candidateRangeM(initialIndex(trialIndex)), scan, 8);
            estimateThetaDeg(trialIndex) = estimate.thetaDeg;
            estimateRangeM(trialIndex) = estimate.rangeM;
            converged(trialIndex) = estimate.converged;
        end

        error = [estimateThetaDeg - truthThetaDeg(locationIndex), ...
            estimateRangeM - truthRangeM(locationIndex)];
        empiricalCovariance = cov(error, 1);
        information = fsjad.projectedEfim(truthResponse, truthDerivative, ...
            1, noiseVariance);
        scaledInformation = parameterScale.' * information * parameterScale;
        covarianceBound = scaledInformation \ eye(2);

        rowIndex = rowIndex + 1;
        locationColumn(rowIndex) = location(locationIndex);
        thetaDeg(rowIndex) = truthThetaDeg(locationIndex);
        rangeM(rowIndex) = truthRangeM(locationIndex);
        snrDb(rowIndex) = snrDbValues(snrIndex);
        angleBiasDeg(rowIndex) = mean(error(:, 1));
        rangeBiasM(rowIndex) = mean(error(:, 2));
        angleRmseDeg(rowIndex) = sqrt(mean(error(:, 1).^2));
        rangeRmseM(rowIndex) = sqrt(mean(error(:, 2).^2));
        angleStdDeg(rowIndex) = sqrt(empiricalCovariance(1, 1));
        rangeStdM(rowIndex) = sqrt(empiricalCovariance(2, 2));
        angleCrbDeg(rowIndex) = sqrt(covarianceBound(1, 1));
        rangeCrbM(rowIndex) = sqrt(covarianceBound(2, 2));
        angleStdToCrb(rowIndex) = angleStdDeg(rowIndex) / angleCrbDeg(rowIndex);
        rangeStdToCrb(rowIndex) = rangeStdM(rowIndex) / rangeCrbM(rowIndex);
        covarianceRelativeError(rowIndex) = norm( ...
            empiricalCovariance - covarianceBound, "fro") ...
            / norm(covarianceBound, "fro");
        convergenceRate(rowIndex) = mean(converged);
    end
end

summary = table(locationColumn, thetaDeg, rangeM, snrDb, ...
    angleBiasDeg, rangeBiasM, angleRmseDeg, rangeRmseM, ...
    angleStdDeg, rangeStdM, angleCrbDeg, rangeCrbM, ...
    angleStdToCrb, rangeStdToCrb, covarianceRelativeError, convergenceRate);

outputFolder = fullfile(projectFolder, "results", "full_spectrum");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(summary, fullfile(outputFolder, "monte_carlo_crlb_summary.csv"));
save(fullfile(outputFolder, "monte_carlo_crlb.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "numTrials", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 410]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
plotBoundComparison(summary, location, "angleStdDeg", "angleCrbDeg", ...
    "Angle standard deviation", "degrees");
plotBoundComparison(summary, location, "rangeStdM", "rangeCrbM", ...
    "Range standard deviation", "m");
title(layout, sprintf("Continuous profile ML versus EFIM, %d trials", numTrials));
exportgraphics(figureHandle, ...
    fullfile(outputFolder, "monte_carlo_crlb.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "monte_carlo_crlb.fig"));
close(figureHandle);

disp(summary);
end

function plotBoundComparison(summary, locations, empiricalName, boundName, ...
    plotTitle, yLabel)
nexttile;
hold on;
colors = lines(numel(locations));
legendLabels = strings(1, 2 * numel(locations));
for locationIndex = 1:numel(locations)
    rows = summary.locationColumn == locations(locationIndex);
    semilogy(summary.snrDb(rows), summary.(empiricalName)(rows), "-o", ...
        Color=colors(locationIndex, :), LineWidth=1.5, MarkerSize=6);
    semilogy(summary.snrDb(rows), summary.(boundName)(rows), "--", ...
        Color=colors(locationIndex, :), LineWidth=1.5);
    legendLabels(2 * locationIndex - 1) = locations(locationIndex) + " empirical";
    legendLabels(2 * locationIndex) = locations(locationIndex) + " CRLB";
end
hold off;
grid on;
xlabel("Output SNR (dB)");
ylabel(yLabel);
title(plotTitle);
legend(legendLabels, Location="southwest");
end
