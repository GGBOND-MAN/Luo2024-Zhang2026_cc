function result = trial(cfg, scan, protocol, candidate, row, options)
%TRIAL Replay one saved calibration observation and run one candidate.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    protocol (1, 1) struct
    candidate (1, :) table
    row (1, :) table
    options.IncludePublicBaseline (1, 1) logical = false
    options.IncludeEnhancedBaseline (1, 1) logical = false
    options.EnhancedAlgorithm (1, 1) struct = struct()
end

replay = fsjad.replayRound27Data(cfg, scan, row);
result = r30.trialFromReplay(cfg, replay, scan, protocol, candidate, ...
    IncludePublicBaseline=options.IncludePublicBaseline, ...
    IncludeEnhancedBaseline=options.IncludeEnhancedBaseline, ...
    EnhancedAlgorithm=options.EnhancedAlgorithm);
result.seed = row.seed;
result.snrDb = row.snrDb;
end
