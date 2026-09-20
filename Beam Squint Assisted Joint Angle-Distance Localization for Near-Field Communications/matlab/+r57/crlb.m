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
    sigmaTauSeconds (1, 1) double {mustBeNonnegative} = 0
end

thetaRad = deg2rad(thetaDeg);
g = 1-context.xSquared*cos(thetaRad)^2/(2*rangeM^2);
gBar = mean(g);
gVar = var(g, 1);
k = context.wavenumber(:);
noiseVariance = 10^(-snrDb/10);
gainEnergy = cfg.numAntennas;

scale = 2*gainEnergy/noiseVariance;
centred = sum((k-mean(k)).^2);
total = sum(k.^2);
coherentInformation = scale*(gBar^2*centred+gVar*total);
freeInformation = scale*gVar*total;

% Hybrid bound with a Gaussian timing prior tau ~ N(0, sigmaTau^2) acting on
% the array block. The delay score direction is proportional to the
% degree-one polynomial in frequency, so the two-by-two information in
% (r, tau) after profiling the common phase is built from the same centred
% and total sums. sigmaTau = 0 reproduces the coherent bound and
% sigmaTau -> Inf reproduces the free-alpha bound; both limits are checked
% by the unit tests.
c = 299792458;
informationRTau = scale*c*gBar*centred;
informationTauTau = scale*c^2*centred;
if sigmaTauSeconds == 0
    hybridStd = 1/sqrt(coherentInformation);
else
    priorInformation = informationTauTau+1/sigmaTauSeconds^2;
    determinant = coherentInformation*priorInformation-informationRTau^2;
    hybridStd = sqrt(priorInformation/determinant);
end

output = struct(version="R57-closed-form-range-crlb-v2", ...
    coherentStdM=1/sqrt(coherentInformation), ...
    freeAlphaStdM=1/sqrt(freeInformation), ...
    hybridStdM=hybridStd, sigmaTauSeconds=sigmaTauSeconds, ...
    gainFactor=sqrt(coherentInformation/freeInformation), ...
    gBar=gBar, gVar=gVar);
end
