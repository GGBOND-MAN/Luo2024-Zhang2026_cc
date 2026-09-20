function result = r36SchemeETrial( ...
    cfg, scan, designRow, rowIndex, r34Protocol, schemeProtocol)
%R36SCHEMEETRIAL Run frozen baselines and one range-orthogonal update.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    designRow (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    r34Protocol (1, 1) struct = r34.config()
    schemeProtocol (1, 1) struct = r36SchemeEConfig()
end

result = failureResult(designRow, rowIndex);
try
    replay = fsjad.replayRound27Data(cfg, scan, designRow);
    if mod(rowIndex, 2) == 1
        order = "P_A-then-C_enhanced";
        pa = r34.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, "P_A", r34Protocol);
        c = r34.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, "C_enhanced", r34Protocol);
    else
        order = "C_enhanced-then-P_A";
        c = r34.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, "C_enhanced", r34Protocol);
        pa = r34.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, "P_A", r34Protocol);
    end

    finalStage = pa.estimate.stages(end);
    refinement = r36RangeOrthogonalOneStep(pa.musicCfg, pa.state, ...
        finalStage.thetaGridDeg, finalStage.selectedIndex, ...
        pa.rangeM, schemeProtocol);
    profileTimer = tic;
    profile = r33.profileAtAngle(cfg, replay.observation, scan, ...
        refinement.thetaDeg, pa.front.selected.rangeM, r34Protocol.r33);
    profileSeconds = toc(profileTimer);
    completeRuntimeSeconds = pa.cost.totalOnlineSeconds ...
        -pa.cost.profileSeconds+refinement.runtimeSeconds+profileSeconds;
    paResponseCount = responseCount(pa);
    cResponseCount = responseCount(c);
    eResponseCount = pa.cost.sparseResponseCalls ...
        +pa.cost.frontFullResponseCalls+profile.evaluationCount;

    result.success = true;
    result.runtimeOrder = order;
    result.truthThetaDeg = designRow.truthThetaDeg;
    result.truthRangeM = designRow.truthRangeM;
    result.frontThetaDeg = pa.front.selected.thetaDeg;
    result.frontRangeM = pa.front.selected.rangeM;
    result.P_A = locationRecord(pa.thetaDeg, pa.rangeM, ...
        pa.cost.totalOnlineSeconds, paResponseCount, ...
        pa.estimate.evaluationCount, pa.cost.directCount);
    result.C_enhanced = locationRecord(c.thetaDeg, c.rangeM, ...
        c.cost.totalOnlineSeconds, cResponseCount, ...
        c.estimate.evaluationCount, c.cost.directCount);
    result.E_one_step = locationRecord(refinement.thetaDeg, ...
        profile.value, completeRuntimeSeconds, eResponseCount, ...
        pa.estimate.evaluationCount+2, pa.cost.directCount);
    result.E_one_step.refinementSeconds = refinement.runtimeSeconds;
    result.E_one_step.profileSeconds = profileSeconds;
    result.E_one_step.carrierResidualEvaluations = ...
        2*pa.cost.carrierCount;
    result.refinement = refinement;
    result.profile = compactProfile(profile);
    result.finalGridDeg = finalStage.thetaGridDeg;
    result.solverAudit = pa.solverAudit;
catch exception
    result.success = false;
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function count = responseCount(input)
count = input.cost.sparseResponseCalls ...
    +input.cost.frontFullResponseCalls+input.cost.profileResponseCalls;
end

function output = locationRecord(thetaDeg, rangeM, runtimeSeconds, ...
    responseEvaluationCount, musicEvaluationCount, evdCount)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM, ...
    runtimeSeconds=runtimeSeconds, ...
    responseEvaluationCount=responseEvaluationCount, ...
    musicEvaluationCount=musicEvaluationCount, evdCount=evdCount);
end

function output = compactProfile(profile)
output = struct(version=profile.version, score=profile.score, ...
    interval=profile.interval, endpointHit=profile.endpointHit, ...
    lambda=profile.lambda, coarseSpacingM=profile.coarseSpacingM, ...
    peakCount=profile.peakCount, evaluationCount=profile.evaluationCount);
end

function result = failureResult(designRow, rowIndex)
result = struct(success=false, rowIndex=rowIndex, seed=designRow.seed, ...
    trialIndex=designRow.trialIndex, snrDb=designRow.snrDb, ...
    truthThetaDeg=designRow.truthThetaDeg, ...
    truthRangeM=designRow.truthRangeM, runtimeOrder="", ...
    errorIdentifier="", errorMessage="");
end
