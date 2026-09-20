function output = assertAuthorized(project, identity)
%ASSERTAUTHORIZED Validate the immutable manual-run authorization.

arguments
    project (1, 1) string
    identity (1, 1) struct
end

locations = r55.paths(project);
if ~isfile(locations.authorizationFile)
    error("r55:FinalNotAuthorized", ...
        "R55 final is locked and requires explicit manual authorization.");
end
saved = load(locations.authorizationFile, "authorization");
output = saved.authorization;
if ~output.approved ...
        || output.designHash ~= identity.designHash ...
        || output.statisticsHash ~= identity.statisticsHash ...
        || output.sourceDigest ~= identity.sourceDigest
    error("r55:AuthorizationIdentityMismatch", ...
        "The R55 authorization does not match the locked package.");
end
end
