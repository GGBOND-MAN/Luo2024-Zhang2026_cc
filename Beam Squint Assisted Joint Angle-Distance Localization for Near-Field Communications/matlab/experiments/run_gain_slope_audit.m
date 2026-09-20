function run_gain_slope_audit
%RUN_GAIN_SLOPE_AUDIT Resolve continuous bias hidden by the coarse grid.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
truthThetaDeg = 12.3;
truthRangeM = 34.2;
truthResponse = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(truthThetaDeg), truthRangeM, scan);
frequencyCoordinate = linspace(-1, 1, cfg.numSubcarriers).';
commonBasis = ones(cfg.numSubcarriers, 1);
linearBasis = [commonBasis, frequencyCoordinate];
slopeMagnitude = [0; 0.3; 0.6; 0.9; 1.2; 1.5];
slopePhaseRad = 1.2;

commonAngleBiasDeg = zeros(size(slopeMagnitude));
commonRangeBiasM = zeros(size(slopeMagnitude));
linearAngleBiasDeg = zeros(size(slopeMagnitude));
linearRangeBiasM = zeros(size(slopeMagnitude));
commonScore = zeros(size(slopeMagnitude));
linearScore = zeros(size(slopeMagnitude));
initial = [truthThetaDeg, truthRangeM];
options = optimset("Display", "off", "TolX", 1e-7, "TolFun", 1e-10, ...
    "MaxIter", 80, "MaxFunEvals", 200);

for slopeIndex = 1:numel(slopeMagnitude)
    gain = linearBasis * [1; slopeMagnitude(slopeIndex) * exp(1i * slopePhaseRad)];
    observation = truthResponse .* gain;
    commonObjective = @(parameter) -fsjad.structuredProfileScore( ...
        fsjad.exactSpectralResponse(cfg, deg2rad(parameter(1)), ...
        parameter(2), scan), observation, commonBasis);
    linearObjective = @(parameter) -fsjad.structuredProfileScore( ...
        fsjad.exactSpectralResponse(cfg, deg2rad(parameter(1)), ...
        parameter(2), scan), observation, linearBasis);
    commonEstimate = fminsearch(commonObjective, initial, options);
    linearEstimate = fminsearch(linearObjective, initial, options);

    commonAngleBiasDeg(slopeIndex) = commonEstimate(1) - truthThetaDeg;
    commonRangeBiasM(slopeIndex) = commonEstimate(2) - truthRangeM;
    linearAngleBiasDeg(slopeIndex) = linearEstimate(1) - truthThetaDeg;
    linearRangeBiasM(slopeIndex) = linearEstimate(2) - truthRangeM;
    commonScore(slopeIndex) = -commonObjective(commonEstimate);
    linearScore(slopeIndex) = -linearObjective(linearEstimate);
end

summary = table(slopeMagnitude, commonAngleBiasDeg, commonRangeBiasM, ...
    linearAngleBiasDeg, linearRangeBiasM, commonScore, linearScore);
outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round2");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(summary, fullfile(outputFolder, "gain_slope_audit.csv"));
save(fullfile(outputFolder, "gain_slope_audit.mat"), ...
    "cfg", "truthThetaDeg", "truthRangeM", "slopePhaseRad", "summary");

figureHandle = figure(Color="w", Position=[100, 100, 900, 390]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
plot(slopeMagnitude, 100 * commonRangeBiasM, "-o", ...
    slopeMagnitude, 100 * linearRangeBiasM, "-s", ...
    LineWidth=1.5, MarkerSize=6);
grid on; xlabel("Linear gain slope magnitude"); ylabel("Range bias (cm)");
title("Continuous pseudo-true range bias");
legend("Common-gain model", "Matched linear model", Location="best");
nexttile;
semilogy(slopeMagnitude, max(1 - commonScore, eps), "-o", ...
    slopeMagnitude, max(1 - linearScore, eps), "-s", ...
    LineWidth=1.5, MarkerSize=6);
grid on; xlabel("Linear gain slope magnitude"); ylabel("1 - profile score");
title("Mismatch hidden by near-unit score");
legend("Common-gain model", "Matched linear model", Location="best");
title(layout, "Off-grid frequency-selective gain audit");
exportgraphics(figureHandle, fullfile(outputFolder, "gain_slope_audit.png"), ...
    Resolution=180);
savefig(figureHandle, fullfile(outputFolder, "gain_slope_audit.fig"));
close(figureHandle);

disp(summary);
end
