function [score, diagnostics] = coherentArrayScore( ...
    cfg, context, thetaDeg, rangeM)
%COHERENTARRAYSCORE Common-gain coherent score over array and carriers.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

thetaRad = deg2rad(thetaDeg);
distance = rangeM-context.x*sin(thetaRad) ...
    +context.xSquared*cos(thetaRad)^2/(2*rangeM);
signal = exp(-1i*distance.*context.wavenumber);
signalEnergy = cfg.numAntennas*context.carrierCount;
innerProduct = sum(conj(signal).*context.snapshots, "all");
explainedEnergy = abs(innerProduct)^2/signalEnergy;
score = explainedEnergy/context.totalEnergy;
roundoffTolerance = 100*eps*max(context.totalEnergy, 1);
if score < -roundoffTolerance || score > 1+roundoffTolerance
    error("r43:CoherentScoreInvariant", ...
        "The coherent projection score must lie inside [0,1].");
end
score = min(max(real(score), 0), 1);
if nargout > 1
    gain = innerProduct/signalEnergy;
    diagnostics = struct(version="R43-common-gain-coherent-array-score-v1", ...
        score=score, gain=gain, signalEnergy=signalEnergy, ...
        explainedEnergy=explainedEnergy, ...
        residualEnergy=max(context.totalEnergy-explainedEnergy, 0));
end
end
