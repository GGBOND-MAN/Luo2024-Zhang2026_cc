function output = blockState(cfg, context, thetaRad, rangeM, protocol)
%BLOCKSTATE Evaluate reduced residuals and derivatives for z and Y.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r42.config()
end

[q, derivative] = fsjad.exactSpectralResponse( ...
    cfg, thetaRad, rangeM, context.scan);
qEnergy = real(q'*q);
beta = (q'*context.observation)/qEnergy;
residualZ = context.observation-beta*q;
dZ = beta*derivative;
dZ = dZ-q*((q'*dZ)/qEnergy);

sinTheta = sin(thetaRad);
cosTheta = cos(thetaRad);
distance = rangeM-context.x*sinTheta ...
    +context.xSquared*cosTheta^2/(2*rangeM);
a = exp(-1i*distance.*context.wavenumber)/context.arrayNormalization;
distanceTheta = -context.x*cosTheta ...
    -context.xSquared*sinTheta*cosTheta/rangeM;
distanceRange = 1-context.xSquared*cosTheta^2/(2*rangeM^2);
aTheta = (-1i*distanceTheta.*context.wavenumber).*a;
aRange = (-1i*distanceRange.*context.wavenumber).*a;
alpha = sum(conj(a).*context.snapshots, 1);
residualY = context.snapshots-a.*alpha;
project = @(input) input-a.*sum(conj(a).*input, 1);
dYTheta = project(aTheta).*alpha;
dYRange = project(aRange).*alpha;

energyZ = real(sum(abs(residualZ).^2));
energyY = real(sum(abs(residualY).^2, "all"));
floorZ = protocol.joint.energyFloorScale*max(context.observationEnergy, 1);
floorY = protocol.joint.energyFloorScale*max(context.totalEnergy, 1);
energyZ = max(energyZ, floorZ);
energyY = max(energyY, floorY);
totalCount = context.scalarCount+context.arrayCount;
cost = (context.scalarCount*log(energyZ/context.scalarCount) ...
    +context.arrayCount*log(energyY/context.arrayCount))/totalCount;

innerZ = @(first, second) real(sum(conj(first).*second));
innerY = @(first, second) real(sum(conj(first).*second, "all"));
gradientZ = -2*context.scalarCount/energyZ ...
    *[innerZ(dZ(:, 1), residualZ); innerZ(dZ(:, 2), residualZ)];
gradientY = -2*context.arrayCount/energyY ...
    *[innerY(dYTheta, residualY); innerY(dYRange, residualY)];
informationZ = 2*context.scalarCount/energyZ ...
    *[innerZ(dZ(:, 1), dZ(:, 1)), innerZ(dZ(:, 1), dZ(:, 2)); ...
      innerZ(dZ(:, 2), dZ(:, 1)), innerZ(dZ(:, 2), dZ(:, 2))];
informationY = 2*context.arrayCount/energyY ...
    *[innerY(dYTheta, dYTheta), innerY(dYTheta, dYRange); ...
      innerY(dYRange, dYTheta), innerY(dYRange, dYRange)];

output = struct(version="R42-joint-block-state-v1", cost=cost, ...
    gradient=(gradientZ+gradientY)/totalCount, ...
    information=(informationZ+informationY)/totalCount, ...
    energyZ=energyZ, energyY=energyY, beta=beta, alpha=alpha(:), ...
    scalarCost=log(energyZ/context.scalarCount), ...
    arrayCost=log(energyY/context.arrayCount), ...
    gradientZ=gradientZ/totalCount, gradientY=gradientY/totalCount, ...
    informationZ=informationZ/totalCount, ...
    informationY=informationY/totalCount);
end
