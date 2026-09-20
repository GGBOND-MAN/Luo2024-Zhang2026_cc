function [design, globalRowIndex] = partitionDesign( ...
    fullDesign, shardIndex, shardCount)
%PARTITIONDESIGN Keep all seven SNR rows for a position in one shard.

arguments
    fullDesign table
    shardIndex (1, 1) double {mustBeInteger, mustBePositive}
    shardCount (1, 1) double {mustBeInteger, mustBePositive}
end

if shardIndex > shardCount
    error("r34:InvalidShard", "ShardIndex cannot exceed ShardCount.");
end
required = ["positionId", "snrDb"];
if ~all(ismember(required, string(fullDesign.Properties.VariableNames)))
    error("r34:PartitionDesignColumns", ...
        "The final design lacks positionId or snrDb.");
end
mask = mod(fullDesign.positionId-1, shardCount) == shardIndex-1;
globalRowIndex = find(mask);
design = fullDesign(mask, :);
if isempty(design)
    error("r34:EmptyShard", "The requested shard contains no rows.");
end
positions = unique(design.positionId);
for position = positions.'
    if nnz(design.positionId == position) ...
            ~= nnz(fullDesign.positionId == position)
        error("r34:SplitPositionCluster", ...
            "A position cluster was split across final shards.");
    end
end
end
