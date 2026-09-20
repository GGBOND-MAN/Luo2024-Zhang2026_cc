function source = sourceManifest(project)
%SOURCEMANIFEST Hash R41 orchestration, tests, and frozen dependencies.

arguments
    project (1, 1) string
end

folders = ["+r29"; "+r30"; "+r31"; "+r32"; "+r33"; ...
    "+r34"; "+r35"; "+r36"; "+r37"; "+r38"; "+r39"; ...
    "+r40"; "+r41"; "+fsjad"; "+jad"];
source = r41.folderManifest(project, folders);
listing = [dir(fullfile(project, "experiments", "*round41*.m")); ...
    dir(fullfile(project, "tests", "round41*.m"))];
paths = source.path;
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    paths(end+1, 1) = replace( ...
        extractAfter(file, strlength(project)+1), ...
        string(filesep), "/"); %#ok<AGROW>
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end
