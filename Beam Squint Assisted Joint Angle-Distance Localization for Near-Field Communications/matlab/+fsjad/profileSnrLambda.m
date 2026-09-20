function lambda = profileSnrLambda( ...
    snrEstimateDb, lowLambda, thresholdDb, slopeDb)
%PROFILESNRLAMBDA Truth-free SNR release from shrinkage to full profile.

arguments
    snrEstimateDb double {mustBeFinite}
    lowLambda (1, 1) double {mustBeFinite}
    thresholdDb (1, 1) double {mustBeFinite}
    slopeDb (1, 1) double {mustBeFinite}
end

if lowLambda < 0 || lowLambda > 1
    error("fsjad:profileSnrLambda:InvalidLowLambda", ...
        "The low-SNR shrinkage coefficient must lie in [0, 1].");
end
if slopeDb <= 0
    error("fsjad:profileSnrLambda:InvalidSlope", ...
        "The SNR release slope must be positive.");
end

release = 1 ./ (1 + exp(-(snrEstimateDb - thresholdDb) / slopeDb));
lambda = lowLambda + (1 - lowLambda) .* release;
lambda = min(max(lambda, lowLambda), 1);
end
