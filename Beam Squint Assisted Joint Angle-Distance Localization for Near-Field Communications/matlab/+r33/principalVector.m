function [vector, diagnostics] = principalVector(aligned, gramProtocol, options)
%PRINCIPALVECTOR Recover the dominant left vector from the smaller Gram EVD.

arguments
    aligned (:, :) double
    gramProtocol (1, 1) struct = r33.config().gram
    options.UseGram (1, 1) logical = true
end

[rowCount, columnCount] = size(aligned);
diagnostics = struct(method="direct-covariance-eig", fallback=false, ...
    fallbackReason="", maximumEigenvalue=nan, secondEigenvalue=nan, ...
    relativeEigengap=nan, relativeResidual=nan, ...
    matrixFormationMacs=0, evdCubicUnits=0, recoveryMacs=0, ...
    matrixOrder=rowCount);
useGram = options.UseGram ...
    && (~gramProtocol.useOnlyWhenColumnsLessThanRows ...
    || columnCount < rowCount);
if ~useGram
    [vector, diagnostics] = directVector(aligned, diagnostics, ...
        "direct-smaller-side");
    return;
end

try
    gram = aligned'*aligned/columnCount;
    gram = (gram+gram')/2;
    [eigenvectors, eigenvalues] = eig(gram, "vector");
    [ordered, order] = sort(real(eigenvalues), "descend");
    maximumEigenvalue = ordered(1);
    secondEigenvalue = ordered(min(2, numel(ordered)));
    scale = max(real(trace(gram)), eps);
    relativeEigenvalue = maximumEigenvalue/scale;
    relativeEigengap = (maximumEigenvalue-secondEigenvalue) ...
        / max(maximumEigenvalue, eps);
    invalidSpectrum = ~isfinite(maximumEigenvalue) ...
        || maximumEigenvalue <= 0 ...
        || relativeEigenvalue < gramProtocol.minimumRelativeEigenvalue;
    nearDegenerate = relativeEigengap ...
        < gramProtocol.minimumRelativeEigengap;
    if invalidSpectrum || nearDegenerate
        reason = "near-zero-maximum-eigenvalue";
        if nearDegenerate
            reason = "near-degenerate-leading-eigenvalues";
        end
        diagnostics.fallback = true;
        diagnostics.fallbackReason = reason;
        diagnostics.matrixFormationMacs = rowCount*columnCount^2;
        diagnostics.evdCubicUnits = columnCount^3;
        [vector, direct] = directVector(aligned, diagnostics, ...
            "gram-fallback-full-covariance-eig");
        diagnostics = direct;
        return;
    end
    vector = aligned*eigenvectors(:, order(1)) ...
        / sqrt(columnCount*maximumEigenvalue);
    vector = vector/norm(vector);
    residual = aligned*(aligned'*vector)/columnCount ...
        - maximumEigenvalue*vector;
    relativeResidual = norm(residual) ...
        / max(maximumEigenvalue*norm(vector), eps);
    if ~all(isfinite(vector)) ...
            || relativeResidual > gramProtocol.residualTolerance
        diagnostics.fallback = true;
        diagnostics.fallbackReason = "nonfinite-or-residual-failure";
        diagnostics.matrixFormationMacs = rowCount*columnCount^2;
        diagnostics.evdCubicUnits = columnCount^3;
        diagnostics.recoveryMacs = 3*rowCount*columnCount;
        [vector, direct] = directVector(aligned, diagnostics, ...
            "gram-fallback-full-covariance-eig");
        diagnostics = direct;
        return;
    end
    diagnostics.method = "smaller-gram-eig-recovery";
    diagnostics.maximumEigenvalue = maximumEigenvalue;
    diagnostics.secondEigenvalue = secondEigenvalue;
    diagnostics.relativeEigengap = relativeEigengap;
    diagnostics.relativeResidual = relativeResidual;
    diagnostics.matrixFormationMacs = rowCount*columnCount^2;
    diagnostics.evdCubicUnits = columnCount^3;
    diagnostics.recoveryMacs = 3*rowCount*columnCount;
    diagnostics.matrixOrder = columnCount;
catch exception
    diagnostics.fallback = true;
    diagnostics.fallbackReason = "gram-exception:"+string(exception.identifier);
    diagnostics.matrixFormationMacs = rowCount*columnCount^2;
    diagnostics.evdCubicUnits = columnCount^3;
    [vector, direct] = directVector(aligned, diagnostics, ...
        "gram-fallback-full-covariance-eig");
    diagnostics = direct;
end
end

function [vector, diagnostics] = directVector(aligned, diagnostics, method)
[rowCount, columnCount] = size(aligned);
covariance = aligned*aligned'/columnCount;
covariance = (covariance+covariance')/2;
[eigenvectors, eigenvalues] = eig(covariance, "vector");
[ordered, order] = sort(real(eigenvalues), "descend");
vector = eigenvectors(:, order(1));
residual = covariance*vector-ordered(1)*vector;
diagnostics.method = method;
diagnostics.maximumEigenvalue = ordered(1);
diagnostics.secondEigenvalue = ordered(min(2, numel(ordered)));
diagnostics.relativeEigengap = (diagnostics.maximumEigenvalue ...
    - diagnostics.secondEigenvalue)/max(diagnostics.maximumEigenvalue, eps);
diagnostics.relativeResidual = norm(residual) ...
    / max(diagnostics.maximumEigenvalue*norm(vector), eps);
diagnostics.matrixFormationMacs = diagnostics.matrixFormationMacs ...
    + columnCount*rowCount^2;
diagnostics.evdCubicUnits = diagnostics.evdCubicUnits+rowCount^3;
diagnostics.matrixOrder = rowCount;
end
