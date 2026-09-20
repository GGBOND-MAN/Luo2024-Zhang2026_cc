function output = curvature(cfg, context, thetaDeg, rangeM, protocol)
%CURVATURE Evaluate all likelihood curvatures at one common range point.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r53.config()
end

h = protocol.curvature.rangeStepM;
if rangeM-h < cfg.rangeLimitsM(1) || rangeM+h > cfg.rangeLimitsM(2)
    output = invalid(rangeM, h, "physical-boundary");
    return;
end
left = r53.likelihoodState(cfg, context, thetaDeg, rangeM-h, protocol);
center = r53.likelihoodState(cfg, context, thetaDeg, rangeM, protocol);
right = r53.likelihoodState(cfg, context, thetaDeg, rangeM+h, protocol);
hZ = (right.scoreZ-2*center.scoreZ+left.scoreZ)/h^2;
hY = (right.scoreY-2*center.scoreY+left.scoreY)/h^2;
hJoint = hZ+hY;
valid = all(isfinite([hZ, hY, hJoint]));
ratio = nan;
if valid && abs(hZ) > protocol.curvature.curvatureFloor
    ratio = abs(hY)/abs(hZ);
end
output = struct(version="R53-common-point-curvature-v1", ...
    rangeM=rangeM, stepM=h, scoreZ=center.scoreZ, ...
    scoreY=center.scoreY, scoreJoint=center.scoreJoint, ...
    hessianZ=hZ, hessianY=hY, hessianJoint=hJoint, ...
    curvatureRatioYToZ=ratio, valid=valid, status="evaluated");
end

function output = invalid(rangeM, stepM, status)
output = struct(version="R53-common-point-curvature-v1", ...
    rangeM=rangeM, stepM=stepM, scoreZ=nan, scoreY=nan, ...
    scoreJoint=nan, hessianZ=nan, hessianY=nan, hessianJoint=nan, ...
    curvatureRatioYToZ=nan, valid=false, status=status);
end
