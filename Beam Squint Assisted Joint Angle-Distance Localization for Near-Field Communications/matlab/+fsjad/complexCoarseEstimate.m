function estimate = complexCoarseEstimate(bank, observation)
%COMPLEXCOARSEESTIMATE Concentrated full-spectrum grid estimate.

arguments
    bank (1, 1) struct
    observation (:, 1) double
end

if size(bank.response, 1) ~= numel(observation)
    error("fsjad:complexCoarseEstimate:SizeMismatch", ...
        "The candidate responses and observation must have equal lengths.");
end

score = abs(bank.response' * observation).^2 ./ bank.energy;
[peakScore, peakIndex] = max(score);
estimate.thetaDeg = bank.thetaDeg(peakIndex);
estimate.rangeM = bank.rangeM(peakIndex);
estimate.candidateIndex = peakIndex;
estimate.score = peakScore / real(observation' * observation);
end
