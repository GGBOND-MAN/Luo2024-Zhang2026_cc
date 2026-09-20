function result = r35SchemeBRangeRefreshTrial( ...
    cfg, scan, designRow, primary, r34Protocol)
%R35SCHEMEBRANGEREFRESHTRIAL Run one allowed frozen profile refresh.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    designRow (1, :) table
    primary (1, 1) struct
    r34Protocol (1, 1) struct = r34.config()
end

result = struct(success=false, thetaDeg=primary.B_primary.thetaDeg, ...
    rangeM=nan, profileSeconds=nan, profileEvaluationCount=nan, ...
    completeRuntimeSeconds=nan, errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, designRow);
    timer = tic;
    profile = r33.profileAtAngle(cfg, replay.observation, scan, ...
        primary.B_primary.thetaDeg, primary.frontRangeM, r34Protocol.r33);
    seconds = toc(timer);
    result.success = true;
    result.rangeM = profile.value;
    result.profileSeconds = seconds;
    result.profileEvaluationCount = profile.evaluationCount;
    result.completeRuntimeSeconds = ...
        primary.B_primary.runtimeSeconds+seconds;
    result.profile = struct(version=profile.version, score=profile.score, ...
        interval=profile.interval, endpointHit=profile.endpointHit, ...
        lambda=profile.lambda, coarseSpacingM=profile.coarseSpacingM, ...
        peakCount=profile.peakCount);
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end
