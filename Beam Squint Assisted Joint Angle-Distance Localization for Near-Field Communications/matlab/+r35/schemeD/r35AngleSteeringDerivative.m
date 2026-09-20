function [steering, derivativeRad] = r35AngleSteeringDerivative( ...
    cfg, state, thetaRad, rangeM)
%R35ANGLESTEERINGDERIVATIVE Fresnel steering and angle derivative per radian.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    thetaRad (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

x = state.referencePositionM(:);
waveNumber = 2*pi*state.frequencyHz(:).'/cfg.c;
distance = rangeM-x*sin(thetaRad) ...
    +x.^2*cos(thetaRad)^2/(2*rangeM);
distanceDerivative = -x*cos(thetaRad) ...
    -x.^2*sin(thetaRad)*cos(thetaRad)/rangeM;
steering = exp(-1i*distance*waveNumber)/sqrt(state.subarraySize);
derivativeRad = (-1i*distanceDerivative*waveNumber).*steering;
end
