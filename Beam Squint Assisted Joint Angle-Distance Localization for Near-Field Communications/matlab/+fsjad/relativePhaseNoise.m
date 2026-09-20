function phaseRad = relativePhaseNoise( ...
    numCarriers, numTrials, rmsDeg, stream)
%RELATIVEPHASENOISE Generate zero-mean residual cross-carrier phase errors.

arguments
    numCarriers (1, 1) double {mustBeInteger, mustBeGreaterThan(numCarriers, 1)}
    numTrials (1, 1) double {mustBeInteger, mustBePositive}
    rmsDeg (1, 1) double {mustBeNonnegative}
    stream = RandStream.getGlobalStream
end

if rmsDeg == 0
    phaseRad = zeros(numCarriers, numTrials);
    return;
end

phaseRad = randn(stream, numCarriers, numTrials);
phaseRad = phaseRad - mean(phaseRad, 1);
phaseRad = phaseRad ./ sqrt(mean(phaseRad.^2, 1));
phaseRad = deg2rad(rmsDeg) * phaseRad;
end
