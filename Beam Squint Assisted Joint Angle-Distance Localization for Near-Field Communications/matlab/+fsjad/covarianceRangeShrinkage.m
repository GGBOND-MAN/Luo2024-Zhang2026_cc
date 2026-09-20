function result = covarianceRangeShrinkage(frontRangeReplicateM, ...
    musicRangeReplicateM, confidenceZ)
%COVARIANCERANGESHRINKAGE Truth-free covariance shrinkage coefficient.

arguments
    frontRangeReplicateM (:, 1) double
    musicRangeReplicateM (:, 1) double
    confidenceZ (1, 1) double {mustBeNonnegative} = 1.645
end

if numel(frontRangeReplicateM) ~= numel(musicRangeReplicateM)
    error("fsjad:covarianceRangeShrinkage:SizeMismatch", ...
        "Front and MUSIC replicates must have equal length.");
end
if numel(frontRangeReplicateM) < 3
    error("fsjad:covarianceRangeShrinkage:ReplicateCount", ...
        "At least three paired replicates are required.");
end

delta = musicRangeReplicateM - frontRangeReplicateM;
centeredFront = frontRangeReplicateM - mean(frontRangeReplicateM);
centeredDelta = delta - mean(delta);
crossProduct = centeredFront .* centeredDelta;
deltaPower = mean(centeredDelta.^2);
negativeCrossMoment = -mean(crossProduct);
crossMomentStandardError = std(crossProduct) / sqrt(numel(crossProduct));

if deltaPower <= eps
    rawAlpha = 0;
    conservativeAlpha = 0;
else
    rawAlpha = min(max(negativeCrossMoment / deltaPower, 0), 1);
    conservativeNumerator = negativeCrossMoment ...
        - confidenceZ * crossMomentStandardError;
    conservativeAlpha = min(max(conservativeNumerator / deltaPower, 0), 1);
end

frontVariance = var(frontRangeReplicateM, 1);
musicVariance = var(musicRangeReplicateM, 1);
frontMusicCovariance = mean((frontRangeReplicateM ...
    - mean(frontRangeReplicateM)) .* (musicRangeReplicateM ...
    - mean(musicRangeReplicateM)));
independentDenominator = frontVariance + musicVariance;
if independentDenominator <= eps
    independentAlpha = 0;
else
    independentAlpha = min(max( ...
        frontVariance / independentDenominator, 0), 1);
end

result.rawAlpha = rawAlpha;
result.conservativeAlpha = conservativeAlpha;
result.independentAlpha = independentAlpha;
result.negativeCrossMoment = negativeCrossMoment;
result.deltaVariance = deltaPower;
result.crossMomentStandardError = crossMomentStandardError;
result.frontVariance = frontVariance;
result.musicVariance = musicVariance;
result.frontMusicCovariance = frontMusicCovariance;
result.frontRangeReplicateM = frontRangeReplicateM;
result.musicRangeReplicateM = musicRangeReplicateM;
end
