function alpha = snrReleasedAlpha(snrEstimateDb, thresholdDb, ...
    slopeDb, saturationDb, baseAlpha)
%SNRRELEASEDALPHA Truth-free SNR release with an exact low-SNR fallback.

arguments
    snrEstimateDb double {mustBeFinite}
    thresholdDb (1, 1) double {mustBeFinite}
    slopeDb (1, 1) double {mustBeFinite, mustBePositive}
    saturationDb (1, 1) double = -Inf
    baseAlpha double = zeros(size(snrEstimateDb))
end

if ~isequal(size(baseAlpha), size(snrEstimateDb))
    error("fsjad:AlphaSizeMismatch", ...
        "baseAlpha and snrEstimateDb must have the same size.");
end
if any(baseAlpha < 0 | baseAlpha > 1, "all")
    error("fsjad:AlphaOutsideUnitInterval", ...
        "baseAlpha must lie in [0, 1].");
end

release = 1 ./ (1 + exp((snrEstimateDb - thresholdDb) / slopeDb));
alpha = baseAlpha + (1 - baseAlpha) .* release;
alpha(snrEstimateDb <= saturationDb) = 1;
alpha = min(max(alpha, 0), 1);
end
