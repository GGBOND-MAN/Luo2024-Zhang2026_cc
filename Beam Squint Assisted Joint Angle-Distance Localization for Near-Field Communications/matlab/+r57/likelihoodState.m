function output = likelihoodState(cfg, context, phaseBasis, thetaDeg, ...
    rangeM, protocol, branches)
%LIKELIHOODSTATE Evaluate the requested R57 branches from one steering pass.
%   The N-by-K steering matrix and the per-carrier matched filter are built
%   once and shared. Only the requested branches are scored, and the scalar
%   block is skipped entirely when no requested branch uses it.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    phaseBasis (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r57.config()
    branches (1, :) string = ["P_FALF", "P_FACR", "P_FACR_A", ...
        "P_FACR_D", "P_FACR_T", "P_FACR_Yonly"]
end

[models, needScalar] = requiredModels(branches);
floorScale = protocol.base.likelihood.numericalEnergyFloorScale;
nZ = context.scalarCount;
nY = context.arrayCount;

scoreZ = 0;
if needScalar
    q = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(thetaDeg), rangeM, context.scan);
    projectionZ = abs(q'*context.observation)^2/real(q'*q);
    floorZ = floorScale*max(context.observationEnergy, 1);
    energyZ = max(real(context.observationEnergy-projectionZ), floorZ);
    scoreZ = -nZ*log(energyZ/nZ);
end

thetaRad = deg2rad(thetaDeg);
distance = rangeM-context.x*sin(thetaRad) ...
    +context.xSquared*cos(thetaRad)^2/(2*rangeM);
a = exp(-1i*distance.*context.wavenumber)/context.arrayNormalization;
aEnergy = real(sum(abs(a).^2, 1));
c = sum(conj(a).*context.snapshots, 1).';
explained = r57.gainModels(c, aEnergy, phaseBasis, ...
    context.frequencyHz, protocol, models);

floorY = floorScale*max(context.totalEnergy, 1);
    function score = arrayScore(projection)
        if isnan(projection)
            score = NaN;
            return;
        end
        residual = max(real(context.totalEnergy-projection), floorY);
        score = -nY*log(residual/nY);
    end

scoreFree = arrayScore(explained.free);
scoreCoherent = arrayScore(explained.coherent);
scoreAmplitude = arrayScore(explained.amplitude);
scoreDispersion = arrayScore(explained.dispersion);
scoreTau = arrayScore(explained.tau);

output = struct(version="R57-multi-branch-likelihood-state-v2", ...
    thetaDeg=thetaDeg, rangeM=rangeM, scoreZ=scoreZ, ...
    scoreYFree=scoreFree, scoreYCoherent=scoreCoherent, ...
    scoreYAmplitude=scoreAmplitude, scoreYDispersion=scoreDispersion, ...
    scoreYTau=scoreTau, explained=explained, branches=branches, ...
    P_FALF=scoreZ+scoreFree, P_FACR=scoreZ+scoreCoherent, ...
    P_FACR_A=scoreZ+scoreAmplitude, P_FACR_D=scoreZ+scoreDispersion, ...
    P_FACR_T=scoreZ+scoreTau, P_FACR_Yonly=scoreCoherent, ...
    scalarCount=nZ, arrayCount=nY);
end

function [models, needScalar] = requiredModels(branches)
models = strings(1, 0);
needScalar = false;
for index = 1:numel(branches)
    switch branches(index)
        case "P_FALF"
            models(end+1) = "free"; %#ok<AGROW>
            needScalar = true;
        case "P_FACR"
            models(end+1) = "coherent"; %#ok<AGROW>
            needScalar = true;
        case "P_FACR_A"
            models(end+1) = "amplitude"; %#ok<AGROW>
            needScalar = true;
        case "P_FACR_D"
            models(end+1) = "dispersion"; %#ok<AGROW>
            needScalar = true;
        case "P_FACR_T"
            models(end+1) = "tau"; %#ok<AGROW>
            needScalar = true;
        case "P_FACR_Yonly"
            models(end+1) = "coherent"; %#ok<AGROW>
        otherwise
            error("r57:UnknownBranch", ...
                "Unknown R57 branch %s.", branches(index));
    end
end
models = unique(models);
end
