function assertIdentity(saved, expected)
%ASSERTIDENTITY Refuse stale completion markers and checkpoints.
arguments
    saved (1,1) struct
    expected (1,1) struct
end
assert(isequaln(saved,expected),"r29:IdentityMismatch", ...
    "Version, configuration, design, data, source, or shard changed; use a new directory.");
end
