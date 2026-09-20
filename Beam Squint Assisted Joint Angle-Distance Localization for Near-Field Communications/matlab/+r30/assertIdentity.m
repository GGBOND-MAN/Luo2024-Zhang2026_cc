function assertIdentity(actual, expected)
%ASSERTIDENTITY Reject stale checkpoints and mixed protocols.

arguments
    actual (1, 1) struct
    expected (1, 1) struct
end

if ~isequaln(actual, expected)
    error("r30:IdentityMismatch", ...
        "The saved result does not match the current design and source identity.");
end
end
