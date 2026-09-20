function score = profileScore(q, context)
%PROFILESCORE Evaluate the unchanged normalized concentrated score.

arguments
    q (:, 1) double
    context (1, 1) struct
end

denominator = real(q'*q)*context.observationEnergy;
if denominator <= 0
    error("r33:ZeroProfileNorm", ...
        "The candidate response and observation must both be nonzero.");
end
score = abs(q'*context.observation)^2/denominator;
end
