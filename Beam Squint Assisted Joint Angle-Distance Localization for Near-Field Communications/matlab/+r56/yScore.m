function score = yScore(context, thetaDeg, rangeM, protocol)
%YSCORE Evaluate the strict concentrated Y-only score for one context.

arguments
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r56.config()
end

thetaRad = deg2rad(thetaDeg);
distance = rangeM-context.x*sin(thetaRad) ...
    +context.xSquared*cos(thetaRad)^2/(2*rangeM);
a = exp(-1i*distance.*context.wavenumber)/context.arrayNormalization;
aEnergy = real(sum(abs(a).^2, 1));
projection = sum(abs(sum(conj(a).*context.snapshots, 1)).^2./aEnergy);
energy = context.totalEnergy-projection;
floorValue = protocol.base.likelihood.numericalEnergyFloorScale ...
    *max(context.totalEnergy, 1);
energy = max(real(energy), floorValue);
score = -context.arrayCount*log(energy/context.arrayCount);
end
