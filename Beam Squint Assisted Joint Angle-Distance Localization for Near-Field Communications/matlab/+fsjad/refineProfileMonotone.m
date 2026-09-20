function estimate = refineProfileMonotone(cfg, observation, thetaDeg, rangeM, scan, options)
%REFINEPROFILEMONOTONE Bounded damped Gauss-Newton with ascent backtracking.
arguments
    cfg (1,1) struct
    observation (:,1) double {mustBeFinite}
    thetaDeg (1,1) double {mustBeFinite}
    rangeM (1,1) double {mustBeFinite,mustBePositive}
    scan (1,1) struct
    options.MaxIterations (1,1) double {mustBeInteger,mustBePositive} = 200
    options.StepTolerance (1,1) double {mustBePositive} = 1e-6
end
assert(numel(observation)==cfg.numSubcarriers,"fsjad:MonotoneSize", ...
    "Observation size must equal the carrier count.");
energy=real(observation'*observation);
assert(energy>0,"fsjad:MonotoneZeroEnergy","Observation energy must be positive.");
lower=[cfg.thetaLimitsDeg(1);cfg.rangeLimitsM(1)];
upper=[cfg.thetaLimitsDeg(2);cfg.rangeLimitsM(2)];
parameter=min(max([thetaDeg;rangeM],lower),upper);
scale=diag([deg2rad(1),1]);
scoreHistory=nan(options.MaxIterations+1,1);
parameterHistory=nan(options.MaxIterations+1,2);
stationarityHistory=nan(options.MaxIterations+1,1);
acceptedDamping=nan(options.MaxIterations,1);
acceptedBacktracks=nan(options.MaxIterations,1);
evaluations=0;
converged=false;
status="iteration_limit";
acceptedSteps=0;
parameterHistory(1,:)=parameter.';
for iteration=1:options.MaxIterations
    [q,D]=fsjad.exactSpectralResponse(cfg,deg2rad(parameter(1)),parameter(2),scan);
    evaluations=evaluations+1;
    beta=(q'*observation)/(q'*q);
    residual=observation-beta*q;
    score=fsjad.profileScore(q,observation);
    scoreHistory(acceptedSteps+1)=score;
    J=beta*D*scale;
    J=J-q*((q'*J)/(q'*q));
    realJacobian=[real(J);imag(J)]/sqrt(energy);
    realResidual=[real(residual);imag(residual)]/sqrt(energy);
    diagonal=max(sum(realJacobian.^2,1).',1e-12);
    rhs=realJacobian.'*realResidual;
    % A diagonally scaled projected gradient tests constrained stationarity.
    projected=min(max(parameter+rhs./diagonal,lower),upper)-parameter;
    stationarity=norm(projected,Inf);
    stationarityHistory(acceptedSteps+1)=stationarity;
    if stationarity<=options.StepTolerance
        converged=true;
        status="projected_stationary";
        break;
    end
    accepted=false;
    for damping=[1e-8,1e-5,1e-2,1,100]
        regularizer=diag(sqrt(diagonal));
        augmentedJacobian=[realJacobian;sqrt(damping)*regularizer];
        augmentedResidual=[realResidual;zeros(2,1)];
        step=augmentedJacobian\augmentedResidual;
        step=step/max(1,norm(step,Inf));
        for backtrack=0:20
            proposed=min(max(parameter+2^(-backtrack)*step,lower),upper);
            displacement=proposed-parameter;
            slope=2*rhs'*displacement;
            if slope<=0
                continue;
            end
            candidate=fsjad.exactSpectralResponse(cfg, ...
                deg2rad(proposed(1)),proposed(2),scan);
            evaluations=evaluations+1;
            candidateScore=fsjad.profileScore(candidate,observation);
            if candidateScore>=score+1e-4*slope
                parameter=proposed;
                acceptedSteps=acceptedSteps+1;
                scoreHistory(acceptedSteps+1)=candidateScore;
                parameterHistory(acceptedSteps+1,:)=parameter.';
                acceptedDamping(acceptedSteps)=damping;
                acceptedBacktracks(acceptedSteps)=backtrack;
                accepted=true;
                break;
            end
        end
        if accepted
            break;
        end
    end
    if ~accepted
        status="line_search_stalled";
        break;
    end
end
[q,D]=fsjad.exactSpectralResponse(cfg,deg2rad(parameter(1)),parameter(2),scan);
evaluations=evaluations+1;
beta=(q'*observation)/(q'*q);
J=beta*D*scale;
J=J-q*((q'*J)/(q'*q));
H=real(J'*J)/energy;
rhs=real(J'*(observation-beta*q))/energy;
projected=min(max(parameter+rhs./max(diag(H),1e-12),lower),upper)-parameter;
stationarity=norm(projected,Inf);
scoreHistory(acceptedSteps+1)=fsjad.profileScore(q,observation);
parameterHistory(acceptedSteps+1,:)=parameter.';
stationarityHistory(acceptedSteps+1)=stationarity;
if stationarity<=options.StepTolerance
    converged=true;
    status="projected_stationary";
end
estimate.thetaDeg=parameter(1);
estimate.rangeM=parameter(2);
estimate.beta=beta;
estimate.score=scoreHistory(acceptedSteps+1);
estimate.converged=converged;
estimate.status=status;
estimate.iterations=iteration;
estimate.acceptedSteps=acceptedSteps;
estimate.stationarity=stationarity;
estimate.responseEvaluations=evaluations;
estimate.scoreHistory=scoreHistory(1:acceptedSteps+1);
estimate.parameterHistory=parameterHistory(1:acceptedSteps+1,:);
estimate.stationarityHistory=stationarityHistory(1:acceptedSteps+1);
estimate.acceptedDamping=acceptedDamping(1:acceptedSteps);
estimate.acceptedBacktracks=acceptedBacktracks(1:acceptedSteps);
estimate.linearSolver="augmented-QR";
end
