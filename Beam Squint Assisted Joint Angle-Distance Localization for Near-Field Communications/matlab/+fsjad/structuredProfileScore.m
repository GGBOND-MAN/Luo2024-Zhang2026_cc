function score = structuredProfileScore(candidateResponse, observation, gainBasis)
%STRUCTUREDPROFILESCORE Concentrated score for a low-dimensional gain basis.

arguments
    candidateResponse (:, :) double
    observation (:, :) double
    gainBasis (:, :) double
end

numCarriers = size(candidateResponse, 1);
if size(observation, 1) ~= numCarriers || size(gainBasis, 1) ~= numCarriers
    error("fsjad:structuredProfileScore:SizeMismatch", ...
        "Responses, observations, and gain basis must share the row count.");
end

numCandidates = size(candidateResponse, 2);
numTrials = size(observation, 2);
observationEnergy = real(sum(abs(observation).^2, 1));
if any(observationEnergy <= 0)
    error("fsjad:structuredProfileScore:ZeroObservation", ...
        "Every observation column must be nonzero.");
end

score = zeros(numCandidates, numTrials);
for candidateIndex = 1:numCandidates
    model = candidateResponse(:, candidateIndex) .* gainBasis;
    coefficient = model \ observation;
    fitted = model * coefficient;
    score(candidateIndex, :) = real(sum(abs(fitted).^2, 1)) ...
        ./ observationEnergy;
end
score = min(max(score, 0), 1);
end
