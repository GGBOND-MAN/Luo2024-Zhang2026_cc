function [subset, columnIndex] = subsetState(state, carrierIndex)
%SUBSETSTATE Select an exact carrier subset and preserve vector columns.

arguments
    state (1, 1) struct
    carrierIndex (:, 1) double {mustBeInteger, mustBeNonnegative}
end

[isMember, columnIndex] = ismember(carrierIndex, state.carrierIndex);
if ~all(isMember)
    error("r31:CarrierSubsetViolation", ...
        "Every reduced carrier must be present in the full-carrier state.");
end
subset = state;
subset.signalVectors = state.signalVectors(:, columnIndex);
subset.carrierIndex = state.carrierIndex(columnIndex);
subset.frequencyHz = state.frequencyHz(columnIndex);
end
