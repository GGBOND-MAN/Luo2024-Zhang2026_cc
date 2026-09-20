function upper = simultaneousUpper(observed, bootstrap, confidence)
%SIMULTANEOUSUPPER Frozen studentized max-statistic one-sided upper bounds.

arguments
    observed (1, :) double
    bootstrap (:, :) double
    confidence (1, 1) double {mustBeGreaterThan(confidence, 0), ...
        mustBeLessThan(confidence, 1)} = 0.95
end

if size(bootstrap, 2) ~= numel(observed) ...
        || any(~isfinite(observed)) || any(~isfinite(bootstrap), "all")
    error("r34:UndefinedSimultaneousFamily", ...
        "The complete simultaneous family must contain finite statistics.");
end
scale = std(bootstrap, 0, 1);
active = scale > 0;
statistics = zeros(size(bootstrap));
statistics(:, active) = (bootstrap(:, active)-observed(active)) ...
    ./scale(active);
critical = quantile(max(statistics, [], 2), confidence);
upper = observed+critical*scale;
upper(~active) = observed(~active);
end
