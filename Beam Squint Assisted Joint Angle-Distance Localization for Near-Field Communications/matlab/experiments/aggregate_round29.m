function aggregate_round29(mode)
%AGGREGATE_ROUND29 Validate exact design coverage and summarize without exclusions.
arguments
    mode (1,1) string {mustBeMember(mode,["pilot","calibration600"])} = "pilot"
end
project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
expected = r29.setup(project,mode);
root = fullfile(project,"results","full_spectrum","round29_"+mode+"_v1");
listing = dir(fullfile(root,"shard_*","result.mat"));
assert(~isempty(listing),"r29:NoShards");
design = table(); results = cell(0,1); seen = [];
environments = cell(numel(listing),1);
for j = 1:numel(listing)
    folder = string(listing(j).folder);
    saved = load(fullfile(folder,"result.mat"));
    marker = load(fullfile(folder,"COMPLETE.mat"));
    r29.assertIdentity(marker.identity,saved.identity);
    r29.assertIdentity(saved.identity.setup,expected);
    rows = (saved.identity.shardId:saved.identity.shardCount:height(expected.design)).';
    assert(isequaln(saved.identity.design,expected.design(rows,:)),"r29:ShardDesign");
    assert(numel(saved.results)==numel(rows),"r29:IncompleteRows");
    design = [design;saved.identity.design]; %#ok<AGROW>
    results = [results;saved.results]; %#ok<AGROW>
    seen(end+1) = saved.identity.shardId; %#ok<AGROW>
    environments{j} = saved.environment;
end
assert(isequal(sort(seen),1:saved.identity.shardCount),"r29:ShardCoverage");
[design,order] = sortrows(design,["snrDb","trialIndex"]);
results = results(order);
assert(isequaln(design,expected.design),"r29:ExactDesignCoverage");
folder = fullfile(root,"aggregate");
if ~isfolder(folder), mkdir(folder); end
success = cellfun(@(r)r.success,results);
writetable(design(~success,:),fullfile(folder,"failed_rows.csv"));
source = expected.source;
accepted = false;
if ~all(success)
    save(fullfile(folder,"acceptance.mat"),"source","accepted");
    error("r29:FailedRows","Failures retained; no complete-case performance table produced.");
end
[methods,paired] = r29.statistics(design,results,expected.protocol);
resources = table(); boundaries = table();
for k = 1:numel(results)
    r = results{k}; c = r.front.cost;
    entry = table(design.seed(k),design.snrDb(k),r.front.totalEvaluations, ...
        c.candidateEvaluations,c.stageOneEvaluations,c.profileEvaluations, ...
        sum(c.finalEvaluations),c.diagnosticEvaluations,r.front.runtimeSeconds, ...
        c.candidateSeconds,c.stageOneSeconds,c.profileSeconds,sum(c.finalSeconds), ...
        r.cost.musicSeconds,r.cost.totalSeconds,r.front.selected.converged, ...
        r.front.selected.stationarity, ...
        'VariableNames',{'seed','snrDb','frontResponseEvaluations','candidateEvaluations', ...
        'stageOneEvaluations','frontProfileEvaluations','finalEvaluations', ...
        'diagnosticEvaluations','frontSeconds','candidateSeconds','stageOneSeconds', ...
        'profileSeconds','finalSeconds','musicSeconds','totalSeconds', ...
        'frontStationary','stationarity'});
    resources = [resources;entry]; %#ok<AGROW>
    names = string(fieldnames(r.solvers));
    for name = names.'
        s = r.solvers.(name);
        entry = table(design.seed(k),design.snrDb(k),name,s.evaluationCount, ...
            s.boundary,s.outwardTrend,s.status,s.intervalM(1),s.intervalM(2), ...
            'VariableNames',{'seed','snrDb','method','evaluations','boundary', ...
            'outward','status','lowerM','upperM'});
        boundaries = [boundaries;entry]; %#ok<AGROW>
    end
end
accepted = all(success) && all(resources.frontStationary);
if mode=="pilot"
    replayCheck = load(fullfile(root,"replay_check.mat"));
    r29.assertIdentity(replayCheck.identity.setup,expected);
    accepted = accepted && replayCheck.passed;
end
% Finite sensitivity is a diagnostic prerequisite, not a performance superiority gate.
sensitivityFile = fullfile(project,"results","full_spectrum", ...
    "round29_sensitivity_v1","result.mat");
assert(isfile(sensitivityFile),"r29:MissingFiniteSensitivity");
sensitivity = load(sensitivityFile,"identity");
assert(isequaln(sensitivity.identity.source,source),"r29:StaleSensitivity");
writetable(methods,fullfile(folder,"method_summary.csv"));
writetable(paired,fullfile(folder,"paired_summary.csv"));
writetable(resources,fullfile(folder,"resources.csv"));
writetable(boundaries,fullfile(folder,"boundary_and_cost.csv"));
writetable(design,fullfile(folder,"seed_list.csv"));
writetable(source,fullfile(folder,"source_hashes.csv"));
save(fullfile(folder,"aggregate.mat"),"expected","design","results","methods","paired", ...
    "resources","boundaries","environments","-v7.3");
save(fullfile(folder,"acceptance.mat"),"source","accepted","expected");
fprintf("ROUND29_AGGREGATE_COMPLETE mode=%s numericalAccepted=%d\n",mode,accepted);
end
