function source = sourceManifest(project)
%SOURCEMANIFEST Extend the unchanged v1 source with isolated v2 overlays.

arguments
    project (1, 1) string
end

v1Source = r41.sourceManifest(project);
listing = [dir(fullfile(project, "+r41statsv2", "*.m")); ...
    dir(fullfile(project, "experiments", "*r41v2*.m")); ...
    dir(fullfile(project, "tests", "r41v2*.m"))];
paths = v1Source.path;
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    paths(end+1, 1) = replace( ...
        extractAfter(file, strlength(project)+1), ...
        string(filesep), "/"); %#ok<AGROW>
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end
