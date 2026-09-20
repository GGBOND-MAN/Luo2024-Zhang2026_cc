function result = refineJoint(cfg, context, thetaDeg, rangeM, protocol)
%REFINEJOINT Bounded monotone damped GN for the Scheme H objective.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r42.config()
end

timer = tic;
lower = [deg2rad(cfg.thetaLimitsDeg(1)); cfg.rangeLimitsM(1)];
upper = [deg2rad(cfg.thetaLimitsDeg(2)); cfg.rangeLimitsM(2)];
parameter = min(max([deg2rad(thetaDeg); rangeM], lower), upper);
scale = diag([protocol.joint.angleScaleRad, protocol.joint.rangeScaleM]);
costHistory = nan(protocol.joint.maxIterations+1, 1);
parameterHistory = nan(protocol.joint.maxIterations+1, 2);
acceptedSteps = 0;
evaluationCount = 0;
status = "iteration-limit";
converged = false;

for iteration = 1:protocol.joint.maxIterations
    state = r42.blockState(cfg, context, parameter(1), parameter(2), protocol);
    evaluationCount = evaluationCount+1;
    costHistory(acceptedSteps+1) = state.cost;
    parameterHistory(acceptedSteps+1, :) = [rad2deg(parameter(1)), parameter(2)];
    scaledGradient = scale.'*state.gradient;
    scaledInformation = scale.'*state.information*scale;
    diagonal = max(diag(scaledInformation), protocol.joint.energyFloorScale);
    stationarity = norm(scaledGradient./diagonal, Inf);
    if stationarity <= protocol.joint.gradientTolerance
        converged = true;
        status = "gradient-stationary";
        break;
    end

    accepted = false;
    for damping = protocol.joint.damping
        regularized = scaledInformation+damping*diag(diagonal);
        stepScaled = -regularized\scaledGradient;
        if any(~isfinite(stepScaled))
            continue;
        end
        stepScaled = stepScaled/max(1, ...
            norm(stepScaled, Inf)/protocol.joint.maximumScaledStep);
        baseDisplacement = scale*stepScaled;
        for backtrack = 0:protocol.joint.maxBacktracks
            candidate = min(max(parameter+2^(-backtrack)*baseDisplacement, ...
                lower), upper);
            displacement = candidate-parameter;
            slope = state.gradient.'*displacement;
            if slope >= 0 || norm(displacement./diag(scale), Inf) ...
                    <= protocol.joint.stepTolerance
                continue;
            end
            candidateCost = r42.jointCost(cfg, context, ...
                rad2deg(candidate(1)), candidate(2), protocol);
            evaluationCount = evaluationCount+1;
            tolerance = protocol.joint.costToleranceScale ...
                *max([1, abs(state.cost), abs(candidateCost)]);
            if candidateCost <= state.cost ...
                    +protocol.joint.armijo*slope+tolerance
                parameter = candidate;
                acceptedSteps = acceptedSteps+1;
                accepted = true;
                break;
            end
        end
        if accepted
            break;
        end
    end
    if ~accepted
        status = "no-monotone-step";
        break;
    end
end

finalState = r42.blockState(cfg, context, parameter(1), parameter(2), protocol);
evaluationCount = evaluationCount+1;
costHistory(acceptedSteps+1) = finalState.cost;
parameterHistory(acceptedSteps+1, :) = [rad2deg(parameter(1)), parameter(2)];
if acceptedSteps > 0
    reduction = costHistory(1)-finalState.cost;
else
    reduction = 0;
end
if reduction < -protocol.joint.costToleranceScale*max(1, abs(costHistory(1)))
    error("r42:MonotonicityViolation", ...
        "Scheme H returned a joint cost above its starting candidate.");
end
finalScaledInformation = scale.'*finalState.information*scale;
finalDiagonal = max(diag(finalScaledInformation), ...
    protocol.joint.energyFloorScale);
result = struct(version="R42-bounded-joint-GN-v1", ...
    thetaDeg=rad2deg(parameter(1)), rangeM=parameter(2), ...
    initialThetaDeg=thetaDeg, initialRangeM=rangeM, ...
    initialCost=costHistory(1), cost=finalState.cost, ...
    costReduction=reduction, acceptedSteps=acceptedSteps, ...
    iterations=iteration, converged=converged, status=status, ...
    stationarity=norm((scale.'*finalState.gradient)./finalDiagonal, Inf), ...
    costHistory=costHistory(1:acceptedSteps+1), ...
    parameterHistory=parameterHistory(1:acceptedSteps+1, :), ...
    evaluationCount=evaluationCount, runtimeSeconds=toc(timer), ...
    scalarCost=finalState.scalarCost, arrayCost=finalState.arrayCost, ...
    energyZ=finalState.energyZ, energyY=finalState.energyY);
end
