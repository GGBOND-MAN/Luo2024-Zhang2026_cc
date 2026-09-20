function addPaths(project)
%ADDPATHS Add frozen non-package implementation folders required by R41.

arguments
    project (1, 1) string
end

addpath(project);
addpath(fullfile(project, "+r35", "common"));
addpath(fullfile(project, "+r36", "common"));
addpath(fullfile(project, "+r37", "singleProfile"));
addpath(fullfile(project, "+r38", "common"));
addpath(fullfile(project, "+r38", "schemeF"));
addpath(fullfile(project, "+r40", "schemeG"));
end
