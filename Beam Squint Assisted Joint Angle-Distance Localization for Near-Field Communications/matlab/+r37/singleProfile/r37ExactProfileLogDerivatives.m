function result = r37ExactProfileLogDerivatives( ...
    cfg, thetaRad, rangeM, context)
%R37EXACTPROFILELOGDERIVATIVES Exact q-only profile derivatives.

arguments
    cfg (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    context (1, 1) struct
end

if context.numAntennas ~= cfg.numAntennas
    error("r37:ResponseContextAntennaMismatch", ...
        "The response context does not match cfg.numAntennas.");
end

x = context.x;
k = context.wavenumber;
sinTheta = sin(thetaRad);
cosTheta = cos(thetaRad);
distance = sqrt(rangeM^2+context.xSquared ...
    -2*rangeM*x*sinTheta);
rangeNumerator = rangeM-x*sinTheta;

distanceTheta = -rangeM*x*cosTheta./distance;
distanceRange = rangeNumerator./distance;
distanceThetaTheta = rangeM*x*sinTheta./distance ...
    -rangeM^2*x.^2*cosTheta^2./distance.^3;
distanceThetaRange = -x*cosTheta./distance ...
    +rangeM*x*cosTheta.*rangeNumerator./distance.^3;
distanceRangeRange = x.^2*cosTheta^2./distance.^3;

a = exp(-1i*distance.*k)/context.arrayNormalization;
aTheta = (-1i*distanceTheta.*k).*a;
aRange = (-1i*distanceRange.*k).*a;
aThetaTheta = (-1i*distanceThetaTheta.*k ...
    -(distanceTheta.*k).^2).*a;
aThetaRange = (-1i*distanceThetaRange.*k ...
    -(distanceTheta.*k).*(distanceRange.*k)).*a;
aRangeRange = (-1i*distanceRangeRange.*k ...
    -(distanceRange.*k).^2).*a;

project = @(input) sum(context.conjugateBeamformer.*input, 1).';
q = project(a);
qTheta = project(aTheta);
qRange = project(aRange);
qThetaTheta = project(aThetaTheta);
qThetaRange = project(aThetaRange);
qRangeRange = project(aRangeRange);

z = context.observation;
c = q'*z;
cTheta = qTheta'*z;
cRange = qRange'*z;
cThetaTheta = qThetaTheta'*z;
cThetaRange = qThetaRange'*z;
cRangeRange = qRangeRange'*z;
energy = real(q'*q);
energyTheta = 2*real(qTheta'*q);
energyRange = 2*real(qRange'*q);
energyThetaTheta = 2*real(qThetaTheta'*q+qTheta'*qTheta);
energyThetaRange = 2*real(qThetaRange'*q+qTheta'*qRange);
energyRangeRange = 2*real(qRangeRange'*q+qRange'*qRange);

valid = isfinite(c) && abs(c) > realmin && isfinite(energy) ...
    && energy > 0 && context.observationEnergy > 0;
if valid
    score = abs(c)^2/(energy*context.observationEnergy);
    logScore = log(max(score, realmin));
    gradient = [firstDerivative(c, cTheta, energy, energyTheta); ...
        firstDerivative(c, cRange, energy, energyRange)];
    hessian = [secondDerivative(c, cTheta, cTheta, ...
        cThetaTheta, energy, energyTheta, energyTheta, ...
        energyThetaTheta), ...
        secondDerivative(c, cTheta, cRange, cThetaRange, ...
        energy, energyTheta, energyRange, energyThetaRange); ...
        secondDerivative(c, cRange, cTheta, cThetaRange, ...
        energy, energyRange, energyTheta, energyThetaRange), ...
        secondDerivative(c, cRange, cRange, cRangeRange, ...
        energy, energyRange, energyRange, energyRangeRange)];
    valid = all(isfinite([score; logScore; gradient; hessian(:)]));
else
    score = nan;
    logScore = nan;
    gradient = nan(2, 1);
    hessian = nan(2, 2);
end

result = struct(version="R37-exact-q-only-profile-derivatives-v1", ...
    score=score, logScore=logScore, gradient=gradient, ...
    hessian=hessian, valid=valid, responseEvaluationCount=1, ...
    q=q, qTheta=qTheta, qRange=qRange, ...
    qThetaTheta=qThetaTheta, qThetaRange=qThetaRange, ...
    qRangeRange=qRangeRange);
end

function value = firstDerivative(c, cFirst, energy, energyFirst)
value = 2*real(cFirst/c)-energyFirst/energy;
end

function value = secondDerivative(c, cFirst, cSecond, cMixed, ...
    energy, energyFirst, energySecond, energyMixed)
value = 2*real(cMixed/c-cFirst*cSecond/c^2) ...
    -(energyMixed/energy-energyFirst*energySecond/energy^2);
end
