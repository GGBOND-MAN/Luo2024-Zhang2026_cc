function [score, diagnostics] = r39ProjectionScore( ...
    context, thetaDeg, rangeM, aggregation)
%R39PROJECTIONSCORE Score one aperture with uniform or VPML aggregation.

arguments
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    aggregation (1, 1) string ...
        {mustBeMember(aggregation, ["uniform", "vpml"])}
end

thetaRad = deg2rad(thetaDeg);
distance = rangeM-context.x*sin(thetaRad) ...
    +context.xSquared*cos(thetaRad)^2/(2*rangeM);
steering = exp(-1i*distance.*context.wavenumber) ...
    /context.arrayNormalization;
projectionEnergy = abs(sum(conj(steering).*context.snapshots, 1)).^2;
carrierScore = projectionEnergy./context.snapshotEnergy;
if aggregation == "uniform"
    score = mean(carrierScore);
else
    score = sum(projectionEnergy)/context.totalEnergy;
end
if nargout > 1
    diagnostics = struct(score=score, aggregation=aggregation, ...
        carrierScore=carrierScore(:), ...
        projectionEnergy=projectionEnergy(:), ...
        responseEvaluationCount=1, apertureSize=context.apertureSize, ...
        carrierCount=context.carrierCount);
end
end
