function assertFormalExpansionAllowed(selected)
%ASSERTFORMALEXPANSIONALLOWED Reject diagnostic deployments from expansion.

arguments
    selected (1, 1) struct
end

required = ["reason", "formalExpansionAllowed"];
if ~all(isfield(selected, required))
    error("r31:IncompleteExpansionDecision", ...
        "The selection does not contain the Round31 expansion decision fields.");
end
if selected.reason ~= "met-predeclared-engineering-thresholds" ...
        || ~selected.formalExpansionAllowed
    error("r31:DiagnosticExpansionRejected", ...
        "Diagnostic-only deployments cannot be scheduled for formal expansion.");
end
end
