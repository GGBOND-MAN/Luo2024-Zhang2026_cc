function source = manifest(project)
%MANIFEST Hash all sources that can affect Round30 outputs.

arguments
    project (1, 1) string
end

folders = ["+r30", "+r29", "+fsjad", "+jad", ...
    "algorithms", "experiments", "tests"];
paths = strings(0, 1);
for folder = folders
    listing = dir(fullfile(project, folder, "**", "*.m"));
    for index = 1:numel(listing)
        file = string(fullfile(listing(index).folder, listing(index).name));
        relative = extractAfter(file, strlength(project) + 1);
        paths(end+1, 1) = replace(relative, string(filesep), "/"); %#ok<AGROW>
    end
end
source = fsjad.sourceHashManifest(project, sort(paths));
end
