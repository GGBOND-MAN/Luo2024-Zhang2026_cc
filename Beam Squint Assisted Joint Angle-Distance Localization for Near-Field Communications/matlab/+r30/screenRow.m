function output = screenRow(cfg, scan, protocol, candidates, row)
%SCREENROW Replay once and evaluate all predeclared lightweight candidates.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    protocol (1, 1) struct
    candidates table
    row (1, :) table
end

replay = fsjad.replayRound27Data(cfg, scan, row);
candidateResults = cell(height(candidates), 1);
for index = 1:height(candidates)
    candidateResults{index} = r30.trialFromReplay( ...
        cfg, replay, scan, protocol, candidates(index, :));
end
output.version = protocol.version;
output.seed = row.seed;
output.snrDb = row.snrDb;
output.candidateId = candidates.candidateId;
output.candidateResults = candidateResults;
output.success = all(cellfun(@(item) item.success, candidateResults));
end
