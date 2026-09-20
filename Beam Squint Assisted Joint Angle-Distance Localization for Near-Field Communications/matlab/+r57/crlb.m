function output = crlb(cfg, context, thetaDeg, rangeM, snrDb)
%CRLB Closed-form coherent-array range bound used by the R57 efficiency gate.
%   Implements research/141 Theorem 2 for the one-common-complex-beta array
%   gain model, with the angle treated as known. It is a reporting quantity
%   only: no estimator reads it, and it never enters a range search.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    snrDb (1, 1) double {mustBeFinite}
end

thetaRad = deg2rad(thetaDeg);
g = 1-context.xSquared*cos(thetaRad)^2/(2*rangeM^2);
gBar = mean(g);
gVar = var(g, 1);
k = context.wavenumber(:);
noiseVariance = 10^(-snrDb/10);
gainEnergy = cfg.numAntennas;

coherentInformation = 2*gainEnergy/noiseVariance ...
    *(gBar^2*sum((k-mean(k)).^2)+gVar*sum(k.^2));
freeInformation = 2*gainEnergy/noiseVariance*gVar*sum(k.^2);

output = struct(version="R57-closed-form-range-crlb-v1", ...
    coherentStdM=1/sqrt(coherentInformation), ...
    freeAlphaStdM=1/sqrt(freeInformation), ...
    gainFactor=sqrt(coherentInformation/freeInformation), ...
    gBar=gBar, gVar=gVar);
end
