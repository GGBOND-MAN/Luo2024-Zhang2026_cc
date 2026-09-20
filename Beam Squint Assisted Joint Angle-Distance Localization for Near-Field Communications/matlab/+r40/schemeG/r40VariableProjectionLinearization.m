function output = r40VariableProjectionLinearization( ...
    cfg, context, thetaRad, rangeM)
%R40VARIABLEPROJECTIONLINEARIZATION Reduced VP Gauss-Newton model.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

derivatives = r40FullArrayFresnelDerivatives( ...
    cfg, context, thetaRad, rangeM);
a = derivatives.a;
alphaHat = sum(conj(a).*context.snapshots, 1);
residual = context.snapshots-a.*alphaHat;
project = @(input) input-a.*sum(conj(a).*input, 1);
dTheta = project(derivatives.aTheta).*alphaHat;
dRange = project(derivatives.aRange).*alphaHat;
inner = @(first, second) real(sum(conj(first).*second, "all")) ...
    /context.totalEnergy;
gradient = -2*[inner(dTheta, residual); inner(dRange, residual)];
information = 2*[inner(dTheta, dTheta), inner(dTheta, dRange); ...
    inner(dRange, dTheta), inner(dRange, dRange)];
cost = real(sum(abs(residual).^2, "all"))/context.totalEnergy;
output = struct(version="R40-reduced-VP-GN-v1", cost=cost, ...
    gradient=gradient, information=information, ...
    alphaHat=alphaHat(:), carrierCount=context.carrierCount, ...
    residualEnergy=cost*context.totalEnergy, ...
    fullArrayEvaluationCount=1, angleUnit="radian", ...
    rangeUnit="meter");
end

