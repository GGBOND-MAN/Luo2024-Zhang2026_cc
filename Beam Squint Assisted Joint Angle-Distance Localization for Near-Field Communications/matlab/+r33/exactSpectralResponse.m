function [q, derivative] = exactSpectralResponse( ...
    cfg, thetaRad, rangeM, context)
%EXACTSPECTRALRESPONSE Compute q and construct derivatives only on demand.

arguments
    cfg (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    context (1, 1) struct
end

if context.numAntennas ~= cfg.numAntennas
    error("r33:ResponseContextAntennaMismatch", ...
        "The response context does not match cfg.numAntennas.");
end

distance = sqrt(rangeM^2 + context.xSquared ...
    - 2*rangeM*context.x*sin(thetaRad));
arrayResponse = exp(-1i*distance*context.wavenumber) ...
    / context.arrayNormalization;
weightedResponse = context.conjugateBeamformer.*arrayResponse;
q = sum(weightedResponse, 1).';

if nargout > 1
    distanceTheta = -rangeM*context.x*cos(thetaRad)./distance;
    distanceRange = (rangeM-context.x*sin(thetaRad))./distance;
    derivativeTheta = -1i*distanceTheta.*context.wavenumber ...
        .*arrayResponse;
    derivativeRange = -1i*distanceRange.*context.wavenumber ...
        .*arrayResponse;
    derivative = [sum(context.conjugateBeamformer.*derivativeTheta, 1).', ...
        sum(context.conjugateBeamformer.*derivativeRange, 1).'];
end
end
