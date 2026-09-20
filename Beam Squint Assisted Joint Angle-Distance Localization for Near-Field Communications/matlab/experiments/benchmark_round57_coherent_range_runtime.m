function output = benchmark_round57_coherent_range_runtime()
%BENCHMARK_ROUND57_COHERENT_RANGE_RUNTIME Measure gate G10 for R57.
%   Times the deployable standalone P_FACR against C_enhanced under the
%   frozen r53-style matched-timing protocol. The reporting-only ablation
%   branches are not part of the deployable method and are not timed.
%   The timing rows come from the smoke design, which has already been run,
%   so no unread development row is touched before the development stage.

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r57.config();
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
design = r57.design(protocol, "smoke");
timing = r57.matchedTiming(design, cfg, scan, protocol);

folder = fullfile(project, "results", "full_spectrum", ...
    "round57_coherent_range_timing_v1");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(timing.rows, fullfile(folder, "timing_rows.csv"));
writetable(timing.summary, fullfile(folder, "timing_summary.csv"));
writetable(timing.comparison, fullfile(folder, "timing_comparison.csv"));
output = timing;
disp(timing.summary);
disp(timing.comparison);
fprintf("ROUND57_G10 ratio=%.5f pass=%d\n", ...
    timing.comparison.meanRuntimeRatio, timing.comparison.pass);
end
