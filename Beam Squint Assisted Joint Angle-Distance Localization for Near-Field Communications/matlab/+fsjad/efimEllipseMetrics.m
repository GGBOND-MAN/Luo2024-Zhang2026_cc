function metrics = efimEllipseMetrics(information, center, points, confidence)
%EFIMELLIPSEMETRICS Evaluate containment and area of an EFIM ellipse.

arguments
    information (2, 2) double
    center (2, 1) double
    points (2, :) double
    confidence (1, 1) double {mustBeGreaterThan(confidence, 0), ...
        mustBeLessThan(confidence, 1)} = 0.95
end

if any(eig((information + information.') / 2) <= 0)
    error("fsjad:efimEllipseMetrics:NonPositiveInformation", ...
        "The information matrix must be positive definite.");
end

threshold = -2 * log(1 - confidence);
offset = points - center;
quadraticForm = sum(offset .* (information * offset), 1);

metrics.contains = quadraticForm <= threshold;
metrics.quadraticForm = quadraticForm;
metrics.threshold = threshold;
metrics.area = pi * threshold / sqrt(det(information));
end
