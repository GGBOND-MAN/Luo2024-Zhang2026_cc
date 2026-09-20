function source = manifest(project)
%MANIFEST Hash Round32 sources and inherited executable dependencies.

arguments
    project (1, 1) string
end

folders = ["+r32", "+r31", "+r30", "+r29", "+fsjad", "+jad"];
paths = strings(0, 1);
for folder = folders
    listing = dir(fullfile(project, folder, "**", "*.m"));
    paths = append(paths, listing, project);
end
listing = [dir(fullfile(project, "experiments", "*round32*.m")); ...
    dir(fullfile(project, "tests", "round32*.m"))];
paths = append(paths, listing, project);
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end

function paths = append(paths, listing, project)
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    relative = extractAfter(file, strlength(project)+1);
    paths(end+1, 1) = replace(relative, string(filesep), "/"); %#ok<AGROW>
end
end
