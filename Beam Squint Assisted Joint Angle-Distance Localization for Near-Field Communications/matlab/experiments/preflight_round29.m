function preflight_round29()
%PREFLIGHT_ROUND29 Execute required tests and persist the source-bound results.
project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
files = [dir(fullfile(project,"+r29","*.m")); ...
    dir(fullfile(project,"experiments","*round29*.m")); ...
    dir(fullfile(project,"tests","round29*.m"))];
static = table();
for k = 1:numel(files)
    name = fullfile(files(k).folder,files(k).name);
    messages = checkcode(name,"-struct");
    for j = 1:numel(messages)
        static = [static;table(string(name),messages(j).line, ...
            string(messages(j).message),'VariableNames',{'file','line','message'})]; %#ok<AGROW>
    end
end
testResults = runtests(fullfile(project,"tests"));
source = r29.manifest(project);
root = fullfile(project,"results","full_spectrum","round29_preflight_v1");
if ~isfolder(root), mkdir(root); end
save(fullfile(root,"preflight.mat"),"testResults","source","static","-v7.3");
writetable(static,fullfile(root,"static_analysis.csv"));
writetable(source,fullfile(root,"source_hashes.csv"));
fprintf("R29 TESTS passed=%d failed=%d incomplete=%d static=%d\n", ...
    nnz([testResults.Passed]),nnz([testResults.Failed]),nnz([testResults.Incomplete]),height(static));
assert(all([testResults.Passed]),"r29:PreflightFailed");
end
