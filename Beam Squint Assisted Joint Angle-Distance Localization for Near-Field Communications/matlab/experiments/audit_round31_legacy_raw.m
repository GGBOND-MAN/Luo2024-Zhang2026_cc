function audit_round31_legacy_raw()
%AUDIT_ROUND31_LEGACY_RAW Reanalyze saved solvers without response calls.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
protocol = r31.config();
audit = table();
components = ["angle", "profile"];

for row = 1:height(raw.pilot.design)
    item = raw.pilot.results{row}.candidateResults{raw.l06PilotIndex};
    solvers = {item.angleSolver, item.profileSolver};
    feasibleValues = [item.front.selected.thetaDeg, item.front.selected.rangeM];
    tolerances = [protocol.angleToleranceDeg, protocol.profileToleranceM];
    for component = 1:2
        entry = auditSolver(raw.pilot.design(row, :), ...
            components(component), solvers{component}, ...
            feasibleValues(component), tolerances(component));
        audit = [audit; entry]; %#ok<AGROW>
    end
end

affected = audit(audit.gridBestMinusFinal > protocol.scoreTolerance ...
    | audit.feasibleBestMinusFinal > protocol.scoreTolerance ...
    | abs(audit.candidateBestMinusFinal) > protocol.scoreTolerance, :);
revisedSummary = r31.reviseRound30Summary(raw.pilot.design, ...
    raw.pilot.results, raw.pilot.expected.protocol.candidates, protocol);
[selection, selected] = r31.selectDeployments( ...
    revisedSummary, raw.pilot.baseline, protocol);

folder = fullfile(project, "results", "full_spectrum", ...
    "round31_legacy_reanalysis_v2");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(audit, fullfile(folder, "legacy_solver_score_audit.csv"));
writetable(affected, fullfile(folder, "affected_rows.csv"));
writetable(revisedSummary, fullfile(folder, "revised_method_summary.csv"));
writetable(selection, fullfile(folder, "revised_selection_audit.csv"));
writetable(raw.source, fullfile(folder, "source_hashes.csv"));
identity = struct(version="R31-legacy-reanalysis-v2", ...
    pilotHash=raw.pilotHash, baselineHash=raw.baselineHash, ...
    protocol=protocol, noResponseRecomputation=true);
save(fullfile(folder, "audit.mat"), "audit", "affected", ...
    "revisedSummary", "selection", "selected", "identity");
save(fullfile(folder, "selection.mat"), "selection", "selected", "identity");
fprintf("R31_LEGACY_RAW_AUDIT rows=%d affected=%d reason=%s\n", ...
    height(audit), height(affected), selected.reason);
end

function entry = auditSolver(row, component, solver, feasibleValue, tolerance)
[distance, nearest] = min(abs(solver.candidates-feasibleValue));
retained = distance <= tolerance;
feasibleScore = nan;
if retained
    feasibleScore = solver.candidateScore(nearest);
end
entry = table(row.seed, row.snrDb, component, solver.score, ...
    max(solver.gridScore), max(solver.gridScore)-solver.score, ...
    feasibleValue, feasibleScore, feasibleScore-solver.score, retained, ...
    max(solver.candidateScore)-solver.score, ...
    'VariableNames', {'seed', 'snrDb', 'component', 'finalScore', ...
    'gridBestScore', 'gridBestMinusFinal', 'feasibleValue', ...
    'feasibleBestScore', 'feasibleBestMinusFinal', 'feasibleRetained', ...
    'candidateBestMinusFinal'});
end
