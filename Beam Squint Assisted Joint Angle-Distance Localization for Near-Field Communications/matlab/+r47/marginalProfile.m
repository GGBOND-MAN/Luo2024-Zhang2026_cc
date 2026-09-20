function result = marginalProfile(cfg, observation, scan, thetaDeg, ...
    sigmaThetaDeg, centerRangeM, quadrature, protocol)
%MARGINALPROFILE Marginalize the q likelihood over angle uncertainty.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    scan (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    sigmaThetaDeg (1, 1) double {mustBeFinite, mustBeNonnegative}
    centerRangeM (1, 1) double {mustBeFinite, mustBePositive}
    quadrature (1, 1) struct
    protocol (1, 1) struct = r47.config()
end

if abs(sum(quadrature.weights)-1) > 1e-12 ...
        || any(quadrature.weights <= 0) ...
        || numel(quadrature.nodes) ~= numel(quadrature.weights)
    error("r47:InvalidQuadrature", ...
        "Quadrature nodes and positive normalized weights are required.");
end
r33Protocol = protocol.r45.r34.r33;
profileProtocol = r33Protocol.r32.profile;
bounds = [max(cfg.rangeLimitsM(1), ...
    centerRangeM-profileProtocol.halfWidthM), ...
    min(cfg.rangeLimitsM(2), centerRangeM+profileProtocol.halfWidthM)];
intervals = max(profileProtocol.minimumIntervals, ...
    ceil(diff(bounds)/profileProtocol.coarseSpacingM));
context = r33.prepareResponseContext(cfg, scan, observation);
angleNodeDeg = min(max(thetaDeg+sigmaThetaDeg*quadrature.nodes(:), ...
    cfg.thetaLimitsDeg(1)), cfg.thetaLimitsDeg(2));
weight = quadrature.weights(:)/sum(quadrature.weights);
score = @(rangeM) marginalLogScore( ...
    cfg, rangeM, angleNodeDeg, weight, context, protocol);
result = r31.maximizeScore1D(score, bounds, centerRangeM, ...
    Intervals=intervals, PeakCount=profileProtocol.peakCount, ...
    TolX=profileProtocol.tolXM, ...
    ScoreTolerance=profileProtocol.scoreTolerance);
result.version = "R47-angle-marginal-q-profile-v1";
result.thetaDeg = thetaDeg;
result.sigmaThetaDeg = sigmaThetaDeg;
result.angleNodeDeg = angleNodeDeg;
result.angleWeight = weight;
result.quadratureOrder = numel(weight);
result.qOnlyResponseEvaluations = result.evaluationCount*numel(weight);
end

function output = marginalLogScore( ...
    cfg, rangeM, angleNodeDeg, weight, context, protocol)
output = zeros(size(rangeM));
degreesOfFreedom = context.carrierCount-1;
floorEnergy = protocol.range.residualFloorScale*context.observationEnergy;
for rangeIndex = 1:numel(rangeM)
    logTerm = zeros(numel(angleNodeDeg), 1);
    for angleIndex = 1:numel(angleNodeDeg)
        response = r33.exactSpectralResponse(cfg, ...
            deg2rad(angleNodeDeg(angleIndex)), rangeM(rangeIndex), context);
        explained = abs(response'*context.observation)^2 ...
            /real(response'*response);
        residual = max(context.observationEnergy-explained, floorEnergy);
        logTerm(angleIndex) = log(weight(angleIndex)) ...
            -degreesOfFreedom*log(residual);
    end
    maximum = max(logTerm);
    output(rangeIndex) = maximum+log(sum(exp(logTerm-maximum)));
end
end
