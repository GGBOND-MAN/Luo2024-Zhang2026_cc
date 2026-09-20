function source = folderManifest(project, folders)
%FOLDERMANIFEST Hash all MATLAB sources under declared relative folders.

arguments
    project (1, 1) string
    folders (:, 1) string
end

paths = strings(0, 1);
for folder = folders.'
    listing = dir(fullfile(project, folder, "**", "*.m"));
    for index = 1:numel(listing)
        file = string(fullfile(listing(index).folder, listing(index).name));
        paths(end+1, 1) = replace( ...
            extractAfter(file, strlength(project)+1), ...
            string(filesep), "/"); %#ok<AGROW>
    end
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end
