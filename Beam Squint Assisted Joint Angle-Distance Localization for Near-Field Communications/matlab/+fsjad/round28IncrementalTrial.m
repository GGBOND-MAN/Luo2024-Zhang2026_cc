function result = round28IncrementalTrial(setup, scan, row, oldResult, options)
%ROUND28INCREMENTALTRIAL Add frozen-subspace fixed-angle range ablations.

arguments
    setup (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    oldResult (1, 1) struct
    options.KeepReplayData (1, 1) logical = false
    options.RunExpansion (1, 1) logical = true
end

index = setup.round27Protocol.methodIndex;
result.version = setup.protocol.version;
result.success = false;
result.errorIdentifier = "";
result.errorMessage = "";
result.errorReport = "";
result.seed = row.seed;
result.snrDb = row.snrDb;
result.truthThetaDeg = row.truthThetaDeg;
result.truthRangeM = row.truthRangeM;
result.methodNames = setup.protocol.methodNames;
result.thetaDeg = nan(1, numel(result.methodNames));
result.rangeM = nan(1, numel(result.methodNames));
result.solvers = struct();
result.expansion = struct();
result.runtimeSeconds = struct();
result.evaluationCount = struct();
result.subspaceValidation = struct();
result.replayData = [];

try
    cfg = setup.cfg;
    replay = fsjad.replayRound27Data(cfg, scan, row);
    assert(replay.peakCarrierIndex == oldResult.peakCarrierIndex, ...
        "fsjad:Round28ReplayPeakMismatch", ...
        "Replayed peak carrier differs from the saved Round 27 row.");

    thetaF = oldResult.thetaDeg(index.StableFront);
    rangeF = oldResult.rangeM(index.StableFront);
    thetaC = oldResult.thetaDeg(index.C);
    rangeC = oldResult.rangeM(index.C);
    rangeD = oldResult.rangeM(index.D);
    rangeProfileFront = oldResult.rangeM(index.ProfileAtFront);

    musicCfg = cfg;
    musicCfg.subarraySize = setup.zhang.subarraySize;
    musicCfg.numSubarrays = cfg.numAntennas-musicCfg.subarraySize+1;
    musicCfg.localHalfWidthDeg = setup.zhang.localHalfWidthDeg;
    musicCfg.localHalfWidthM = setup.zhang.localHalfWidthM;
    musicCfg.gridSizes = setup.zhang.gridSizes;
    carrierCount = setup.zhang.fusionCarrierCount;
    first = max(0, min(replay.peakCarrierIndex-floor(carrierCount/2), ...
        cfg.numSubcarriers-carrierCount));
    carriers = (first:first+carrierCount-1).';
    selectedSnapshots = replay.snapshots(:, carriers+1);
    frozen = jad.freezeLocalMusicSubspace( ...
        musicCfg, selectedSnapshots, carriers, thetaF, rangeF);

    vectorNorm = vecnorm(frozen.signalVectors, 2, 1);
    result.subspaceValidation.minimumEigenvectorNorm = min(vectorNorm);
    result.subspaceValidation.maximumEigenvectorNormMismatch = ...
        max(abs(vectorNorm-1));
    result.subspaceValidation.carrierIndexMatches = ...
        isequal(carriers, frozen.carrierIndex);
    result.subspaceValidation.coarseCenterMatchesStableFront = ...
        frozen.coarseThetaDeg == thetaF && frozen.coarseRangeM == rangeF;
    result.subspaceValidation.builderEquivalenceTest = ...
        "localMusicLogScoreTest/frozenSubspaceMatchesLegacyBuilder";
    assert(max(abs(vectorNorm-1)) <= 1e-10 ...
        && result.subspaceValidation.carrierIndexMatches ...
        && result.subspaceValidation.coarseCenterMatchesStableFront, ...
        "fsjad:Round28SubspaceReconstructionMismatch");

    narrow = jad.localMusicReachableInterval(musicCfg, rangeF);
    wideBounds = [max(cfg.rangeLimitsM(1), ...
        rangeF-setup.protocol.wideHalfWidthM), ...
        min(cfg.rangeLimitsM(2), rangeF+setup.protocol.wideHalfWidthM)];
    feasible = unique([rangeF; rangeC; rangeD; rangeProfileFront]);
    solverOptions = solverSettings(setup.protocol);

    musicCacheRange = zeros(0, 1);
    musicCacheScore = zeros(0, 1);
    profileCCacheRange = zeros(0, 1);
    profileCCacheScore = zeros(0, 1);
    profileFCacheRange = zeros(0, 1);
    profileFCacheScore = zeros(0, 1);

    timer = tic;
    mn = solveRange(@scoreMusicC, narrow.boundsM, feasible, solverOptions);
    result.runtimeSeconds.Mn = toc(timer);
    timer = tic;
    pn = solveRange(@scoreProfileC, narrow.boundsM, feasible, solverOptions);
    result.runtimeSeconds.Pn = toc(timer);
    timer = tic;
    mw = solveRange(@scoreMusicC, wideBounds, feasible, solverOptions);
    result.runtimeSeconds.Mw = toc(timer);
    timer = tic;
    pw = solveRange(@scoreProfileC, wideBounds, feasible, solverOptions);
    result.runtimeSeconds.Pw = toc(timer);
    timer = tic;
    pf = solveRange(@scoreProfileF, wideBounds, feasible, solverOptions);
    result.runtimeSeconds.PF = toc(timer);

    if options.RunExpansion
        timer = tic;
        musicExpansion = fsjad.expandRangeSearch(@scoreMusicC, rangeF, ...
            cfg.rangeLimitsM, setup.protocol.expansionHalfWidthsM, ...
            feasible, solverOptions);
        result.runtimeSeconds.MExpansion = toc(timer);
        timer = tic;
        profileExpansion = fsjad.expandRangeSearch(@scoreProfileC, rangeF, ...
            cfg.rangeLimitsM, setup.protocol.expansionHalfWidthsM, ...
            feasible, solverOptions);
        result.runtimeSeconds.PExpansion = toc(timer);
        commonHalfWidthM = max(musicExpansion.finalHalfWidthM, ...
            profileExpansion.finalHalfWidthM);
        commonBounds = [max(cfg.rangeLimitsM(1), rangeF-commonHalfWidthM), ...
            min(cfg.rangeLimitsM(2), rangeF+commonHalfWidthM)];
        timer = tic;
        musicCommon = solveRange( ...
            @scoreMusicC, commonBounds, feasible, solverOptions);
        result.runtimeSeconds.MAdaptiveCommon = toc(timer);
        timer = tic;
        profileCommon = solveRange( ...
            @scoreProfileC, commonBounds, feasible, solverOptions);
        result.runtimeSeconds.PAdaptiveCommon = toc(timer);
    else
        musicExpansion = emptyExpansion();
        profileExpansion = emptyExpansion();
        musicCommon = mw;
        profileCommon = pw;
        commonBounds = wideBounds;
        commonHalfWidthM = setup.protocol.wideHalfWidthM;
        result.runtimeSeconds.MExpansion = 0;
        result.runtimeSeconds.PExpansion = 0;
        result.runtimeSeconds.MAdaptiveCommon = 0;
        result.runtimeSeconds.PAdaptiveCommon = 0;
    end

    method = setup.protocol.methodIndex;
    result.thetaDeg([method.C, method.D, method.H, method.Mn, ...
        method.Pn, method.Mw, method.Pw, method.MAdaptiveCommon, ...
        method.PAdaptiveCommon]) = thetaC;
    result.rangeM(method.C) = rangeC;
    result.rangeM(method.D) = rangeD;
    result.thetaDeg(method.E) = thetaF;
    result.rangeM(method.E) = rangeF;
    result.thetaDeg(method.ProfileAtFront) = thetaF;
    result.rangeM(method.ProfileAtFront) = rangeProfileFront;
    result.rangeM(method.H) = rangeF;
    result.rangeM(method.Mn) = mn.rangeM;
    result.rangeM(method.Pn) = pn.rangeM;
    result.rangeM(method.Mw) = mw.rangeM;
    result.rangeM(method.Pw) = pw.rangeM;
    result.thetaDeg(method.PF) = thetaF;
    result.rangeM(method.PF) = pf.rangeM;
    result.rangeM(method.MAdaptiveCommon) = musicCommon.rangeM;
    result.rangeM(method.PAdaptiveCommon) = profileCommon.rangeM;

    result.narrowInterval = narrow;
    result.wideIntervalM = wideBounds;
    result.commonExpansionIntervalM = commonBounds;
    result.commonExpansionHalfWidthM = commonHalfWidthM;
    result.carrierIndex = carriers;
    result.frozenCoarseThetaDeg = thetaF;
    result.frozenCoarseRangeM = rangeF;
    result.referenceIds = frozen.referenceIds;
    result.solvers.Mn = compactSolver(mn, setup.protocol.rankingRowsToKeep);
    result.solvers.Pn = compactSolver(pn, setup.protocol.rankingRowsToKeep);
    result.solvers.Mw = compactSolver(mw, setup.protocol.rankingRowsToKeep);
    result.solvers.Pw = compactSolver(pw, setup.protocol.rankingRowsToKeep);
    result.solvers.PF = compactSolver(pf, setup.protocol.rankingRowsToKeep);
    result.solvers.MAdaptiveCommon = compactSolver( ...
        musicCommon, setup.protocol.rankingRowsToKeep);
    result.solvers.PAdaptiveCommon = compactSolver( ...
        profileCommon, setup.protocol.rankingRowsToKeep);
    result.expansion.M = compactExpansion( ...
        musicExpansion, setup.protocol.rankingRowsToKeep);
    result.expansion.P = compactExpansion( ...
        profileExpansion, setup.protocol.rankingRowsToKeep);
    result.evaluationCount.MusicUnique = numel(musicCacheRange);
    result.evaluationCount.ProfileCUnique = numel(profileCCacheRange);
    result.evaluationCount.ProfileFUnique = numel(profileFCacheRange);
    result.evaluationCount.MnRequested = mn.evaluationCount;
    result.evaluationCount.PnRequested = pn.evaluationCount;
    result.evaluationCount.MwRequested = mw.evaluationCount;
    result.evaluationCount.PwRequested = pw.evaluationCount;
    if options.KeepReplayData
        result.replayData = replay;
        result.frozenState = frozen;
    end
    result.success = all(isfinite([result.thetaDeg, result.rangeM]));
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(exception.message);
    result.errorReport = string(getReport(exception, "extended", "hyperlinks", "off"));
end

    function values = scoreMusicC(rangeM)
        [values, musicCacheRange, musicCacheScore] = cachedScore( ...
            rangeM, musicCacheRange, musicCacheScore, ...
            @(missing) jad.localMusicLogScore(musicCfg, frozen, ...
            thetaC, missing, MaxPointsPerChunk= ...
            setup.protocol.maxMusicPointsPerChunk));
    end

    function values = scoreProfileC(rangeM)
        [values, profileCCacheRange, profileCCacheScore] = cachedScore( ...
            rangeM, profileCCacheRange, profileCCacheScore, ...
            @(missing) fsjad.fixedAngleProfileLogScore( ...
            cfg, replay.observation, thetaC, missing, scan));
    end

    function values = scoreProfileF(rangeM)
        [values, profileFCacheRange, profileFCacheScore] = cachedScore( ...
            rangeM, profileFCacheRange, profileFCacheScore, ...
            @(missing) fsjad.fixedAngleProfileLogScore( ...
            cfg, replay.observation, thetaF, missing, scan));
    end
end

function result = solveRange(scoreFunction, intervalM, candidatesM, options)
result = fsjad.maximizeRangeScore(scoreFunction, intervalM, candidatesM, ...
    InitialSpacingM=options.InitialSpacingM, ...
    MinimumIntervals=options.MinimumIntervals, ...
    RefinementLevels=options.RefinementLevels, ...
    PeakCount=options.PeakCount, TolX=options.TolX, ...
    ScoreTolerance=options.ScoreTolerance, KeepTrace=options.KeepTrace);
end

function options = solverSettings(protocol)
options = struct(InitialSpacingM=protocol.initialSpacingM, ...
    MinimumIntervals=protocol.minimumIntervals, ...
    RefinementLevels=protocol.refinementLevels, ...
    PeakCount=protocol.peakCount, TolX=protocol.tolX, ...
    ScoreTolerance=protocol.scoreTolerance, KeepTrace=false);
end

function [values, cacheRangeM, cacheScore] = cachedScore( ...
    rangeM, cacheRangeM, cacheScore, evaluator)
inputSize = size(rangeM);
query = rangeM(:);
[present, location] = ismember(query, cacheRangeM);
missing = unique(query(~present));
if ~isempty(missing)
    missingScore = evaluator(missing);
    cacheRangeM = [cacheRangeM; missing];
    cacheScore = [cacheScore; missingScore(:)];
    [present, location] = ismember(query, cacheRangeM);
end
assert(all(present), "fsjad:Round28ScoreCacheFailure");
values = reshape(cacheScore(location), inputSize);
end

function compact = compactSolver(full, rankingRows)
compact = full;
compact.candidateRanking = full.candidateRanking( ...
    1:min(rankingRows, height(full.candidateRanking)), :);
end

function compact = compactExpansion(full, rankingRows)
compact = full;
for index = 1:numel(compact.stages)
    compact.stages{index} = compactSolver(compact.stages{index}, rankingRows);
end
end

function result = emptyExpansion()
result.version = "not-run";
result.rangeM = NaN;
result.score = NaN;
result.finalIntervalM = [NaN, NaN];
result.finalHalfWidthM = NaN;
result.usedStages = 0;
result.reachedPhysicalBoundary = false;
result.termination = "not_run";
result.stages = cell(0, 1);
result.evaluationCount = 0;
end
