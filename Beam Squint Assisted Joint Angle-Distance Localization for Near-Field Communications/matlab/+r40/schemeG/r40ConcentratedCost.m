function [cost, diagnostics] = r40ConcentratedCost( ...
    cfg, context, thetaRad, rangeM)
%R40CONCENTRATEDCOST Normalized full-array VP residual energy.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

a = r40FullArrayFresnelSteering(cfg, context, thetaRad, rangeM);
alphaHat = sum(conj(a).*context.snapshots, 1);
residual = context.snapshots-a.*alphaHat;
residualEnergy = real(sum(abs(residual).^2, "all"));
cost = residualEnergy/context.totalEnergy;
if nargout > 1
    diagnostics = struct(version="R40-concentrated-cost-v1", ...
        cost=cost, residualEnergy=residualEnergy, ...
        totalEnergy=context.totalEnergy, alphaHat=alphaHat(:), ...
        fullArrayEvaluationCount=1);
end
end

