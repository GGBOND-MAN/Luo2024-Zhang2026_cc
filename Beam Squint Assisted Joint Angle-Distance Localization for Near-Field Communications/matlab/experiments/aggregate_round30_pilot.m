function aggregate_round30_pilot()
%AGGREGATE_ROUND30_PILOT Validate the fixed 60-user candidate screen.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
expected = r30.setup(project, "pilot");
root = fullfile(project, "results", "full_spectrum", "round30_pilot_v1");
listing = dir(fullfile(root, "shard_*", "result.mat"));
if isempty(listing)
    error("r30:NoPilotShards", "No completed Round30 pilot shards were found.");
end
design = table();
results = cell(0, 1);
seen = zeros(numel(listing), 1);
for index = 1:numel(listing)
    saved = load(fullfile(listing(index).folder, "result.mat"));
    marker = load(fullfile(listing(index).folder, "COMPLETE.mat"));
    r30.assertIdentity(marker.identity, saved.identity);
    r30.assertIdentity(saved.identity.setup, expected);
    design = [design; saved.identity.design]; %#ok<AGROW>
    results = [results; saved.results]; %#ok<AGROW>
    seen(index) = saved.identity.shardId;
end
if ~isequal(sort(seen).', 1:saved.identity.shardCount)
    error("r30:IncompletePilotShardSet", ...
        "The pilot shard set does not cover every declared shard.");
end
[design, order] = sortrows(design, ["snrDb", "trialIndex"]);
results = results(order);
if ~isequaln(design, expected.design)
    error("r30:PilotDesignMismatch", ...
        "The aggregated pilot does not match the frozen 60-user design.");
end
success = cellfun(@(item) item.success, results);
folder = fullfile(root, "aggregate");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(design(~success, :), fullfile(folder, "failed_rows.csv"));
if ~all(success)
    error("r30:PilotFailures", ...
        "Failures are retained; candidate selection was not performed.");
end

summary = r30.summarize(design, results, expected.protocol.candidates);
baselineFile = fullfile(project, "results", "full_spectrum", ...
    "round29_pilot_v1", "aggregate", "method_summary.csv");
if ~isfile(baselineFile)
    error("r30:MissingRound29Pilot", ...
        "The completed Round29 pilot summary is required for development screening.");
end
baseline = readtable(baselineFile, TextType="string");
[selection, selected] = r30.selectCandidates( ...
    summary, baseline, expected.protocol);
writetable(summary, fullfile(folder, "candidate_summary.csv"));
writetable(selection, fullfile(folder, "selection_audit.csv"));
writetable(expected.source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "selection.mat"), ...
    "selected", "selection", "summary", "expected");
save(fullfile(folder, "aggregate.mat"), ...
    "expected", "design", "results", "summary", "selection", ...
    "selected", "baseline", "-v7.3");
fprintf("ROUND30_PILOT_AGGREGATE_COMPLETE selected=%s reason=%s\n", ...
    strjoin(selected.candidateId, ","), selected.reason);
end
