function score = profileScore(q, observation)
%PROFILESCORE Normalized concentrated-likelihood score.

arguments
    q (:, 1) double
    observation (:, 1) double
end

if numel(q) ~= numel(observation)
    error("fsjad:profileScore:SizeMismatch", ...
        "The candidate response and observation must have equal lengths.");
end

denominator = real(q' * q) * real(observation' * observation);
if denominator <= 0
    error("fsjad:profileScore:ZeroNorm", ...
        "The candidate response and observation must both be nonzero.");
end

score = abs(q' * observation)^2 / denominator;
end
