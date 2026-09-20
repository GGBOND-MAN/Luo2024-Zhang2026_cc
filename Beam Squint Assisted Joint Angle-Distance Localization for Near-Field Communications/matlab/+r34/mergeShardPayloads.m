function results = mergeShardPayloads(expectedDesign, payloads, identity)
%MERGESHARDPAYLOADS Merge disjoint complete shards into frozen row order.

arguments
    expectedDesign table
    payloads (:, 1) cell
    identity (1, 1) struct
end

results = cell(height(expectedDesign), 1);
assigned = false(height(expectedDesign), 1);
for shardIndex = 1:numel(payloads)
    payload = payloads{shardIndex};
    required = ["identity", "design", "results"];
    if ~all(isfield(payload, required)) ...
            || payload.identity.protocolDesignHash ~= identity.designHash ...
            || payload.identity.sourceDigest ~= identity.sourceDigest
        error("r34:ShardIdentityMismatch", ...
            "A shard does not match the frozen protocol identity.");
    end
    rows = payload.identity.globalRowIndex(:);
    if numel(rows) ~= height(payload.design) ...
            || numel(rows) ~= numel(payload.results) ...
            || any(rows < 1 | rows > height(expectedDesign)) ...
            || any(assigned(rows)) ...
            || ~isequaln(payload.design, expectedDesign(rows, :))
        error("r34:InvalidOrOverlappingShard", ...
            "Shard rows are missing, overlapping, out of order, or changed.");
    end
    results(rows) = payload.results;
    assigned(rows) = true;
end
if ~all(assigned) || any(cellfun(@isempty, results))
    error("r34:IncompleteShardMerge", ...
        "Every frozen design row must appear exactly once.");
end
end
