function alpha = oracleRangeShrinkage(frontErrorM, rangeDeltaM)
%ORACLERANGESHRINKAGE Best convex MUSIC displacement using known error.

arguments
    frontErrorM double
    rangeDeltaM double {mustBeEqualSize(frontErrorM, rangeDeltaM)}
end

alpha = zeros(size(frontErrorM));
movable = abs(rangeDeltaM) > eps;
unconstrained = -frontErrorM(movable) .* rangeDeltaM(movable) ...
    ./ rangeDeltaM(movable).^2;
alpha(movable) = min(max(unconstrained, 0), 1);
end

function mustBeEqualSize(first, second)
if ~isequal(size(first), size(second))
    error("fsjad:SizeMismatch", ...
        "frontErrorM and rangeDeltaM must have the same size.");
end
end
