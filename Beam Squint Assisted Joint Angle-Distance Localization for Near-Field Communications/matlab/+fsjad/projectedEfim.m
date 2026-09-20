function information = projectedEfim(q, derivative, beta, noiseVariance, nuisanceBasis)
%PROJECTEDEFIM Localization EFIM after eliminating complex nuisance terms.

arguments
    q (:, 1) double
    derivative (:, 2) double
    beta double
    noiseVariance (1, 1) double {mustBeFinite, mustBePositive}
    nuisanceBasis double = q
end

numObservations = numel(q);
if size(derivative, 1) ~= numObservations
    error("fsjad:projectedEfim:SizeMismatch", ...
        "The response and derivative must have the same number of rows.");
end
if size(nuisanceBasis, 1) ~= numObservations
    error("fsjad:projectedEfim:NuisanceSizeMismatch", ...
        "The nuisance basis must have one row per observation.");
end
if ~(isscalar(beta) || isequal(size(beta), [numObservations, 1]))
    error("fsjad:projectedEfim:GainSizeMismatch", ...
        "The gain must be scalar or one complex gain per observation.");
end

signalDerivative = beta .* derivative;
projectedDerivative = signalDerivative ...
    - nuisanceBasis * (pinv(nuisanceBasis) * signalDerivative);
information = 2 / noiseVariance ...
    * real(signalDerivative' * projectedDerivative);
information = (information + information.') / 2;
end
