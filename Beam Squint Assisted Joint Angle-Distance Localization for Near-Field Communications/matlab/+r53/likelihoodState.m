function output = likelihoodState(cfg, context, thetaDeg, rangeM, protocol)
%LIKELIHOODSTATE Evaluate strict concentrated-ML z and Y range scores.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r53.config()
end

q = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(thetaDeg), rangeM, context.scan);
qEnergy = real(q'*q);
projectionZ = abs(q'*context.observation)^2/qEnergy;
energyZ = context.observationEnergy-projectionZ;

thetaRad = deg2rad(thetaDeg);
distance = rangeM-context.x*sin(thetaRad) ...
    +context.xSquared*cos(thetaRad)^2/(2*rangeM);
a = exp(-1i*distance.*context.wavenumber)/context.arrayNormalization;
aEnergy = real(sum(abs(a).^2, 1));
projectionY = sum(abs(sum(conj(a).*context.snapshots, 1)).^2./aEnergy);
energyY = context.totalEnergy-projectionY;

floorScale = protocol.likelihood.numericalEnergyFloorScale;
floorZ = floorScale*max(context.observationEnergy, 1);
floorY = floorScale*max(context.totalEnergy, 1);
energyZ = max(real(energyZ), floorZ);
energyY = max(real(energyY), floorY);
nZ = context.scalarCount;
nY = context.arrayCount;
scoreZ = -nZ*log(energyZ/nZ);
scoreY = -nY*log(energyY/nY);

output = struct(version="R53-strict-concentrated-ML-state-v1", ...
    thetaDeg=thetaDeg, rangeM=rangeM, energyZ=energyZ, ...
    energyY=energyY, scoreZ=scoreZ, scoreY=scoreY, ...
    scoreJoint=scoreZ+scoreY, scalarCount=nZ, arrayCount=nY, ...
    qEnergy=qEnergy, minimumEnergyZ=floorZ, minimumEnergyY=floorY);
end
