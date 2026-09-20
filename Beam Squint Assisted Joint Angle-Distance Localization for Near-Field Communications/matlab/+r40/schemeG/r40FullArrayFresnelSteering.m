function steering = r40FullArrayFresnelSteering( ...
    cfg, context, thetaRad, rangeM)
%R40FULLARRAYFRESNELSTEERING Scheme F-equivalent full-array steering.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

validateContext(cfg, context);
distance = rangeM-context.x*sin(thetaRad) ...
    +context.xSquared*cos(thetaRad)^2/(2*rangeM);
steering = exp(-1i*distance.*context.wavenumber) ...
    /context.arrayNormalization;
end

function validateContext(cfg, context)
if context.numAntennas ~= cfg.numAntennas ...
        || context.arrayNormalization ~= sqrt(cfg.numAntennas)
    error("r40:FullArrayContextMismatch", ...
        "Scheme G requires the Scheme F full-array context.");
end
end

