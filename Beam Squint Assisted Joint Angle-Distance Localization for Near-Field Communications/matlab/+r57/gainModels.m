function output = gainModels(c, aEnergy, phaseBasis, frequencyHz, protocol)
%GAINMODELS Explained array energy under every R57 array-gain model.
%   c is the per-carrier matched filter a_m' * y_m, aEnergy is ||a_m||^2.
%   Every branch is a concentrated maximum-likelihood explained energy; no
%   branch carries a weight, a threshold or a selector.

arguments
    c (:, 1) double
    aEnergy (1, :) double {mustBePositive}
    phaseBasis (1, 1) struct
    frequencyHz (1, :) double
    protocol (1, 1) struct = r57.config()
end

energySum = sum(aEnergy);
normalized = c./sqrt(aEnergy(:));

% free complex alpha_m per carrier: the frozen P_FALF array model
freeEnergy = sum(abs(c).^2./aEnergy(:));

% one common complex beta: the R57 primary model
coherentEnergy = abs(sum(c))^2/energySum;

% free real rho_m per carrier plus one common phase
amplitudeEnergy = 0.5*(sum(abs(normalized).^2)+abs(sum(normalized.^2)));

% common beta plus an orthonormal phase polynomial that excludes degree 1
dispersionObjective = @(coefficients) ...
    -abs(sum(exp(-1i*(phaseBasis.dispersion*coefficients(:))).*c))^2/energySum;
options = optimset("Display", "off", ...
    "MaxIter", protocol.dispersion.maxIterations, ...
    "TolX", protocol.dispersion.tolX, "TolFun", protocol.dispersion.tolFun);
start = zeros(numel(phaseBasis.degrees), 1);
[~, negativeDispersion] = fminsearch(dispersionObjective, start, options);
dispersionEnergy = max(-negativeDispersion, coherentEnergy);

% common beta plus a FREE delay: the Theorem 1 falsification branch
tauGrid = linspace(-protocol.tau.halfWidthSeconds, ...
    protocol.tau.halfWidthSeconds, protocol.tau.coarseCount);
gridEnergy = abs(exp(-1i*2*pi*tauGrid(:)*frequencyHz(:).')*c).^2/energySum;
[bestGrid, bestIndex] = max(gridEnergy);
lower = tauGrid(max(bestIndex-1, 1));
upper = tauGrid(min(bestIndex+1, numel(tauGrid)));
tauEnergy = bestGrid;
if upper > lower
    settings = optimset("TolX", protocol.tau.tolSeconds, "Display", "off");
    [~, negativeTau] = fminbnd(@(tau) ...
        -abs(sum(exp(-1i*2*pi*tau*frequencyHz(:)).*c))^2/energySum, ...
        lower, upper, settings);
    tauEnergy = max(tauEnergy, -negativeTau);
end

output = struct(version="R57-array-gain-models-v1", ...
    free=freeEnergy, coherent=coherentEnergy, ...
    amplitude=amplitudeEnergy, dispersion=dispersionEnergy, ...
    tau=tauEnergy, energySum=energySum);
end
