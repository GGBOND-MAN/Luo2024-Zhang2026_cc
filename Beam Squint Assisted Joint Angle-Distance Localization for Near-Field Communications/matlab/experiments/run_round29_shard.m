function run_round29_shard(shardId, shardCount, options)
%RUN_ROUND29_SHARD Run the one 60-user pilot or saved 600-user mechanism audit.
arguments
    shardId (1,1) double {mustBeInteger,mustBePositive}
    shardCount (1,1) double {mustBeInteger,mustBePositive}
    options.Mode (1,1) string {mustBeMember(options.Mode,["pilot","calibration600"])} = "pilot"
    options.NumWorkers (1,1) double {mustBeInteger,mustBePositive} = 8
    options.BatchSize (1,1) double {mustBeInteger,mustBePositive} = 8
end
assert(shardId<=shardCount,"r29:InvalidShard");
project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
setup = r29.setup(project,options.Mode);
passed = load(fullfile(project,"results","full_spectrum","round29_preflight_v1","preflight.mat"));
assert(isequaln(passed.source,setup.source) && all([passed.testResults.Passed]),"r29:StalePreflight");
base = fullfile(project,"results","full_spectrum");
finite = load(fullfile(base,"round29_sensitivity_v1","result.mat"),"identity");
assert(isequaln(finite.identity.source,setup.source),"r29:StaleFiniteAudit");
if options.Mode=="calibration600"
    gate = load(fullfile(base,"round29_pilot_v1","aggregate","acceptance.mat"));
    assert(gate.accepted,"r29:PilotNotAccepted");
    assert(isequaln(gate.source,setup.source),"r29:StalePilotGate");
    assert(isequaln(gate.expected.cfg,setup.cfg) ...
        && isequaln(gate.expected.algorithm,setup.algorithm) ...
        && isequaln(gate.expected.protocol,setup.protocol) ...
        && isequaln(gate.expected.dataHash,setup.dataHash),"r29:PilotProtocolMismatch");
end
root = fullfile(base,"round29_"+options.Mode+"_v1", ...
    sprintf("shard_%02d_of_%02d",shardId,shardCount));
if ~isfolder(root), mkdir(root); end
rows = (shardId:shardCount:height(setup.design)).';
design = setup.design(rows,:);
identity = struct(setup=setup,design=design,shardId=shardId,shardCount=shardCount);
checkpoint = fullfile(root,"checkpoint.mat");
results = cell(height(design),1);
if isfile(checkpoint)
    saved = load(checkpoint);
    r29.assertIdentity(saved.identity,identity);
    results = saved.results;
end
pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers~=options.NumWorkers, delete(pool); pool=[]; end
if isempty(pool), pool=parpool("Threads",options.NumWorkers); end
environment = struct(matlabVersion=version,computer=computer,workers=pool.NumWorkers, ...
    requestedWorkers=options.NumWorkers,poolClass=class(pool),timestamp=string(datetime("now")));
cfg = setup.cfg;
algorithm = setup.algorithm;
protocol = setup.protocol;
scan = fsjad.prepareScan(cfg);
pending = find(cellfun(@isempty,results));
sessionTimer = tic;
for first = 1:options.BatchSize:numel(pending)
    taskRows = pending(first:min(first+options.BatchSize-1,numel(pending)));
    batchDesign = design(taskRows,:);
    batch = cell(numel(taskRows),1);
    parfor j = 1:numel(taskRows)
        batch{j} = r29.trial(cfg,algorithm,protocol,scan,batchDesign(j,:));
    end
    results(taskRows) = batch;
    save(checkpoint,"identity","results","environment","-v7.3");
    fprintf("R29 %s shard %d: %d/%d session %.2f h\n",options.Mode,shardId, ...
        nnz(~cellfun(@isempty,results)),height(design),toc(sessionTimer)/3600);
end
save(fullfile(root,"result.mat"),"identity","results","environment","-v7.3");
writetable(design,fullfile(root,"seed_list.csv"));
writetable(setup.source,fullfile(root,"source_hashes.csv"));
failed = ~cellfun(@(s)s.success,results);
failures = design(failed,:);
failures.errorMessage = string(cellfun(@(s)s.errorMessage,results(failed),UniformOutput=false));
writetable(failures,fullfile(root,"failures.csv"));
% Completion is coverage only; failed rows remain and prevent acceptance.
save(fullfile(root,"COMPLETE.mat"),"identity","failed");
fprintf("ROUND29_SHARD_COMPLETE failures=%d\n",nnz(failed));
end
