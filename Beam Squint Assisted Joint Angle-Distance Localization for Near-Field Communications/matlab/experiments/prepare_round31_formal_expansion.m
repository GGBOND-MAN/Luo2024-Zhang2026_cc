function prepare_round31_formal_expansion(options)
%PREPARE_ROUND31_FORMAL_EXPANSION Enforce the development-to-formal gate.

arguments
    options.SelectionFile (1, 1) string = ""
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
if options.SelectionFile == ""
    options.SelectionFile = fullfile(project, "results", "full_spectrum", ...
        "round31_legacy_reanalysis_v2", "selection.mat");
end
saved = load(options.SelectionFile, "selected");
r31.assertFormalExpansionAllowed(saved.selected);
error("r31:ExpansionNotAuthorized", ...
    ["The software gate passed, but this Round31 task does not authorize " ...
    "a 600-user or new-user expansion."]);
end
