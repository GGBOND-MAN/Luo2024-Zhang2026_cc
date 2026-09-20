function aggregate_round30_selected()
%AGGREGATE_ROUND30_SELECTED Summarize the selected candidates on all 600 users.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
setup = r30.setup(project, "calibration600");
root = fullfile(project, "results", "full_spectrum", ...
    "round30_calibration600_v1");
listing = dir(fullfile(root, "shard_*", "result.mat"));
if isempty(listing)
    error("r30:NoSelectedShards", "No completed selected-candidate shards were found.");
end
design = table();
results = cell(0, 1);
seen = zeros(numel(listing), 1);
for index = 1:numel(listing)
    saved = load(fullfile(listing(index).folder, "result.mat"));
    marker = load(fullfile(listing(index).folder, "COMPLETE.mat"));
    r30.assertIdentity(marker.identity, saved.identity);
    r30.assertIdentity(saved.identity.setup, setup);
    design = [design; saved.identity.design]; %#ok<AGROW>
    results = [results; saved.results]; %#ok<AGROW>
    seen(index) = saved.identity.shardId;
    candidates = saved.identity.candidates;
    selected = saved.identity.selected;
end
if ~isequal(sort(seen).', 1:saved.identity.shardCount)
    error("r30:IncompleteSelectedShardSet", ...
        "The selected-candidate shard set is incomplete.");
end
[design, order] = sortrows(design, ["snrDb", "trialIndex"]);
results = results(order);
if ~isequaln(design, setup.design)
    error("r30:SelectedDesignMismatch", ...
        "The selected-candidate aggregate does not cover the frozen 600 users.");
end
success = cellfun(@(item) item.success, results);
folder = fullfile(root, "aggregate");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(design(~success, :), fullfile(folder, "failed_rows.csv"));
if ~all(success)
    error("r30:SelectedFailures", ...
        "Failures are retained; no complete-case table was produced.");
end
summary = r30.summarize(design, results, candidates);
writetable(summary, fullfile(folder, "method_and_cost_summary.csv"));
writetable(setup.source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "aggregate.mat"), ...
    "setup", "design", "results", "candidates", "selected", ...
    "summary", "-v7.3");
fprintf("ROUND30_SELECTED_AGGREGATE_COMPLETE users=%d candidates=%d\n", ...
    height(design), height(candidates));
end
