function score = r35SingleCarrierMusicLogScores( ...
    cfg, state, thetaDeg, rangeM)
%R35SINGLECARRIERMUSICLOGSCORES Return ell_m(theta) for every carrier.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    thetaDeg (1, :) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
end

carrierCount = numel(state.frequencyHz);
pointCount = numel(thetaDeg);
score = zeros(carrierCount, pointCount);
x = state.referencePositionM(:);
for point = 1:pointCount
    thetaRad = deg2rad(thetaDeg(point));
    distance = rangeM-x*sin(thetaRad) ...
        +x.^2*cos(thetaRad)^2/(2*rangeM);
    steering = exp(-1i*distance ...
        *(2*pi*state.frequencyHz(:).'/cfg.c))/sqrt(state.subarraySize);
    projection = sum(conj(state.signalVectors).*steering, 1);
    denominator = max(real(1-abs(projection).^2), eps);
    score(:, point) = -log(denominator(:));
end
end
