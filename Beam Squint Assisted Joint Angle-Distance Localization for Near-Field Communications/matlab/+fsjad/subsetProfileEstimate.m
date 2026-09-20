function estimate = subsetProfileEstimate(cfg, observation, sampleIndex, ...
    initialThetaDeg, initialRangeM, scan, maxIterations)
%SUBSETPROFILEESTIMATE Locally fit complex spectrum on selected carriers.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    sampleIndex (:, 1) double {mustBeInteger, mustBePositive}
    initialThetaDeg (1, 1) double {mustBeFinite}
    initialRangeM (1, 1) double {mustBeFinite, mustBePositive}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    maxIterations (1, 1) double {mustBeInteger, mustBePositive} = 8
end

if numel(observation) ~= cfg.numSubcarriers
    error("fsjad:subsetProfileEstimate:ObservationSize", ...
        "The observation must contain cfg.numSubcarriers samples.");
end
if any(sampleIndex > cfg.numSubcarriers)
    error("fsjad:subsetProfileEstimate:SampleIndex", ...
        "sampleIndex exceeds cfg.numSubcarriers.");
end

parameter = [initialThetaDeg; initialRangeM];
parameterScale = diag([deg2rad(1), 1]);
subsetObservation = observation(sampleIndex);
converged = false;
for iteration = 1:maxIterations
    [fullResponse, fullDerivative] = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(parameter(1)), parameter(2), scan);
    response = fullResponse(sampleIndex);
    derivative = fullDerivative(sampleIndex, :);
    responseEnergy = real(response' * response);
    beta = response' * subsetObservation / responseEnergy;
    residual = subsetObservation - beta * response;
    scaledDerivative = beta * derivative * parameterScale;
    projectedDerivative = scaledDerivative - response ...
        * (response' * scaledDerivative / responseEnergy);
    normalMatrix = real(projectedDerivative' * projectedDerivative);
    rightHandSide = real(projectedDerivative' * residual);
    step = pinv(normalMatrix) * rightHandSide;
    step = max(min(step, [0.25; 0.5]), [-0.25; -0.5]);
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

fullResponse = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(parameter(1)), parameter(2), scan);
response = fullResponse(sampleIndex);
beta = response' * subsetObservation / real(response' * response);
estimate.thetaDeg = parameter(1);
estimate.rangeM = parameter(2);
estimate.beta = beta;
estimate.score = fsjad.profileScore(response, subsetObservation);
estimate.iterations = iteration;
estimate.converged = converged;
end
