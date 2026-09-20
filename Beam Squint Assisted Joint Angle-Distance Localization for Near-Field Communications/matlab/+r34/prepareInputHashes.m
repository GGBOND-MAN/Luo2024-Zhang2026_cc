function hashes = prepareInputHashes(cfg, scan, design)
%PREPAREINPUTHASHES Compute observation SHA-256 digests on the MATLAB client.
% r31.arrayHash uses Java and is intentionally not called from thread workers.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    design table
end

hashes = cell(height(design), 1);
for index = 1:height(design)
    replay = fsjad.replayRound27Data(cfg, scan, design(index, :));
    hashes{index} = struct( ...
        version="R34-client-SHA256-input-hash-v1", ...
        seed=design.seed(index), ...
        observation=r31.arrayHash(replay.observation), ...
        snapshots=r31.arrayHash(replay.snapshots), ...
        computedOn="MATLAB-client-before-thread-estimation");
end
end
