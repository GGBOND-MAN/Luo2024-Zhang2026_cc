function aggregate_round30_selected_baselines()
%AGGREGATE_ROUND30_SELECTED_BASELINES Summarize the same-front controls.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
setup = r30.setup(project, "pilot");
root = fullfile(project, "results", "full_spectrum", ...
    "round30_selected_baselines_v1");
saved = load(fullfile(root, "result.mat"));
r30.assertIdentity(saved.identity.setup, setup);
selectedRows = find(ismember(setup.protocol.candidates.candidateId, ...
    saved.identity.selected.candidateId));
candidates = setup.protocol.candidates(selectedRows, :);
if any(cellfun(@isempty, saved.results), "all")
    error("r30:IncompleteBaselineResults", ...
        "Every selected candidate and pilot user must contain both baselines.");
end
summary = r30.summarizeBaselines( ...
    saved.identity.design, saved.results, candidates);
publicCost = r30.baselineComplexity(setup.cfg, setup.protocol.publicZhang);
enhancedCost = r30.baselineComplexity(setup.cfg, setup.enhancedAlgorithm);
writetable(summary, fullfile(root, "method_summary.csv"));
save(fullfile(root, "aggregate.mat"), ...
    "setup", "candidates", "summary", "publicCost", "enhancedCost");
fprintf("ROUND30_SELECTED_BASELINES_AGGREGATE_COMPLETE rows=%d\n", ...
    height(summary));
end
