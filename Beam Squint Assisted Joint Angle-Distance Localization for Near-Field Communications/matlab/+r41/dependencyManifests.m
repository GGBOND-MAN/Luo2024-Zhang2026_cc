function output = dependencyManifests(project)
%DEPENDENCYMANIFESTS Freeze R33, R34, and all transitive estimator sources.

arguments
    project (1, 1) string
end

output.r33 = r41.folderManifest(project, "+r33");
output.r34 = r41.folderManifest(project, "+r34");
folders = ["+r29"; "+r30"; "+r31"; "+r32"; "+r33"; ...
    "+r34"; "+r35"; "+r36"; "+r37"; "+r38"; "+r39"; ...
    "+fsjad"; "+jad"];
output.all = r41.folderManifest(project, folders);
end
