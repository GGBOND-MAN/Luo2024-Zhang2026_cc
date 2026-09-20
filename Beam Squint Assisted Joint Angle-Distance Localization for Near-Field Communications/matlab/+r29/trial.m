function result = trial(cfg, algorithm, protocol, scan, row)
%TRIAL Recompute one observation-only front and one MUSIC, then freeze.
arguments
    cfg (1,1) struct
    algorithm (1,1) struct
    protocol (1,1) struct
    scan (1,1) struct
    row (1,:) table
end
result = struct(success=false, errorIdentifier="", errorMessage="", ...
    version=protocol.version, seed=row.seed, thetaDeg=nan(1,10), ...
    rangeM=nan(1,10));
totalTimer = tic;
try
    timer = tic;
    replay = fsjad.replayRound27Data(cfg,scan,row);
    result.replay = replay;
    result.cost.replaySeconds = toc(timer);
    result.front = r29.front(cfg,replay.observation,scan,protocol);
    f = result.front.selected;
    musicCfg = cfg;
    musicCfg.subarraySize = algorithm.subarraySize;
    musicCfg.numSubarrays = cfg.numAntennas-algorithm.subarraySize+1;
    musicCfg.localHalfWidthDeg = algorithm.localHalfWidthDeg;
    musicCfg.localHalfWidthM = algorithm.localHalfWidthM;
    musicCfg.gridSizes = algorithm.gridSizes;
    count = algorithm.fusionCarrierCount;
    first = max(0,min(replay.peakCarrierIndex-floor(count/2),cfg.numSubcarriers-count));
    carriers = (first:first+count-1).';
    timer = tic;
    music = jad.localMusicEstimate(musicCfg,replay.snapshots(:,carriers+1), ...
        carriers,f.thetaDeg,f.rangeM);
    result.cost.musicSeconds = toc(timer);
    result.cost.musicGridPoints = sum(musicCfg.gridSizes.^2);
    result.cost.musicCarrierProjections = count*result.cost.musicGridPoints;
    % Reuse the vectors returned by the sole MUSIC call; do not rebuild eigensystems.
    [~,~,frequencyHz] = jad.trajectory(musicCfg,carriers);
    referenceStart = floor((musicCfg.numSubarrays+1)/2);
    ids = referenceStart:referenceStart+musicCfg.subarraySize-1;
    frozen = struct(signalVectors=music.signalVectors,carrierIndex=carriers, ...
        frequencyHz=frequencyHz,referenceIds=ids, ...
        referencePositionM=cfg.elementIndex(ids)*cfg.elementSpacing, ...
        coarseThetaDeg=f.thetaDeg,coarseRangeM=f.rangeM, ...
        subarraySize=musicCfg.subarraySize);
    result.frozen = frozen;
    result.music = music;
    result.musicConfigLabel = "Zhang-R26-fixed-backend-new-front-not-R26-locked";
    narrow = jad.localMusicReachableInterval(musicCfg,f.rangeM);
    narrowBounds = [max(15,narrow.boundsM(1)),min(50,narrow.boundsM(2))];
    wideBounds = [max(15,f.rangeM-2),min(50,f.rangeM+2)];
    feasible = unique([f.rangeM;music.rangeM]);
    funcs = {@(r) jad.localMusicLogScore(musicCfg,frozen,music.thetaDeg,r), ...
        @(r) fsjad.fixedAngleProfileLogScore(cfg,replay.observation,music.thetaDeg,r,scan), ...
        @(r) fsjad.fixedAngleProfileLogScore(cfg,replay.observation,f.thetaDeg,r,scan)};
    domains = {narrowBounds,narrowBounds,wideBounds,wideBounds,wideBounds};
    functionIndices = [1,2,1,2,3];
    names = ["Mn","Pn","Mw","Pw","PF"];
    solutions = cell(1,5);
    for j = 1:5
        timer = tic;
        solutions{j} = r29.solve(funcs{functionIndices(j)},domains{j}, ...
            feasible,protocol.solver);
        result.cost.(names(j)+"Seconds") = toc(timer);
        result.cost.(names(j)+"Evaluations") = solutions{j}.evaluationCount;
        result.solvers.(names(j)) = solutions{j};
    end
    result.thetaDeg = [f.thetaDeg,music.thetaDeg,music.thetaDeg, ...
        repmat(music.thetaDeg,1,4),f.thetaDeg,music.thetaDeg,music.thetaDeg];
    result.rangeM(1:8) = [f.rangeM,music.rangeM,f.rangeM, ...
        cellfun(@(x)x.rangeM,solutions)];
    timer = tic;
    exM = fsjad.expandRangeSearch(funcs{1},f.rangeM,cfg.rangeLimitsM, ...
        protocol.halfWidthsM,feasible,protocol.solver);
    exP = fsjad.expandRangeSearch(funcs{2},f.rangeM,cfg.rangeLimitsM, ...
        protocol.halfWidthsM,feasible,protocol.solver);
    width = max(exM.finalHalfWidthM,exP.finalHalfWidthM);
    common = [max(15,f.rangeM-width),min(50,f.rangeM+width)];
    cm = r29.solve(funcs{1},common,feasible,protocol.solver);
    cp = r29.solve(funcs{2},common,feasible,protocol.solver);
    result.rangeM(9:10) = [cm.rangeM,cp.rangeM];
    result.cost.expansionSeconds = toc(timer);
    result.cost.expansionMusicEvaluations = exM.evaluationCount+cm.evaluationCount;
    result.cost.expansionProfileEvaluations = exP.evaluationCount+cp.evaluationCount;
    result.expansion = struct(M=exM,P=exP,commonBounds=common);
    result.solvers.MExtended = cm;
    result.solvers.PExtended = cp;
    result.narrowBounds = narrowBounds;
    result.wideBounds = wideBounds;
    result.feasibleCandidates = feasible;
    result.replay = replay;
    result.checks.sameNarrowNodes = isequaln( ...
        solutions{1}.feasibleCandidatesM,solutions{2}.feasibleCandidatesM) ...
        && solutions{1}.baseIntervals==solutions{2}.baseIntervals;
    result.checks.sameWideNodes = isequaln( ...
        solutions{3}.feasibleCandidatesM,solutions{4}.feasibleCandidatesM) ...
        && solutions{3}.baseIntervals==solutions{4}.baseIntervals;
    result.checks.sameSubspace = isequal(music.signalVectors,frozen.signalVectors);
    result.checks.sameAngle = isscalar(unique(result.thetaDeg([3:7,9:10])));
    result.checks.frontStationary = f.converged;
    result.success = all(isfinite([result.thetaDeg,result.rangeM])) ...
        && result.checks.sameNarrowNodes && result.checks.sameWideNodes ...
        && result.checks.sameSubspace && result.checks.sameAngle;
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport(exception,"extended","hyperlinks","off"));
end
result.cost.totalSeconds = toc(totalTimer);
end
