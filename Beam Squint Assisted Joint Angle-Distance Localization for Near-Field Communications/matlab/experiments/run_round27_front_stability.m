function run_round27_front_stability(options)
%RUN_ROUND27_FRONT_STABILITY Compare 200/400 front-end continuations.
arguments
    options.CountPerSnr (1,1) double {mustBeInteger,mustBePositive} = 10
    options.NumWorkers (1,1) double {mustBeInteger,mustBePositive} = 8
    options.BatchSize (1,1) double {mustBeInteger,mustBePositive} = 8
    options.PoolType (1,1) string {mustBeMember(options.PoolType, ...
        ["Threads","Processes"])} = "Threads"
    options.OutputRoot (1,1) string = ""
end

project=string(fileparts(fileparts(mfilename('fullpath'))));
originalPath=path;
addpath(project);
cleanup=onCleanup(@() path(originalPath));
setup=fsjad.round27Setup(project,options.CountPerSnr,"formal");
passFile=fullfile(project,"results","full_spectrum", ...
    "round27_preflight","preflight_passed.mat");
assert(isfile(passFile),"fsjad:Round27PreflightRequired", ...
    "Run preflight_round27 successfully on this server first.");
passed=load(passFile,"source");
assert(isequal(passed.source,setup.source),"fsjad:Round27PreflightStale", ...
    "Source changed after preflight. Run preflight_round27 again.");

if options.OutputRoot==""
    folderName=sprintf('round27_front_stability_%04d_per_snr', ...
        options.CountPerSnr);
    root=fullfile(project,"results","full_spectrum",folderName);
else
    root=options.OutputRoot;
end
if ~isfolder(root)
    mkdir(root);
end
checkpoint=fullfile(root,"checkpoint.mat");
design=setup.design;
results=cell(height(design),1);
if isfile(checkpoint)
    saved=load(checkpoint);
    assert(isequaln(saved.setup,setup) && isequal(saved.design,design), ...
        "fsjad:Round27StabilityCheckpointMismatch", ...
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
for first=1:options.BatchSize:numel(pending)
    batchRows=pending(first:min(first+options.BatchSize-1,numel(pending)));
    batchDesign=design(batchRows,:);
    batch=cell(numel(batchRows),1);
    parfor index=1:numel(batchRows)
        batch{index}=stabilityTrial(setup,scan,batchDesign(index,:));
    end
    results(batchRows)=batch;
    save(checkpoint+".next.mat","setup","design","results", ...
        "environment",'-v7.3');
    movefile(checkpoint+".next.mat",checkpoint,'f');
    fprintf('R27 front stability: %d/%d, session %.2f h\n', ...
        sum(~cellfun(@isempty,results)),height(design),toc(timer)/3600);
end

save(fullfile(root,"front_stability_result.mat"),"setup","design", ...
    "results","environment",'-v7.3');
successful=cellfun(@(item) item.success,results);
failures=design(~successful,:);
failures.errorIdentifier=string(cellfun(@(item) item.errorIdentifier, ...
    results(~successful),'UniformOutput',false));
failures.errorMessage=string(cellfun(@(item) item.errorMessage, ...
    results(~successful),'UniformOutput',false));
writetable(failures,fullfile(root,"failures.csv"));
assert(all(successful),"fsjad:Round27StabilityTrialFailure", ...
    "Trials failed; inspect failures.csv. No trials may be silently removed.");

trials=makeTrialTable(design,results);
summary=makeSummary(trials);
writetable(trials,fullfile(root,"stability_trials.csv"));
writetable(summary,fullfile(root,"stability_summary.csv"));
marker=table(string(setup.protocol.version),options.CountPerSnr,height(design), ...
    sum(trials.numericallyStable), ...
    'VariableNames',{'protocolVersion','countPerSnr','completedRows', ...
    'numericallyStableRows'});
writetable(marker,fullfile(root,"COMPLETE.csv"));
disp(summary);
fprintf('ROUND27_FRONT_STABILITY_COMPLETE %s\n',root);
end

function result=stabilityTrial(setup,scan,row)
result.success=false;
result.errorIdentifier="";
result.errorMessage="";
result.errorReport="";
try
    cfg=setup.cfg;
    q=fsjad.exactSpectralResponse(cfg,deg2rad(row.truthThetaDeg), ...
        row.truthRangeM,scan);
    stream=RandStream("mt19937ar",Seed=row.seed);
    variance=mean(abs(q).^2)/10^(row.snrDb/10);
    beta=exp(1i*2*pi*rand(stream));
    observation=beta*q+sqrt(variance/2)*( ...
        randn(stream,cfg.numSubcarriers,1)+ ...
        1i*randn(stream,cfg.numSubcarriers,1));
    legacy=fsjad.angleMultistartProfileEstimate(cfg,observation,scan, ...
        setup.zhang.frontOffsetsDeg);
    short=fsjad.convergedFrontEstimate(cfg,observation,scan,legacy, ...
        MaxIterations=setup.protocol.maxIterations, ...
        StepTolerance=setup.protocol.stepTolerance);
    long=fsjad.convergedFrontEstimate(cfg,observation,scan,legacy, ...
        MaxIterations=setup.protocol.stabilityMaxIterations, ...
        StepTolerance=setup.protocol.stepTolerance);
    result.legacy=legacy;
    result.short=short;
    result.long=long;
    result.scoreDifference=abs(short.score-long.score);
    result.thetaDifferenceDeg=abs(short.thetaDeg-long.thetaDeg);
    result.rangeDifferenceM=abs(short.rangeM-long.rangeM);
    result.numericallyStable=short.converged && long.converged ...
        && short.score>=legacy.score-setup.protocol.stabilityScoreTolerance ...
        && long.score>=legacy.score-setup.protocol.stabilityScoreTolerance ...
        && result.scoreDifference<=setup.protocol.stabilityScoreTolerance ...
        && result.thetaDifferenceDeg<=setup.protocol.stabilityThetaToleranceDeg ...
        && result.rangeDifferenceM<=setup.protocol.stabilityRangeToleranceM ...
        && short.stationarity<=setup.protocol.stepTolerance ...
        && long.stationarity<=setup.protocol.stepTolerance;
    result.success=true;
catch exception
    result.errorIdentifier=string(exception.identifier);
    result.errorMessage=string(exception.message);
    result.errorReport=string(getReport(exception,'extended','hyperlinks','off'));
end
end

function trials=makeTrialTable(design,results)
legacy=cellfun(@(item) item.legacy,results,'UniformOutput',false);
short=cellfun(@(item) item.short,results,'UniformOutput',false);
long=cellfun(@(item) item.long,results,'UniformOutput',false);
trials=design;
trials.legacyThetaDeg=cellfun(@(item) item.thetaDeg,legacy);
trials.legacyRangeM=cellfun(@(item) item.rangeM,legacy);
trials.shortThetaDeg=cellfun(@(item) item.thetaDeg,short);
trials.shortRangeM=cellfun(@(item) item.rangeM,short);
trials.longThetaDeg=cellfun(@(item) item.thetaDeg,long);
trials.longRangeM=cellfun(@(item) item.rangeM,long);
trials.legacyAngleErrorDeg=trials.legacyThetaDeg-trials.truthThetaDeg;
trials.legacyRangeErrorM=trials.legacyRangeM-trials.truthRangeM;
trials.shortAngleErrorDeg=trials.shortThetaDeg-trials.truthThetaDeg;
trials.shortRangeErrorM=trials.shortRangeM-trials.truthRangeM;
trials.longAngleErrorDeg=trials.longThetaDeg-trials.truthThetaDeg;
trials.longRangeErrorM=trials.longRangeM-trials.truthRangeM;
trials.legacyConverged=cellfun(@(item) item.converged,legacy);
trials.shortConverged=cellfun(@(item) item.converged,short);
trials.longConverged=cellfun(@(item) item.converged,long);
trials.shortStatus=string(cellfun(@(item) item.status,short, ...
    'UniformOutput',false));
trials.longStatus=string(cellfun(@(item) item.status,long, ...
    'UniformOutput',false));
trials.shortStationarity=cellfun(@(item) item.stationarity,short);
trials.longStationarity=cellfun(@(item) item.stationarity,long);
trials.shortIterations=cellfun(@(item) item.iterations,short);
trials.longIterations=cellfun(@(item) item.iterations,long);
trials.shortScoreGain=cellfun(@(item) item.score-item.legacyScore,short);
trials.longScoreGain=cellfun(@(item) item.score-item.legacyScore,long);
trials.scoreDifference=cellfun(@(item) item.scoreDifference,results);
trials.thetaDifferenceDeg=cellfun(@(item) item.thetaDifferenceDeg,results);
trials.rangeDifferenceM=cellfun(@(item) item.rangeDifferenceM,results);
trials.numericallyStable=cellfun(@(item) item.numericallyStable,results);
end

function summary=makeSummary(trials)
summary=table();
snrValues=unique(trials.snrDb).';
for snrDb=snrValues
    rows=trials.snrDb==snrDb;
    entry=table(snrDb,sum(rows),mean(trials.legacyConverged(rows)), ...
        mean(trials.shortConverged(rows)),mean(trials.longConverged(rows)), ...
        mean(trials.numericallyStable(rows)), ...
        max(trials.shortStationarity(rows)), ...
        max(trials.longStationarity(rows)), ...
        max(trials.scoreDifference(rows)), ...
        max(trials.thetaDifferenceDeg(rows)), ...
        max(trials.rangeDifferenceM(rows)), ...
        rms(trials.shortRangeErrorM(rows)), ...
        rms(trials.longRangeErrorM(rows)), ...
        'VariableNames',{'snrDb','count','legacyConvergedRate', ...
        'shortConvergedRate','longConvergedRate','numericallyStableRate', ...
        'maxShortStationarity','maxLongStationarity', ...
        'maxScoreDifference','maxThetaDifferenceDeg', ...
        'maxRangeDifferenceM','shortRangeRmseM','longRangeRmseM'});
    summary=[summary;entry]; %#ok<AGROW>
end
end
