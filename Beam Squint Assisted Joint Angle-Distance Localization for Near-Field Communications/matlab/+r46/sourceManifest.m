function source = sourceManifest(project)
%SOURCEMANIFEST Hash R46 code and all executable dependencies.

arguments
    project (1, 1) string
end

folders = ["+r46", "+r45", "+r41", "+r40", "+r38", "+r37", ...
    "+r34", "+r33", "+r32", "+r31", "+r30", "+fsjad", "+jad"];
paths = strings(0, 1);
for folder = folders
    listing = dir(fullfile(project, folder, "**", "*.m"));
    for index = 1:numel(listing)
        file = string(fullfile(listing(index).folder, listing(index).name));
        relative = extractAfter(file, strlength(project)+1);
        paths(end+1, 1) = replace(relative, string(filesep), "/"); %#ok<AGROW>
    end
end
listing = [dir(fullfile(project, "experiments", "*round46*.m")); ...
    dir(fullfile(project, "tests", "round46*.m"))];
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    relative = extractAfter(file, strlength(project)+1);
    paths(end+1, 1) = replace(relative, string(filesep), "/"); %#ok<AGROW>
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end
