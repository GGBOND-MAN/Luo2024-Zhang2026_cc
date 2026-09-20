function output = gainModels(c, aEnergy, phaseBasis, frequencyHz, protocol, models)
%GAINMODELS Explained array energy under the requested R57 array-gain models.
%   c is the per-carrier matched filter a_m' * y_m, aEnergy is ||a_m||^2.
%   Only the requested models are evaluated; the rest return NaN. The
%   dispersion and delay models carry inner optimizations, so a range search
%   over a single branch must not pay for the others.

arguments
    c (:, 1) double
    aEnergy (1, :) double {mustBePositive}
    phaseBasis (1, 1) struct
    frequencyHz (1, :) double
    protocol (1, 1) struct = r57.config()
    models (1, :) string = ["free", "coherent", "amplitude", ...
        "dispersion", "tau"]
end

energySum = sum(aEnergy);
freeEnergy = NaN;
coherentEnergy = NaN;
amplitudeEnergy = NaN;
dispersionEnergy = NaN;
tauEnergy = NaN;

% free complex alpha_m per carrier: the frozen P_FALF array model
if ismember("free", models)
    freeEnergy = sum(abs(c).^2./aEnergy(:));
end

% one common complex beta: the R57 primary model
needCoherent = any(ismember(["coherent", "dispersion", "tau"], models));
if needCoherent
    coherentEnergy = abs(sum(c))^2/energySum;
end

% free real rho_m per carrier plus one common phase
if ismember("amplitude", models)
    normalized = c./sqrt(aEnergy(:));
    amplitudeEnergy = 0.5*(sum(abs(normalized).^2)+abs(sum(normalized.^2)));
end

% common beta plus an orthonormal phase polynomial that excludes degree 1
if ismember("dispersion", models)
    objective = @(coefficients) ...
        -abs(sum(exp(-1i*(phaseBasis.dispersion*coefficients(:))).*c))^2 ...
        /energySum;
    options = optimset("Display", "off", ...
        "MaxIter", protocol.dispersion.maxIterations, ...
        "TolX", protocol.dispersion.tolX, "TolFun", protocol.dispersion.tolFun);
    [~, negativeDispersion] = fminsearch(objective, ...
        zeros(numel(phaseBasis.degrees), 1), options);
    dispersionEnergy = max(-negativeDispersion, coherentEnergy);
end

% common beta plus a FREE delay: the Theorem 1 falsification branch
if ismember("tau", models)
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
end

output = struct(version="R57-array-gain-models-v2", ...
    free=freeEnergy, coherent=coherentEnergy, ...
    amplitude=amplitudeEnergy, dispersion=dispersionEnergy, ...
    tau=tauEnergy, energySum=energySum, models=models);
end
