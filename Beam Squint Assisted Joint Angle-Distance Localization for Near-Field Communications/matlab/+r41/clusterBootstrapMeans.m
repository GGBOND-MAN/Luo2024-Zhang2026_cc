function bootstrap = clusterBootstrapMeans(values, indices)
%CLUSTERBOOTSTRAPMEANS Preserve one draw across all seven SNR columns.

arguments
    values (:, :) double
    indices (:, :) double {mustBeInteger, mustBePositive}
end

[clusterCount, conditionCount] = size(values);
if size(indices, 1) ~= clusterCount ...
        || any(indices(:) > clusterCount)
    error("r41:BootstrapIndexSize", ...
        "Bootstrap indices must be clusterCount-by-bootstrapCount.");
end
bootstrapCount = size(indices, 2);
bootstrap = zeros(bootstrapCount, conditionCount);
for condition = 1:conditionCount
    sampled = reshape(values(indices(:), condition), ...
        clusterCount, bootstrapCount);
    bootstrap(:, condition) = mean(sampled, 1).';
end
end
