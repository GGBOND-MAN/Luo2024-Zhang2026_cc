function result = cbsLowEstimate(cfg, thetaDeg, rangeM, snrDb, stream)
%CBSLOWESTIMATE Reimplementation of the public Lei et al. CBS-Low code.
% Unlike the released function, the distance scan uses the estimated angle
% rather than the true angle, so angle-to-range error propagation is kept.

arguments
    cfg (1, 1) struct
    thetaDeg (1, 1) double
    rangeM (1, 1) double {mustBePositive}
    snrDb (1, 1) double
    stream = RandStream.getGlobalStream
end

channel = jad.widebandArrayResponse(cfg, thetaDeg, rangeM);
angleWeights = jad.ttdBeamformer(cfg, cfg.thetaLimitsDeg(2), 5, ...
    cfg.thetaLimitsDeg(1), 5);
angleGain = sum(conj(channel) .* angleWeights, 1).';
[anglePath, ~] = endpointTrajectory(cfg, cfg.thetaLimitsDeg(2), 5, ...
    cfg.thetaLimitsDeg(1), 5);
angleEstimate = zeros(4, 1);
for snapshot = 1:4
    measurement = addPeakReferencedNoise(angleGain, snrDb, stream);
    [~, peak] = max(abs(measurement));
    angleEstimate(snapshot) = anglePath(peak);
end
estimatedThetaDeg = mean(angleEstimate);

rangeWeights = jad.ttdBeamformer(cfg, estimatedThetaDeg, ...
    cfg.rangeLimitsM(2), estimatedThetaDeg, cfg.rangeLimitsM(1));
rangeGain = sum(conj(channel) .* rangeWeights, 1).';
[~, rangePath] = endpointTrajectory(cfg, estimatedThetaDeg, ...
    cfg.rangeLimitsM(2), estimatedThetaDeg, cfg.rangeLimitsM(1));
rangeEstimate = zeros(2, 1);
for snapshot = 1:2
    measurement = addPeakReferencedNoise(rangeGain, snrDb, stream);
    [~, peak] = max(abs(measurement));
    rangeEstimate(snapshot) = rangePath(peak);
end

result.thetaDeg = estimatedThetaDeg;
result.rangeM = mean(rangeEstimate);
end

function measurement = addPeakReferencedNoise(signal, snrDb, stream)
noiseStd = max(abs(signal)) * 10^(-snrDb / 20);
noise = noiseStd / sqrt(2) * (randn(stream, size(signal)) ...
    + 1i * randn(stream, size(signal)));
measurement = signal + noise;
end

function [thetaPathDeg, rangePathM] = endpointTrajectory( ...
    cfg, startThetaDeg, startRangeM, endThetaDeg, endRangeM)
index = (0:cfg.numSubcarriers - 1).';
fLow = cfg.fc - cfg.bandwidth / 2;
offset = index * cfg.bandwidth / cfg.numSubcarriers;
frequency = fLow + offset;
startWeight = (cfg.bandwidth - offset) .* fLow ./ (cfg.bandwidth .* frequency);
endWeight = (cfg.bandwidth + fLow) .* offset ./ (cfg.bandwidth .* frequency);
thetaPathDeg = asind(startWeight * sind(startThetaDeg) ...
    + endWeight * sind(endThetaDeg));
inverseRange = startWeight / startRangeM * cosd(startThetaDeg)^2 ...
    ./ cosd(thetaPathDeg).^2 + endWeight / endRangeM * cosd(endThetaDeg)^2 ...
    ./ cosd(thetaPathDeg).^2;
rangePathM = 1 ./ inverseRange;
end
