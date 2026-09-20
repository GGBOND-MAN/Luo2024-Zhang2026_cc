function source = manifest(project)
%MANIFEST Hash all MATLAB runtime and experiment sources for strict reuse.
arguments
    project (1,1) string
end
folders = ["+r29","+fsjad","+jad","algorithms","experiments","tests"];
paths = strings(0,1);
for folder = folders
    listing = dir(fullfile(project,folder,"**","*.m"));
    for k = 1:numel(listing)
        full = string(fullfile(listing(k).folder,listing(k).name));
        paths(end+1,1) = replace(extractAfter(full,strlength(project)+1), ...
            string(filesep),"/"); %#ok<AGROW>
    end
end
source = fsjad.sourceHashManifest(project,sort(paths));
end
