function run_round27_convergence_shard(shardId,shardCount,options)
%RUN_ROUND27_CONVERGENCE_SHARD Paired calibration diagnostics with checkpoints.
arguments
    shardId (1,1) double {mustBeInteger,mustBePositive}
    shardCount (1,1) double {mustBeInteger,mustBePositive}
    options.CountPerSnr (1,1) double {mustBeInteger,mustBePositive} = 10
    options.NumWorkers (1,1) double {mustBeInteger,mustBePositive} = 8
    options.BatchSize (1,1) double {mustBeInteger,mustBePositive} = 8
    options.PoolType (1,1) string {mustBeMember(options.PoolType,["Threads","Processes"])} = "Threads"
    options.Protocol (1,1) string {mustBeMember(options.Protocol,["formal","smoke"])} = "formal"
    options.OutputRoot (1,1) string = ""
end
assert(shardId<=shardCount,"fsjad:Round27ShardId");
project=string(fileparts(fileparts(mfilename('fullpath'))));
originalPath=path;
addpath(project);
cleanup=onCleanup(@() path(originalPath));
setup=fsjad.round27Setup(project,options.CountPerSnr,options.Protocol);
if options.Protocol=="formal"
    passFile=fullfile(project,"results","full_spectrum", ...
        "round27_preflight","preflight_passed.mat");
    assert(isfile(passFile),"fsjad:Round27PreflightRequired", ...
        "Run preflight_round27 successfully on this server first.");
    passed=load(passFile,"source");
    assert(isequal(passed.source,setup.source),"fsjad:Round27PreflightStale", ...
        "Source changed after preflight. Run preflight_round27 again.");
end
setup.protocol.shardCount=shardCount;
rows=mod(setup.design.trialIndex-1,shardCount)==shardId-1;
design=setup.design(rows,:);
assert(~isempty(design),"fsjad:Round27EmptyShard");
if options.OutputRoot==""
    assert(options.Protocol=="formal","fsjad:Round27SmokeOutput");
    folderName=sprintf('round27_v3_%04d_per_snr',options.CountPerSnr);
    root=fullfile(project,"results","full_spectrum",folderName);
else
    root=options.OutputRoot;
end
folder=fullfile(root,sprintf('shard_%02d_of_%02d',shardId,shardCount));
if ~isfolder(folder)
    mkdir(folder);
end
checkpoint=fullfile(folder,"checkpoint.mat");
results=cell(height(design),1);
if isfile(checkpoint)
    saved=load(checkpoint);
    assert(isequaln(saved.setup,setup) && isequal(saved.design,design) ...
        && saved.shardId==shardId,"fsjad:Round27CheckpointMismatch", ...
        "Source, data, or settings changed. Do not mix checkpoints.");
    results=saved.results;
end
environment.matlabVersion=version;
environment.computer=computer;
environment.numWorkers=options.NumWorkers;
environment.poolType=options.PoolType;
environment.timestamp=string(datetime('now'));
environment.hostName=string(getenv('COMPUTERNAME'));
if environment.hostName==""
    environment.hostName=string(getenv('HOSTNAME'));
end
scan=fsjad.prepareScan(setup.cfg);
pool=gcp('nocreate');
if isempty(pool)
    pool=parpool(options.PoolType,options.NumWorkers);
elseif pool.NumWorkers~=options.NumWorkers
    warning('fsjad:Round27ExistingPool', ...
        'Using existing pool with %d workers.',pool.NumWorkers);
end
environment.numWorkers=pool.NumWorkers;
environment.actualPoolClass=class(pool);
pending=find(cellfun(@isempty,results));
timer=tic;
for start=1:options.BatchSize:numel(pending)
    batchRows=pending(start:min(start+options.BatchSize-1,numel(pending)));
    batchDesign=design(batchRows,:);
    batch=cell(numel(batchRows),1);
    parfor i=1:numel(batchRows)
        batch{i}=fsjad.round27Trial(setup,scan,batchDesign(i,:));
    end
    results(batchRows)=batch;
    save(checkpoint+".next.mat","setup","design","results", ...
        "shardId","environment",'-v7.3');
    movefile(checkpoint+".next.mat",checkpoint,'f');
    completed=sum(~cellfun(@isempty,results));
    fprintf('R27 shard %d/%d: %d/%d, session %.2f h\n', ...
        shardId,shardCount,completed,height(design),toc(timer)/3600);
end
save(fullfile(folder,"shard_result.mat"),"setup","design","results", ...
    "shardId","environment",'-v7.3');
successful=cellfun(@(r) r.success,results);
failureTable=design(~successful,:);
failureTable.errorIdentifier=string(cellfun(@(item) item.errorIdentifier, ...
    results(~successful),'UniformOutput',false));
failureTable.errorMessage=string(cellfun(@(r) r.errorMessage, ...
    results(~successful),'UniformOutput',false));
writetable(failureTable,fullfile(folder,"failures.csv"));
assert(all(successful),"fsjad:Round27TrialFailure", ...
    "Trials failed; inspect failures.csv. No trials may be silently removed.");
marker=table(string(setup.protocol.version),shardId,shardCount, ...
    options.CountPerSnr,height(design), ...
    'VariableNames',{'protocolVersion','shardId','shardCount', ...
    'countPerSnr','completedRows'});
writetable(marker,fullfile(folder,"COMPLETE.csv"));
fprintf('ROUND27_SHARD_COMPLETE %s\n',folder);
end
