function subset = subsetResponseContext(context, carrierColumn)
%SUBSETRESPONSECONTEXT Select carriers without rebuilding invariants.

arguments
    context (1, 1) struct
    carrierColumn (:, 1) double {mustBeInteger, mustBePositive}
end

if any(carrierColumn > context.carrierCount)
    error("r33:ResponseSubsetIndex", ...
        "A response-context carrier column is out of range.");
end
subset = context;
subset.wavenumber = context.wavenumber(carrierColumn);
subset.conjugateBeamformer = context.conjugateBeamformer(:, carrierColumn);
subset.observation = context.observation(carrierColumn);
subset.observationEnergy = real(subset.observation'*subset.observation);
subset.carrierCount = numel(carrierColumn);
end
