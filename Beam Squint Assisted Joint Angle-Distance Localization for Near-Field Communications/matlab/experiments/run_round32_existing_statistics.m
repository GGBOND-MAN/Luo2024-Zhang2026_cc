function run_round32_existing_statistics()
%RUN_ROUND32_EXISTING_STATISTICS Analyze only the existing R31 raw results.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
output = r32.summarizeExisting(project);
folder = fullfile(project, "results", "full_spectrum", ...
    "round32_pa_finite_closeout_v1", "existing_raw_statistics");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(output.perUser, fullfile(folder, "per_user_existing_raw.csv"));
writetable(output.methodSummary, fullfile(folder, "method_summary.csv"));
writetable(output.comparisons, fullfile(folder, "paired_comparisons.csv"));
writetable(output.thresholdAudit, fullfile(folder, ...
    "r29_engineering_threshold_audit.csv"));
writetable(output.sameFrontAudit, fullfile(folder, ...
    "same_front_C_descriptive_ratios.csv"));
source = r32.manifest(project);
writetable(source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "result.mat"), "output", "source", "-v7.3");
fprintf("ROUND32_EXISTING_RAW_STATISTICS_COMPLETE rows=%d\n", ...
    height(output.perUser));
end
