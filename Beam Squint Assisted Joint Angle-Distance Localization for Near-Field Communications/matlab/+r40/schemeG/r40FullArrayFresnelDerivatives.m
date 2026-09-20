function output = r40FullArrayFresnelDerivatives( ...
    cfg, context, thetaRad, rangeM)
%R40FULLARRAYFRESNELDERIVATIVES Analytic radian/meter derivatives.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

a = r40FullArrayFresnelSteering(cfg, context, thetaRad, rangeM);
x = context.x;
xSquared = context.xSquared;
k = context.wavenumber;
sinTheta = sin(thetaRad);
cosTheta = cos(thetaRad);
distanceTheta = -x*cosTheta-xSquared*sinTheta*cosTheta/rangeM;
distanceRange = 1-xSquared*cosTheta^2/(2*rangeM^2);
aTheta = (-1i*distanceTheta.*k).*a;
aRange = (-1i*distanceRange.*k).*a;
output = struct(version="R40-full-array-Fresnel-derivatives-v1", ...
    a=a, aTheta=aTheta, aRange=aRange, ...
    angleUnit="radian", rangeUnit="meter");
end

