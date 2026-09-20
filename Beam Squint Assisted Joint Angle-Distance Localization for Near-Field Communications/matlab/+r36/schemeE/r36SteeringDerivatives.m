function output = r36SteeringDerivatives(cfg, state, thetaRad, rangeM)
%R36STEERINGDERIVATIVES Fresnel steering derivatives in radian and meter.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

x = state.referencePositionM(:);
k = 2*pi*state.frequencyHz(:).'/cfg.c;
sinTheta = sin(thetaRad);
cosTheta = cos(thetaRad);
distance = rangeM-x*sinTheta+x.^2*cosTheta^2/(2*rangeM);
distanceTheta = -x*cosTheta-x.^2*sinTheta*cosTheta/rangeM;
distanceRange = 1-x.^2*cosTheta^2/(2*rangeM^2);
distanceThetaTheta = x*sinTheta-x.^2*cos(2*thetaRad)/rangeM;
distanceThetaRange = x.^2*sinTheta*cosTheta/rangeM^2;
distanceRangeRange = x.^2*cosTheta^2/rangeM^3;

a = exp(-1i*distance.*k)/sqrt(state.subarraySize);
aTheta = (-1i*distanceTheta.*k).*a;
aRange = (-1i*distanceRange.*k).*a;
aThetaTheta = (-1i*distanceThetaTheta.*k ...
    -(distanceTheta.*k).^2).*a;
aThetaRange = (-1i*distanceThetaRange.*k ...
    -(distanceTheta.*k).*(distanceRange.*k)).*a;
aRangeRange = (-1i*distanceRangeRange.*k ...
    -(distanceRange.*k).^2).*a;
output = struct(a=a, aTheta=aTheta, aRange=aRange, ...
    aThetaTheta=aThetaTheta, aThetaRange=aThetaRange, ...
    aRangeRange=aRangeRange);
end
