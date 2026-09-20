function [design, globalRows] = partitionDesign(fullDesign, shardId)
%PARTITIONDESIGN Assign complete position clusters to one of two servers.

arguments
    fullDesign table
    shardId (1, 1) double {mustBeInteger, mustBeInRange(shardId, 1, 2)}
end

globalRows = find(fullDesign.shardId == shardId);
design = fullDesign(globalRows, :);
positionIds = unique(design.positionId);
if height(design) ~= 700 || numel(positionIds) ~= 100
    error("r41:FrozenShardBalanceMismatch", ...
        "Each R41 shard must contain 100 positions and 700 rows.");
end
for positionId = positionIds.'
    if nnz(design.positionId == positionId) ~= 7
        error("r41:SplitPositionCluster", ...
            "Every position cluster must remain wholly on one shard.");
    end
end
end
