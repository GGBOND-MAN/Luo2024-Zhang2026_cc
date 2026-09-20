function run_fresnel_mismatch
%RUN_FRESNEL_MISMATCH Measure noiseless bias from a Fresnel channel model.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

baseCfg = jad.defaultConfig();
numAntennasValues = [64, 128, 256, 512];
thetaDegValues = [-50, -25, 0, 25, 50];
rangeMValues = [3, 5, 10, 15, 30, 50];
numRows = numel(numAntennasValues) * numel(thetaDegValues) ...
    * numel(rangeMValues);

numAntennas = zeros(numRows, 1);
thetaDeg = zeros(numRows, 1);
rangeM = zeros(numRows, 1);
modelCoherenceAtTruth = zeros(numRows, 1);
exactAngleBiasDeg = zeros(numRows, 1);
exactRangeBiasM = zeros(numRows, 1);
fresnelAngleBiasDeg = zeros(numRows, 1);
fresnelRangeBiasM = zeros(numRows, 1);
fresnelProfileScore = zeros(numRows, 1);
fresnelConverged = false(numRows, 1);
rowIndex = 0;

for antennaIndex = 1:numel(numAntennasValues)
    cfg = baseCfg;
    cfg.numAntennas = numAntennasValues(antennaIndex);
    cfg.elementIndex = (0:cfg.numAntennas - 1).' ...
        - (cfg.numAntennas - 1) / 2;
    scan = fsjad.prepareScan(cfg);
    estimatorCfg = cfg;
    estimatorCfg.rangeLimitsM = [2, 55];

    for thetaIndex = 1:numel(thetaDegValues)
        for rangeIndex = 1:numel(rangeMValues)
            rowIndex = rowIndex + 1;
            truthThetaDeg = thetaDegValues(thetaIndex);
            truthRangeM = rangeMValues(rangeIndex);
            observation = fsjad.exactSpectralResponse(cfg, ...
                deg2rad(truthThetaDeg), truthRangeM, scan);
            fresnelAtTruth = fsjad.fresnelSpectralResponse(cfg, ...
                deg2rad(truthThetaDeg), truthRangeM, scan);
            exactEstimate = fsjad.refineProfileEstimate(estimatorCfg, observation, ...
                truthThetaDeg + 0.02, truthRangeM + 0.02, scan, 20, ...
                @fsjad.exactSpectralResponse);
            fresnelEstimate = fsjad.refineProfileEstimate(estimatorCfg, observation, ...
                truthThetaDeg, truthRangeM, scan, 40, ...
                @fsjad.fresnelSpectralResponse);

            numAntennas(rowIndex) = cfg.numAntennas;
            thetaDeg(rowIndex) = truthThetaDeg;
            rangeM(rowIndex) = truthRangeM;
            modelCoherenceAtTruth(rowIndex) = fsjad.profileScore( ...
                fresnelAtTruth, observation);
            exactAngleBiasDeg(rowIndex) = exactEstimate.thetaDeg - truthThetaDeg;
            exactRangeBiasM(rowIndex) = exactEstimate.rangeM - truthRangeM;
            fresnelAngleBiasDeg(rowIndex) = ...
                fresnelEstimate.thetaDeg - truthThetaDeg;
            fresnelRangeBiasM(rowIndex) = ...
                fresnelEstimate.rangeM - truthRangeM;
            fresnelProfileScore(rowIndex) = fresnelEstimate.score;
            fresnelConverged(rowIndex) = fresnelEstimate.converged;
        end
    end
end

absExactAngleBiasDeg = abs(exactAngleBiasDeg);
absExactRangeBiasM = abs(exactRangeBiasM);
absFresnelAngleBiasDeg = abs(fresnelAngleBiasDeg);
absFresnelRangeBiasM = abs(fresnelRangeBiasM);
details = table(numAntennas, thetaDeg, rangeM, modelCoherenceAtTruth, ...
    exactAngleBiasDeg, exactRangeBiasM, fresnelAngleBiasDeg, ...
    fresnelRangeBiasM, absExactAngleBiasDeg, absExactRangeBiasM, ...
    absFresnelAngleBiasDeg, absFresnelRangeBiasM, ...
    fresnelProfileScore, fresnelConverged);
insideClaimedRegion = rangeM >= baseCfg.rangeLimitsM(1);
summary = groupsummary(details, ["numAntennas", "rangeM"], "max", ...
    ["absExactAngleBiasDeg", "absExactRangeBiasM", ...
    "absFresnelAngleBiasDeg", "absFresnelRangeBiasM"]);
claimedSummary = groupsummary(details(insideClaimedRegion, :), ...
    "numAntennas", ["mean", "max"], ...
    ["modelCoherenceAtTruth", "absFresnelAngleBiasDeg", ...
    "absFresnelRangeBiasM"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round2");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(details, fullfile(outputFolder, "fresnel_mismatch_points.csv"));
writetable(summary, fullfile(outputFolder, "fresnel_mismatch_summary.csv"));
writetable(claimedSummary, ...
    fullfile(outputFolder, "fresnel_mismatch_claimed_region.csv"));
save(fullfile(outputFolder, "fresnel_mismatch.mat"), ...
    "baseCfg", "numAntennasValues", "thetaDegValues", "rangeMValues", ...
    "details", "summary", "claimedSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1100, 760]);
layout = tiledlayout(2, 2, TileSpacing="compact", Padding="compact");
plotMismatch(details, numAntennasValues, "modelCoherenceAtTruth", ...
    "Exact/Fresnel coherence at truth", "Coherence", false);
plotMismatch(details, numAntennasValues, "fresnelProfileScore", ...
    "Best local Fresnel profile score", "Score", false);
plotMismatch(details, numAntennasValues, "fresnelAngleBiasDeg", ...
    "Worst absolute angle bias", "degrees", true);
plotMismatch(details, numAntennasValues, "fresnelRangeBiasM", ...
    "Worst absolute range bias", "m", true);
title(layout, "Noiseless exact-data / Fresnel-estimator mismatch");
exportgraphics(figureHandle, fullfile(outputFolder, "fresnel_mismatch.png"), ...
    Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "fresnel_mismatch.fig"));
close(figureHandle);

disp(claimedSummary);
end

function plotMismatch(details, numAntennasValues, variableName, ...
    plotTitle, yLabel, useLog)
nexttile;
hold on;
lineStyle = ["-o", "-s", "-^", "-d"];
for antennaIndex = 1:numel(numAntennasValues)
    values = zeros(numel(unique(details.rangeM)), 1);
    ranges = unique(details.rangeM);
    for rangeIndex = 1:numel(ranges)
        rows = details.numAntennas == numAntennasValues(antennaIndex) ...
            & details.rangeM == ranges(rangeIndex);
        if contains(variableName, "Bias")
            values(rangeIndex) = max(abs(details.(variableName)(rows)));
        else
            values(rangeIndex) = min(details.(variableName)(rows));
        end
    end
    if useLog
        loglog(ranges, max(values, eps), lineStyle(antennaIndex), ...
            LineWidth=1.5, MarkerSize=5);
    else
        semilogx(ranges, values, lineStyle(antennaIndex), ...
            LineWidth=1.5, MarkerSize=5);
    end
end
hold off;
grid on;
xlabel("Range (m)"); ylabel(yLabel); title(plotTitle);
legend("N=64", "N=128", "N=256", "N=512", Location="best");
end
