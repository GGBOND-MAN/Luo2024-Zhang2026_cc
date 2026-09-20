function manifest = v1ArtifactManifest(project)
%V1ARTIFACTMANIFEST Hash the permanently archived v1 protocol artifacts.

arguments
    project (1, 1) string
end

v1 = r41.paths(project);
relative = [replace(extractAfter(v1.protocolFile, ...
    strlength(project)+1), string(filesep), "/"); ...
    replace(extractAfter(v1.designFile, ...
    strlength(project)+1), string(filesep), "/")];
manifest = fsjad.sourceHashManifest(project, relative);
end
