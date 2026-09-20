function run_round29_sensitivity(options)
%RUN_ROUND29_SENSITIVITY One finite 2x2 candidate-sensitivity audit.
arguments
    options.NumWorkers (1,1) double {mustBePositive,mustBeInteger} = 8
end
project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
root = fullfile(project,"results","full_spectrum","round29_sensitivity_v1");
if ~isfolder(root), mkdir(root); end
paths = r29.paths(project);
old = load(paths.v2,"setup","design","results","serialThreadCheck");
protocol = r29.config();
source = r29.manifest(project);
passed = load(fullfile(project,"results","full_spectrum","round29_preflight_v1","preflight.mat"));
assert(isequaln(passed.source,source) && all([passed.testResults.Passed]),"r29:StalePreflight");
identity = struct(version="R29-finite-sensitivity-v1", ...
    protocol=protocol,source=source,oldSetup=old.setup,design=old.design, ...
    dataHash=fsjad.sourceHashManifest(string(fileparts(paths.v2)), ...
    "front_candidate_closure_v2.mat"));
checkpoint = fullfile(root,"checkpoint.mat");
results = cell(4,4);
if isfile(checkpoint)
    saved = load(checkpoint);
    r29.assertIdentity(saved.identity,identity);
    results = saved.results;
end
targets = [36200034;36200114;36200073;36200127];
settings = [0.05,16;0.05,32;0.025,16;0.025,32];
cfg = old.setup.cfg;
scan = fsjad.prepareScan(cfg);
for k = 1:4
    oldIndex = find(old.design.seed==targets(k),1);
    if isempty(results{k,1})
        results{k,1} = struct(reused=true,estimate=old.results{oldIndex}, ...
            addedSeconds=0,diagnostics={{}});
    end
end
pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers~=options.NumWorkers, delete(pool); pool=[]; end
if isempty(pool), pool=parpool("Threads",options.NumWorkers); end
environment = struct(matlabVersion=version,computer=computer,workers=pool.NumWorkers, ...
    requestedWorkers=options.NumWorkers,poolClass=class(pool),timestamp=string(datetime("now")));
pending = find(cellfun(@isempty,results));
for first = 1:options.NumWorkers:numel(pending)
    tasks = pending(first:min(first+options.NumWorkers-1,numel(pending)));
    batch = cell(numel(tasks),1);
    taskInputs = cell(numel(tasks),1);
    for j = 1:numel(tasks)
        [k,s] = ind2sub([4,4],tasks(j));
        oldIndex = find(old.design.seed==targets(k),1);
        taskInputs{j} = struct(baseline=old.results{oldIndex}, ...
            row=old.design(oldIndex,:),spacing=settings(s,1),peaks=settings(s,2));
    end
    angleOffsets = protocol.angleOffsetsDeg;
    modeAngle = protocol.modeAngleDeg;
    modeRange = protocol.modeRangeM;
    scoreTolerance = protocol.scoreTolerance;
    stepTolerance = protocol.stepTolerance;
    parfor j = 1:numel(tasks)
        input = taskInputs{j};
        baseline = input.baseline;
        replay = fsjad.replayRound27Data(cfg,scan,input.row);
        timer = tic;
        estimate = r29.candidateFront(cfg,replay.observation,scan, ...
            angleOffsets,IterationCaps=200, ...
            InitialSpacingM=input.spacing,PeakCount=input.peaks, ...
            FeasibleCandidates=baseline.candidateBank);
        selected = estimate.selectedEstimates{1};
        base = baseline.selectedEstimates{1};
        diagnostics = cell(0,1);
        newMode = abs(selected.thetaDeg-base.thetaDeg)>modeAngle ...
            || abs(selected.rangeM-base.rangeM)>modeRange;
        if ~selected.converged || (newMode && selected.score>base.score+scoreTolerance)
            for cap = [400,800]
                diagnostics{end+1,1} = fsjad.refineProfileMonotone( ...
                    cfg,replay.observation,selected.thetaDeg,selected.rangeM,scan, ...
                    MaxIterations=cap,StepTolerance=stepTolerance); %#ok<AGROW>
            end
        end
        batch{j} = struct(reused=false,estimate=estimate,addedSeconds=toc(timer), ...
            diagnostics={diagnostics},replay=replay);
    end
    results(tasks) = batch;
    save(checkpoint,"identity","results","environment","-v7.3");
    fprintf("R29 sensitivity %d/16 completed\n",nnz(~cellfun(@isempty,results)));
end
summary = table();
for k = 1:4
    base = results{k,1}.estimate.selectedEstimates{1};
    for s = 1:4
        item = results{k,s};
        e = item.estimate.selectedEstimates{1};
        delta = [e.score-base.score,e.thetaDeg-base.thetaDeg,e.rangeM-base.rangeM];
        sameMode = abs(delta(2))<=protocol.modeAngleDeg && abs(delta(3))<=protocol.modeRangeM;
        stable = abs(delta(1))<=protocol.scoreTolerance ...
            && abs(delta(2))<=protocol.angleToleranceDeg && abs(delta(3))<=protocol.rangeToleranceM;
        cost = responseCost(item.estimate);
        entry = table(targets(k),settings(s,1),settings(s,2),item.reused, ...
            e.score,e.thetaDeg,e.rangeM,e.stationarity,e.converged, ...
            delta(1),delta(2),delta(3),sameMode,stable, ...
            height(item.estimate.candidateBank),cost,item.addedSeconds,numel(item.diagnostics), ...
            'VariableNames',{'seed','spacingM','peakCount','reused','score', ...
            'thetaDeg','rangeM','stationarity','converged','scoreGain','thetaDeltaDeg', ...
            'rangeDeltaM','sameMode','engineeringStable','candidateCount', ...
            'responseEvaluations200Path','addedSeconds','extraDiagnosticCount'});
        summary = [summary;entry]; %#ok<AGROW>
    end
end
changedMode = summary.scoreGain>protocol.scoreTolerance & ~summary.sameMode;
decision = struct(initialSpacingM=0.05,peakCount=16, ...
    reason="finite-set-no-material-new-mode",truthUsed=false);
if any(changedMode)
    decision.initialSpacingM = 0.025;
    decision.peakCount = 32;
    decision.reason = "finite-set-new-mode-use-predetermined-densest-reference";
end
engineering = old.serialThreadCheck;
engineering.originalCheckStillFailed = ~engineering.withinTolerance;
engineering.candidateAngleOldFailed = engineering.maxCandidateThetaDifferenceDeg>1e-10;
engineering.selectedAngleOldFailed = engineering.maxThetaDifferenceDeg>1e-7;
engineering.postHocEngineeringOnly = engineering.maxObjectiveDifference<=protocol.scoreTolerance ...
    & engineering.maxThetaDifferenceDeg<=protocol.angleToleranceDeg ...
    & engineering.maxRangeDifferenceM<=protocol.rangeToleranceM;
engineering.note = repmat("post-hoc-not-an-original-preregistered-pass",height(engineering),1);
writetable(engineering,fullfile(root,"engineering_tolerance_analysis.csv"));
writetable(summary,fullfile(root,"sensitivity_summary.csv"));
writetable(source,fullfile(root,"source_hashes.csv"));
save(fullfile(root,"result.mat"),"identity","results","summary","engineering","environment","decision","-v7.3");
fprintf("ROUND29_SENSITIVITY_COMPLETE; no global-optimality claim\n");
end

function count = responseCost(e)
count = sum(cellfun(@(s)s.evaluationCount,e.rangeSolvers))+e.profileSolver.evaluationCount ...
    +sum(cellfun(@(s)s.responseEvaluations,e.stageOneEstimates)) ...
    +sum(cellfun(@(s)s.responseEvaluations,e.allEstimates(:,1)));
end
