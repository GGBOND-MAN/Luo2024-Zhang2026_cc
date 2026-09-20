function aggregate_round31_angle_controls()
%AGGREGATE_ROUND31_ANGLE_CONTROLS Summarize the fixed 60-user C/A/B run.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
folder = fullfile(project, "results", "full_spectrum", ...
    "round31_angle_controls_v2");
saved = load(fullfile(folder, "result.mat"), "identity", "results");
marker = load(fullfile(folder, "COMPLETE.mat"), "identity", "failed");
if ~isequaln(saved.identity, marker.identity) || any(marker.failed)
    error("r31:IncompleteAngleControls", ...
        "The C/A/B control result is incomplete or contains retained failures.");
end
[summary, perUser] = r31.summarizeControls(raw.pilot.design, saved.results);
decision = r31.evaluateControlThresholds( ...
    summary, raw.pilot.baseline, r31.config());
cPass = decision.anglePass(decision.method == "C_enhanced");
aPass = decision.anglePass(decision.method == "H_A");
sliceDiagnosticTriggered = cPass && ~aPass;
writetable(summary, fullfile(folder, "method_summary.csv"));
writetable(perUser, fullfile(folder, "per_user_estimates.csv"));
writetable(decision, fullfile(folder, "threshold_decision.csv"));
identity = saved.identity;
save(fullfile(folder, "aggregate.mat"), ...
    "identity", "summary", "perUser", "decision", ...
    "sliceDiagnosticTriggered", "-v7.3");
fprintf("ROUND31_ANGLE_CONTROLS_AGGREGATE_COMPLETE sliceTrigger=%d\n", ...
    sliceDiagnosticTriggered);
end
