function output = preflight_round57_coherent_range()
%PREFLIGHT_ROUND57_COHERENT_RANGE Static-check and unit-test R57 without trials.
%   Run this before any R57 stage. It adds the frozen non-package folders,
%   runs checkcode over every R57 file, and runs the R57 unit tests by full
%   path. Tests in this project are never on the MATLAB path, so calling
%   runtests with a bare class name always fails.

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);

files = [dir(fullfile(project, "+r57", "*.m")); ...
    dir(fullfile(project, "experiments", "*round57*.m")); ...
    dir(fullfile(project, "tests", "round57*.m"))];
static = table('Size', [0, 4], ...
    'VariableTypes', {'string', 'double', 'string', 'string'}, ...
    'VariableNames', {'file', 'line', 'identifier', 'message'});
for index = 1:numel(files)
    file = fullfile(files(index).folder, files(index).name);
    messages = checkcode(file, "-struct", "-id");
    for messageIndex = 1:numel(messages)
        entry = table(string(files(index).name), ...
            messages(messageIndex).line, ...
            string(messages(messageIndex).id), ...
            string(messages(messageIndex).message), ...
            'VariableNames', static.Properties.VariableNames);
        static = [static; entry]; %#ok<AGROW>
    end
end
% Any checkcode message blocks. An earlier version filtered on a hand-picked
% list of identifiers and reported "0 syntax faults" while fromFront.m was
% broken: checkcode had flagged FVSOR (arguments block does not match the
% function line) and the filter dropped it. R57 code is expected to be
% checkcode-clean, so the threshold is zero and nothing is filtered.
fprintf("R57 preflight: %d checkcode messages (threshold 0)\n", height(static));
if ~isempty(static)
    disp(static);
    error("r57:StaticAnalysisNotClean", ...
        "Resolve all %d checkcode messages before running any R57 stage.", ...
        height(static));
end

unitResults = runtests(fullfile(project, "tests", ...
    "round57CoherentRangeTest.m"));
output = struct(version="R57-preflight-v1", ...
    project=project, static=static, unitResults=unitResults, ...
    passed=all([unitResults.Passed]), ...
    timestamp=string(datetime("now", "TimeZone", "Asia/Shanghai")));
fprintf("ROUND57_PREFLIGHT passed=%d tests=%d\n", ...
    output.passed, numel(unitResults));
end
