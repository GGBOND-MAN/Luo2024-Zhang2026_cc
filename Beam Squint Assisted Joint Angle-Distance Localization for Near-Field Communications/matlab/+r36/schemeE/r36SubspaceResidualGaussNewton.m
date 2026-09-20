function result = r36SubspaceResidualGaussNewton( ...
    cfg, state, thetaRad, rangeM)
%R36SUBSPACERESIDUALGAUSSNEWTON Uniform raw-MUSIC residual linearization.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

d = r36SteeringDerivatives(cfg, state, thetaRad, rangeM);
u = state.signalVectors;
residual = projectAway(u, d.a);
jacobianTheta = projectAway(u, d.aTheta);
jacobianRange = projectAway(u, d.aRange);
inner = @(first, second) mean(real(sum(conj(first).*second, 1)));
gradient = 2*[inner(jacobianTheta, residual); ...
    inner(jacobianRange, residual)];
information = 2*[inner(jacobianTheta, jacobianTheta), ...
    inner(jacobianTheta, jacobianRange); ...
    inner(jacobianRange, jacobianTheta), ...
    inner(jacobianRange, jacobianRange)];
carrierCost = real(sum(abs(residual).^2, 1));
result = struct(cost=mean(carrierCost), gradient=gradient, ...
    information=information, carrierCost=carrierCost(:), ...
    carrierCount=numel(state.frequencyHz));
end

function output = projectAway(signalVectors, input)
output = input-signalVectors.*sum(conj(signalVectors).*input, 1);
end
