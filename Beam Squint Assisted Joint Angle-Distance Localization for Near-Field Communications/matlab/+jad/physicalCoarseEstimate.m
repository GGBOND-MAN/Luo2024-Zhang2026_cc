function result = physicalCoarseEstimate(cfg, thetaDeg, rangeM, snrDb, stream)
%PHYSICALCOARSEESTIMATE Simulate (23)-(25) using ideal TTD/PS focal beams.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double
    rangeM (1, 1) double {mustBePositive}
    snrDb (1, 1) double = Inf
    stream = RandStream.getGlobalStream
end

index = (0:cfg.numSubcarriers - 1).';
[focusThetaDeg, focusRangeM, frequencyHz] = jad.trajectory(cfg, index);
gain = zeros(cfg.numSubcarriers, 1);
for k = 1:cfg.numSubcarriers
    userResponse = jad.steeringVector(cfg, thetaDeg, rangeM, frequencyHz(k));
    focusResponse = jad.steeringVector( ...
        cfg, focusThetaDeg(k), focusRangeM(k), frequencyHz(k));
    gain(k) = focusResponse' * userResponse;
end

if isfinite(snrDb)
    noiseStd = 10^(-snrDb / 20);
    noise = noiseStd / sqrt(2) * (randn(stream, cfg.numSubcarriers, 1) ...
        + 1i * randn(stream, cfg.numSubcarriers, 1));
else
    noise = zeros(cfg.numSubcarriers, 1);
end
power = abs(gain + noise).^2;
[~, peak] = max(power);

result.thetaDeg = focusThetaDeg(peak);
result.rangeM = focusRangeM(peak);
result.carrierIndex = index(peak);
result.power = power;
result.focusThetaDeg = focusThetaDeg;
result.focusRangeM = focusRangeM;
end
