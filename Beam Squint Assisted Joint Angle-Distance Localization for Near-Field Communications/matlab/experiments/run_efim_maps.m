function run_efim_maps
%RUN_EFIM_MAPS Map full-spectrum local identifiability over the region.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
thetaGridDeg = (-60:5:60).';
rangeGridM = (15:2.5:50).';
[thetaMeshDeg, rangeMeshM] = meshgrid(thetaGridDeg, rangeGridM);
truthThetaDeg = thetaMeshDeg(:);
truthRangeM = rangeMeshM(:);
numLocations = numel(truthThetaDeg);

beta = 1;
noiseVariance = 1;
parameterScale = diag([deg2rad(1), 1]);
lambdaMin = zeros(numLocations, 1);
determinant = zeros(numLocations, 1);
conditionNumber = zeros(numLocations, 1);
angleBoundDeg = zeros(numLocations, 1);
rangeBoundM = zeros(numLocations, 1);

for locationIndex = 1:numLocations
    [q, derivative] = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(truthThetaDeg(locationIndex)), ...
        truthRangeM(locationIndex), scan);
    information = fsjad.projectedEfim( ...
        q, derivative, beta, noiseVariance);
    scaledInformation = parameterScale.' * information * parameterScale;
    eigenvalues = eig(scaledInformation, "vector");
    lambdaMin(locationIndex) = min(eigenvalues);
    determinant(locationIndex) = det(scaledInformation);
    conditionNumber(locationIndex) = cond(scaledInformation);
    covarianceBound = information \ eye(2);
    angleBoundDeg(locationIndex) = rad2deg(sqrt(covarianceBound(1, 1)));
    rangeBoundM(locationIndex) = sqrt(covarianceBound(2, 2));
end

pointResults = table(truthThetaDeg, truthRangeM, lambdaMin, determinant, ...
    conditionNumber, angleBoundDeg, rangeBoundM, ...
    VariableNames=["ThetaDeg", "RangeM", "ScaledLambdaMin", ...
    "ScaledDeterminant", "ScaledConditionNumber", ...
    "AngleCrbDegAtUnitGainNoise", "RangeCrbMAtUnitGainNoise"]);
summary = table(min(lambdaMin), max(lambdaMin), ...
    min(determinant), max(determinant), ...
    min(conditionNumber), median(conditionNumber), max(conditionNumber), ...
    max(angleBoundDeg), max(rangeBoundM), ...
    VariableNames=["MinLambdaMin", "MaxLambdaMin", ...
    "MinDeterminant", "MaxDeterminant", "MinConditionNumber", ...
    "MedianConditionNumber", "MaxConditionNumber", ...
    "MaxAngleCrbDegAtUnitGainNoise", "MaxRangeCrbMAtUnitGainNoise"]);

outputFolder = fullfile(projectFolder, "results", "full_spectrum");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(pointResults, fullfile(outputFolder, "efim_map_points.csv"));
writetable(summary, fullfile(outputFolder, "efim_map_summary.csv"));
save(fullfile(outputFolder, "efim_maps.mat"), ...
    "cfg", "thetaGridDeg", "rangeGridM", "pointResults", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 1200, 410]);
layout = tiledlayout(1, 3, TileSpacing="compact", Padding="compact");
plotLogMap(thetaGridDeg, rangeGridM, lambdaMin, ...
    "Scaled minimum eigenvalue", "log_{10} lambda_{min}");
plotLogMap(thetaGridDeg, rangeGridM, determinant, ...
    "Scaled determinant", "log_{10} determinant");
plotLogMap(thetaGridDeg, rangeGridM, conditionNumber, ...
    "Scaled condition number", "log_{10} condition number");
title(layout, ["Full-complex-spectrum EFIM, 1 degree / 1 m scaling, " ...
    "|beta|^2 / sigma^2 = 1"]);
exportgraphics(figureHandle, fullfile(outputFolder, "efim_maps.png"), ...
    Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "efim_maps.fig"));
close(figureHandle);

disp(summary);
end

function plotLogMap(thetaGridDeg, rangeGridM, valueVector, plotTitle, label)
nexttile;
imagesc(thetaGridDeg, rangeGridM, reshape(log10(valueVector), ...
    numel(rangeGridM), numel(thetaGridDeg)));
set(gca, YDir="normal");
xlabel("Angle (degrees)");
ylabel("Range (m)");
title(plotTitle);
colorbarHandle = colorbar;
colorbarHandle.Label.String = label;
end
