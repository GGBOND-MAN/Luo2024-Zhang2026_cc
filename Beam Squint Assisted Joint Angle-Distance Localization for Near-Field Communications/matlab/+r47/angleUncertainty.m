function output = angleUncertainty(cfg, context, thetaDeg, rangeM, protocol)
%ANGLEUNCERTAINTY Estimate local angle variance from observed information.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r47.config()
end

requested = protocol.angleUncertainty.stepDeg;
available = min(thetaDeg-cfg.thetaLimitsDeg(1), ...
    cfg.thetaLimitsDeg(2)-thetaDeg);
stepDeg = min(requested, available/2);
validStep = isfinite(stepDeg) && stepDeg > 100*eps(max(1, abs(thetaDeg)));
curvature = nan;
rawSigmaDeg = nan;
validCurvature = false;
evaluationCount = 0;
if validStep
    [~, center] = r38RawArrayVpmlScore(cfg, context, thetaDeg, rangeM);
    [~, lower] = r38RawArrayVpmlScore( ...
        cfg, context, thetaDeg-stepDeg, rangeM);
    [~, upper] = r38RawArrayVpmlScore( ...
        cfg, context, thetaDeg+stepDeg, rangeM);
    evaluationCount = 3;
    curvature = (lower.residualEnergy-2*center.residualEnergy ...
        +upper.residualEnergy)/stepDeg^2;
    degreesOfFreedom = context.carrierCount*(cfg.numAntennas-1);
    validCurvature = isfinite(curvature) && curvature > 0 ...
        && center.residualEnergy > 0;
    if validCurvature
        rawSigmaDeg = sqrt(center.residualEnergy ...
            /(degreesOfFreedom*curvature));
    end
else
    degreesOfFreedom = context.carrierCount*(cfg.numAntennas-1);
end
if validCurvature && isfinite(rawSigmaDeg) && rawSigmaDeg > 0
    sigmaDeg = min(max(rawSigmaDeg, ...
        protocol.angleUncertainty.minimumSigmaDeg), ...
        protocol.angleUncertainty.maximumSigmaDeg);
    status = "observed-information";
else
    sigmaDeg = protocol.angleUncertainty.maximumSigmaDeg;
    status = "invalid-curvature-maximum-sigma";
end
output = struct(version="R47-angle-observed-information-v1", ...
    thetaDeg=thetaDeg, rangeM=rangeM, stepDeg=stepDeg, ...
    curvaturePerDeg2=curvature, rawSigmaDeg=rawSigmaDeg, ...
    sigmaDeg=sigmaDeg, degreesOfFreedom=degreesOfFreedom, ...
    validCurvature=validCurvature, status=status, ...
    evaluationCount=evaluationCount);
end
