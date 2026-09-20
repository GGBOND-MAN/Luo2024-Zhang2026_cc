function source = manifest(project)
%MANIFEST Hash R57 code and all executable dependencies.

arguments
    project (1, 1) string
end

folders = ["+r57", "+r56", "+r53", "+r51", "+r50", "+r45", ...
    "+r42", "+r41", "+r40", "+r38", "+r37", "+r34", ...
    "+r33", "+r32", "+r31", "+r30", "+fsjad", "+jad"];
paths = strings(0, 1);
for folder = folders
    listing = dir(fullfile(project, folder, "**", "*.m"));
    for index = 1:numel(listing)
        file = string(fullfile(listing(index).folder, listing(index).name));
        relative = extractAfter(file, strlength(project)+1);
        paths(end+1, 1) = replace(relative, string(filesep), "/"); %#ok<AGROW>
    end
end
listing = [dir(fullfile(project, "experiments", "*round57*.m")); ...
    dir(fullfile(project, "tests", "round57*.m"))];
for index = 1:numel(listing)
    file = string(fullfile(listing(index).folder, listing(index).name));
    relative = extractAfter(file, strlength(project)+1);
    paths(end+1, 1) = replace(relative, string(filesep), "/"); %#ok<AGROW>
end
source = fsjad.sourceHashManifest(project, sort(unique(paths)));
end
