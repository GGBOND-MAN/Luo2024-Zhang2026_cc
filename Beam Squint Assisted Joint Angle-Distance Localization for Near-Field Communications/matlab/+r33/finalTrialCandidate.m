function result = finalTrialCandidate(cfg, scan, row, protocol)
%FINALTRIALCANDIDATE Unexecuted fast candidate for the inherited final design.
% This function contains no authorization logic and is not invoked by R33
% preparation. A future authorized runner must still enforce a source- and
% design-bound gate before calling it.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    protocol (1, 1) struct = r33.config()
end

result = struct(success=false, errorIdentifier="", errorMessage="", ...
    version="R33-A-only-final-candidate-unexecuted-v1", seed=row.seed, ...
    positionId=row.positionId, snrDb=row.snrDb);
timer = tic;
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    estimate = r33.sharedRegressionSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol, UseFastResponse=true, ...
        UseGram=false);
    result.methodNames = ["P_A", "C_enhanced", "H_A", ...
        "C_public", "F_L06"];
    result.thetaDeg = [estimate.P_A.thetaDeg, ...
        estimate.C_enhanced.thetaDeg, estimate.H_A.thetaDeg, ...
        estimate.C_public.thetaDeg, estimate.front.selected.thetaDeg];
    result.rangeM = [estimate.P_A.rangeM, ...
        estimate.C_enhanced.rangeM, estimate.H_A.rangeM, ...
        estimate.C_public.rangeM, estimate.front.selected.rangeM];
    result.estimate = estimate;
    result.hash = struct(observation=r31.arrayHash(replay.observation), ...
        snapshots=r31.arrayHash(replay.snapshots));
    result.success = all(isfinite(result.thetaDeg)) ...
        && all(isfinite(result.rangeM));
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
result.sessionSeconds = toc(timer);
end
