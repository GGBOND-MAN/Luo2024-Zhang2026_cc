function output = likelihoodState(cfg, context, phaseBasis, thetaDeg, rangeM, protocol)
%LIKELIHOODSTATE Evaluate every R57 branch score from one shared steering pass.
%   The N-by-K steering matrix and the per-carrier matched filter are built
%   once and reused by all branches; no branch rebuilds them.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    phaseBasis (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r57.config()
end

q = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(thetaDeg), rangeM, context.scan);
projectionZ = abs(q'*context.observation)^2/real(q'*q);
energyZ = context.observationEnergy-projectionZ;

thetaRad = deg2rad(thetaDeg);
distance = rangeM-context.x*sin(thetaRad) ...
    +context.xSquared*cos(thetaRad)^2/(2*rangeM);
a = exp(-1i*distance.*context.wavenumber)/context.arrayNormalization;
aEnergy = real(sum(abs(a).^2, 1));
c = sum(conj(a).*context.snapshots, 1).';
explained = r57.gainModels(c, aEnergy, phaseBasis, ...
    context.frequencyHz, protocol);

floorScale = protocol.base.likelihood.numericalEnergyFloorScale;
floorZ = floorScale*max(context.observationEnergy, 1);
floorY = floorScale*max(context.totalEnergy, 1);
nZ = context.scalarCount;
nY = context.arrayCount;
scoreZ = -nZ*log(max(real(energyZ), floorZ)/nZ);

    function score = arrayScore(projection)
        residual = max(real(context.totalEnergy-projection), floorY);
        score = -nY*log(residual/nY);
    end

scoreFree = arrayScore(explained.free);
scoreCoherent = arrayScore(explained.coherent);
scoreAmplitude = arrayScore(explained.amplitude);
scoreDispersion = arrayScore(explained.dispersion);
scoreTau = arrayScore(explained.tau);

output = struct(version="R57-multi-branch-likelihood-state-v1", ...
    thetaDeg=thetaDeg, rangeM=rangeM, scoreZ=scoreZ, ...
    scoreYFree=scoreFree, scoreYCoherent=scoreCoherent, ...
    scoreYAmplitude=scoreAmplitude, scoreYDispersion=scoreDispersion, ...
    scoreYTau=scoreTau, explained=explained, ...
    P_FALF=scoreZ+scoreFree, P_FACR=scoreZ+scoreCoherent, ...
    P_FACR_A=scoreZ+scoreAmplitude, P_FACR_D=scoreZ+scoreDispersion, ...
    P_FACR_T=scoreZ+scoreTau, P_FACR_Yonly=scoreCoherent, ...
    scalarCount=nZ, arrayCount=nY);
end
