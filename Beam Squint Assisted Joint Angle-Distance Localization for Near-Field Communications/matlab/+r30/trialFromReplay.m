function result = trialFromReplay(cfg, replay, scan, protocol, candidate, options)
%TRIALFROMREPLAY Run one lightweight candidate on one fixed observation.

arguments
    cfg (1, 1) struct
    replay (1, 1) struct
    scan (1, 1) struct
    protocol (1, 1) struct
    candidate (1, :) table
    options.IncludePublicBaseline (1, 1) logical = false
    options.IncludeEnhancedBaseline (1, 1) logical = false
    options.EnhancedAlgorithm (1, 1) struct = struct()
end

result = struct(success=false, errorIdentifier="", errorMessage="", ...
    candidateId=candidate.candidateId);
timer = tic;
try
    result.front = r30.front(cfg, replay.observation, scan, protocol, candidate);
    front = result.front.selected;
    carrierIndex = r30.selectLocalCarriers(cfg.numSubcarriers, ...
        candidate.musicCarrierCount, replay.peakCarrierIndex);
    [state, musicCfg, stateCost] = r30.prepareMusicState(cfg, ...
        replay.snapshots(:, carrierIndex+1), carrierIndex, ...
        front.thetaDeg, front.rangeM, candidate.musicSubarraySize);
    result.musicState = state;
    result.musicStateCost = stateCost;

    angleBounds = [max(cfg.thetaLimitsDeg(1), ...
        front.thetaDeg-protocol.angleHalfWidthDeg), ...
        min(cfg.thetaLimitsDeg(2), front.thetaDeg+protocol.angleHalfWidthDeg)];
    angleScore = @(thetaDeg) jad.localMusicLogScore( ...
        musicCfg, state, thetaDeg, front.rangeM);
    angleTimer = tic;
    result.angleSolver = r30.maximizeScore1D(angleScore, angleBounds, ...
        front.thetaDeg, Intervals=protocol.angleIntervals, ...
        PeakCount=protocol.anglePeakCount, TolX=1e-7);
    result.angleSeconds = toc(angleTimer);
    thetaDeg = result.angleSolver.value;

    rangeBounds = [max(cfg.rangeLimitsM(1), ...
        front.rangeM-protocol.profileHalfWidthM), ...
        min(cfg.rangeLimitsM(2), front.rangeM+protocol.profileHalfWidthM)];
    rangeScore = @(rangeM) fsjad.fixedAngleProfileLogScore( ...
        cfg, replay.observation, thetaDeg, rangeM, scan);
    rangeIntervals = max(40, ceil(diff(rangeBounds)/0.05));
    profileTimer = tic;
    result.profileSolver = r30.maximizeScore1D(rangeScore, rangeBounds, ...
        front.rangeM, Intervals=rangeIntervals, PeakCount=8, TolX=1e-6);
    result.profileSeconds = toc(profileTimer);

    result.methodNames = ["F_L", "H_L", "P_L", ...
        "C_public", "C_enhanced"];
    result.thetaDeg = [front.thetaDeg, thetaDeg, thetaDeg, nan, nan];
    result.rangeM = [front.rangeM, front.rangeM, ...
        result.profileSolver.value, nan, nan];
    result.publicBaseline = struct();
    result.enhancedBaseline = struct();
    if options.IncludePublicBaseline
        [result.publicBaseline, result.thetaDeg(4), result.rangeM(4)] = ...
            r30.runBaseline(cfg, replay, front, protocol.publicZhang);
    end
    if options.IncludeEnhancedBaseline
        if isempty(fieldnames(options.EnhancedAlgorithm))
            error("r30:MissingEnhancedAlgorithm", ...
                "EnhancedAlgorithm is required for the enhanced baseline.");
        end
        [result.enhancedBaseline, result.thetaDeg(5), result.rangeM(5)] = ...
            r30.runBaseline(cfg, replay, front, options.EnhancedAlgorithm);
    end
    result.complexity = r30.complexity(cfg, candidate, result);
    result.success = all(isfinite(result.thetaDeg(1:3))) ...
        && all(isfinite(result.rangeM(1:3)));
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport(exception, "extended", "hyperlinks", "off"));
end
result.totalSeconds = toc(timer);
end
