function estimate = refineProfileMonotone( ...
    cfg, thetaDeg, rangeM, context, options)
%REFINEPROFILEMONOTONE Preserve the solver while using q-only backtracking.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    context (1, 1) struct
    options.MaxIterations (1, 1) double ...
        {mustBeInteger, mustBePositive} = 200
    options.StepTolerance (1, 1) double {mustBePositive} = 1e-6
end

energy = context.observationEnergy;
observation = context.observation;
lower = [cfg.thetaLimitsDeg(1); cfg.rangeLimitsM(1)];
upper = [cfg.thetaLimitsDeg(2); cfg.rangeLimitsM(2)];
parameter = min(max([thetaDeg; rangeM], lower), upper);
scale = diag([deg2rad(1), 1]);
scoreHistory = nan(options.MaxIterations+1, 1);
parameterHistory = nan(options.MaxIterations+1, 2);
stationarityHistory = nan(options.MaxIterations+1, 1);
acceptedDamping = nan(options.MaxIterations, 1);
acceptedBacktracks = nan(options.MaxIterations, 1);
evaluations = 0;
derivativeEvaluations = 0;
qOnlyEvaluations = 0;
converged = false;
status = "iteration_limit";
acceptedSteps = 0;
parameterHistory(1, :) = parameter.';

for iteration = 1:options.MaxIterations
    [q, derivative] = r33.exactSpectralResponse( ...
        cfg, deg2rad(parameter(1)), parameter(2), context);
    evaluations = evaluations+1;
    derivativeEvaluations = derivativeEvaluations+1;
    beta = (q'*observation)/(q'*q);
    residual = observation-beta*q;
    score = r33.profileScore(q, context);
    scoreHistory(acceptedSteps+1) = score;
    jacobian = beta*derivative*scale;
    jacobian = jacobian-q*((q'*jacobian)/(q'*q));
    realJacobian = [real(jacobian); imag(jacobian)]/sqrt(energy);
    realResidual = [real(residual); imag(residual)]/sqrt(energy);
    diagonal = max(sum(realJacobian.^2, 1).', 1e-12);
    rhs = realJacobian.'*realResidual;
    projected = min(max(parameter+rhs./diagonal, lower), upper)-parameter;
    stationarity = norm(projected, Inf);
    stationarityHistory(acceptedSteps+1) = stationarity;
    if stationarity <= options.StepTolerance
        converged = true;
        status = "projected_stationary";
        break;
    end
    accepted = false;
    for damping = [1e-8, 1e-5, 1e-2, 1, 100]
        regularizer = diag(sqrt(diagonal));
        augmentedJacobian = [realJacobian; sqrt(damping)*regularizer];
        augmentedResidual = [realResidual; zeros(2, 1)];
        step = augmentedJacobian\augmentedResidual;
        step = step/max(1, norm(step, Inf));
        for backtrack = 0:20
            proposed = min(max(parameter+2^(-backtrack)*step, lower), upper);
            displacement = proposed-parameter;
            slope = 2*rhs'*displacement;
            if slope <= 0
                continue;
            end
            candidate = r33.exactSpectralResponse( ...
                cfg, deg2rad(proposed(1)), proposed(2), context);
            evaluations = evaluations+1;
            qOnlyEvaluations = qOnlyEvaluations+1;
            candidateScore = r33.profileScore(candidate, context);
            if candidateScore >= score+1e-4*slope
                parameter = proposed;
                acceptedSteps = acceptedSteps+1;
                scoreHistory(acceptedSteps+1) = candidateScore;
                parameterHistory(acceptedSteps+1, :) = parameter.';
                acceptedDamping(acceptedSteps) = damping;
                acceptedBacktracks(acceptedSteps) = backtrack;
                accepted = true;
                break;
            end
        end
        if accepted
            break;
        end
    end
    if ~accepted
        status = "line_search_stalled";
        break;
    end
end

[q, derivative] = r33.exactSpectralResponse( ...
    cfg, deg2rad(parameter(1)), parameter(2), context);
evaluations = evaluations+1;
derivativeEvaluations = derivativeEvaluations+1;
beta = (q'*observation)/(q'*q);
jacobian = beta*derivative*scale;
jacobian = jacobian-q*((q'*jacobian)/(q'*q));
hessian = real(jacobian'*jacobian)/energy;
rhs = real(jacobian'*(observation-beta*q))/energy;
projected = min(max(parameter ...
    + rhs./max(diag(hessian), 1e-12), lower), upper)-parameter;
stationarity = norm(projected, Inf);
scoreHistory(acceptedSteps+1) = r33.profileScore(q, context);
parameterHistory(acceptedSteps+1, :) = parameter.';
stationarityHistory(acceptedSteps+1) = stationarity;
if stationarity <= options.StepTolerance
    converged = true;
    status = "projected_stationary";
end

estimate.thetaDeg = parameter(1);
estimate.rangeM = parameter(2);
estimate.beta = beta;
estimate.score = scoreHistory(acceptedSteps+1);
estimate.converged = converged;
estimate.status = status;
estimate.iterations = iteration;
estimate.acceptedSteps = acceptedSteps;
estimate.stationarity = stationarity;
estimate.responseEvaluations = evaluations;
estimate.derivativeResponseEvaluations = derivativeEvaluations;
estimate.qOnlyResponseEvaluations = qOnlyEvaluations;
estimate.scoreHistory = scoreHistory(1:acceptedSteps+1);
estimate.parameterHistory = parameterHistory(1:acceptedSteps+1, :);
estimate.stationarityHistory = stationarityHistory(1:acceptedSteps+1);
estimate.acceptedDamping = acceptedDamping(1:acceptedSteps);
estimate.acceptedBacktracks = acceptedBacktracks(1:acceptedSteps);
estimate.linearSolver = "augmented-QR";
end
