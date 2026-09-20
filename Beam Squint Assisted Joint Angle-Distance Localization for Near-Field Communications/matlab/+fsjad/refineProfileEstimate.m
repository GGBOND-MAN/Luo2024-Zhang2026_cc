function estimate = refineProfileEstimate( ...
    cfg, observation, initialThetaDeg, initialRangeM, scan, maxIterations, ...
    responseFunction)
%REFINEPROFILEESTIMATE Continuously refine the concentrated complex ML fit.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    initialThetaDeg (1, 1) double {mustBeFinite}
    initialRangeM (1, 1) double {mustBeFinite, mustBePositive}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    maxIterations (1, 1) double {mustBeInteger, mustBePositive} = 6
    responseFunction (1, 1) function_handle = @fsjad.exactSpectralResponse
end

parameter = [initialThetaDeg; initialRangeM];
parameterScale = diag([deg2rad(1), 1]);
converged = false;

for iteration = 1:maxIterations
    [q, derivative] = responseFunction( ...
        cfg, deg2rad(parameter(1)), parameter(2), scan);
    responseEnergy = real(q' * q);
    beta = q' * observation / responseEnergy;
    residual = observation - beta * q;
    scaledDerivative = beta * derivative * parameterScale;
    projectedDerivative = scaledDerivative ...
        - q * (q' * scaledDerivative / responseEnergy);
    normalMatrix = real(projectedDerivative' * projectedDerivative);
    rightHandSide = real(projectedDerivative' * residual);
    step = normalMatrix \ rightHandSide;
    step = max(min(step, [1; 1]), [-1; -1]);
    parameter = parameter + step;
    parameter(1) = min(max(parameter(1), cfg.thetaLimitsDeg(1)), ...
        cfg.thetaLimitsDeg(2));
    parameter(2) = min(max(parameter(2), cfg.rangeLimitsM(1)), ...
        cfg.rangeLimitsM(2));

    if norm(step) < 1e-5
        converged = true;
        break;
    end
end

q = responseFunction( ...
    cfg, deg2rad(parameter(1)), parameter(2), scan);
beta = q' * observation / real(q' * q);
estimate.thetaDeg = parameter(1);
estimate.rangeM = parameter(2);
estimate.beta = beta;
estimate.score = fsjad.profileScore(q, observation);
estimate.iterations = iteration;
estimate.converged = converged;
estimate.responseEvaluations = iteration + 1;
end
