function result = r35SchemeDBaselineTrial( ...
    cfg, scan, designRow, rowIndex, r34Protocol, schemeProtocol)
%R35SCHEMEDBASELINETRIAL Run frozen baselines and the mandatory D0 identity.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    designRow (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    r34Protocol (1, 1) struct = r34.config()
    schemeProtocol (1, 1) struct = r35SchemeDConfig()
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
    d0Weight = r35BuildCarrierWeights( ...
        pa.musicCfg, pa.state, pa.cost, "D0_uniform", schemeProtocol);
    d0 = r35StagedWeightedAngleMusic(pa.musicCfg, pa.state, ...
        pa.front.selected.thetaDeg, pa.front.selected.rangeM, ...
        r34Protocol.r32.music.angleHalfWidthDeg, ...
        schemeProtocol.gridSizes, d0Weight.weights);
    d0Audit = r35AssertD0Identity(pa, d0, schemeProtocol);

    result.success = true;
    result.runtimeOrder = order;
    result.truthThetaDeg = designRow.truthThetaDeg;
    result.truthRangeM = designRow.truthRangeM;
    result.paFrozen = pa;
    result.P_A = compactEstimate(pa);
    result.C_enhanced = compactEstimate(c);
    result.D0_uniform = result.P_A;
    result.D0_uniform.thetaDeg = d0.thetaDeg;
    result.D0_uniform.musicEvaluationCount = d0.evaluationCount;
    result.D0_uniform.carrierScoreEvaluationCount = ...
        d0.carrierScoreEvaluationCount;
    result.d0Identity = d0Audit;
    result.d0IdentitySearchSeconds = d0.runtimeSeconds;
    result.d0WeightConstructionSeconds = d0Weight.constructionSeconds;
    result.d0WeightDiagnostics = d0Weight.diagnostics;
catch exception
    result.success = false;
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function output = compactEstimate(input)
responseCount = input.cost.sparseResponseCalls ...
    +input.cost.frontFullResponseCalls+input.cost.profileResponseCalls;
output = struct(thetaDeg=input.thetaDeg, rangeM=input.rangeM, ...
    runtimeSeconds=input.cost.totalOnlineSeconds, ...
    responseEvaluationCount=responseCount, ...
    musicEvaluationCount=input.estimate.evaluationCount, ...
    carrierScoreEvaluationCount=input.estimate.evaluationCount ...
        *input.cost.carrierCount, ...
    evdCount=input.cost.directCount);
end

function result = failureResult(designRow, rowIndex)
result = struct(success=false, rowIndex=rowIndex, seed=designRow.seed, ...
    trialIndex=designRow.trialIndex, snrDb=designRow.snrDb, ...
    truthThetaDeg=designRow.truthThetaDeg, ...
    truthRangeM=designRow.truthRangeM, runtimeOrder="", ...
    errorIdentifier="", errorMessage="");
end
