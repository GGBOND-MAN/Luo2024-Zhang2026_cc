function authorization = assertFinalTestAuthorized(packageFolder, identity)
%ASSERTFINALTESTAUTHORIZED Refuse final trials until explicit approval exists.

arguments
    packageFolder (1, 1) string
    identity (1, 1) struct
end

file = fullfile(packageFolder, "FINAL_TEST_AUTHORIZATION.mat");
if ~isfile(file)
    error("r32:FinalTestNotAuthorized", ...
        "The 1400-trial final test is intentionally locked. " + ...
        "Run no final shard until the user explicitly confirms it.");
end
saved = load(file, "authorization");
authorization = saved.authorization;
required = ["approved", "designHash", "sourceDigest", "protocolVersion"];
if ~all(isfield(authorization, required)) ...
        || ~authorization.approved ...
        || authorization.designHash ~= identity.designHash ...
        || authorization.sourceDigest ~= identity.sourceDigest ...
        || authorization.protocolVersion ~= identity.protocol.version
    error("r32:FinalAuthorizationIdentityMismatch", ...
        "The authorization does not match this exact design and source identity.");
end
end
