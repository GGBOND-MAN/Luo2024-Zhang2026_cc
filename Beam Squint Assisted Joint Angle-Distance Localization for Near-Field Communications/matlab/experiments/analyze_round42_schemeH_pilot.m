function output = analyze_round42_schemeH_pilot()
%ANALYZE_ROUND42_SCHEMEH_PILOT Derive read-only R42 mechanism tables.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
root = fullfile(project, "results", "full_spectrum", ...
    "round42_schemeH_pa_free_joint_development_v1", "positions_10");
loaded = load(fullfile(root, "result.mat"), "identity", "results", "summary");
if loaded.identity.completedRows ~= 30 ...
        || loaded.identity.finalTrialsReadOrExecuted ~= 0
    error("r42:AnalysisIdentity", ...
        "R42 pilot analysis requires the completed 30-row development result.");
end

diagnostics = jointDiagnostics(loaded.results);
writetable(diagnostics, fullfile(root, "joint_diagnostics.csv"));
ablation = ablationComparisons(loaded.summary.perUser);
writetable(ablation, fullfile(root, "ablation_vs_pa.csv"));
status = groupcounts(diagnostics, "status");
writetable(status, fullfile(root, "joint_status_counts.csv"));
mechanism = table(height(diagnostics), ...
    sum(diagnostics.selectedCandidate ~= diagnostics.frontSelected), ...
    median(abs(diagnostics.rangeStepM)), max(abs(diagnostics.rangeStepM)), ...
    mean(diagnostics.costReduction), ...
    'VariableNames', {'rows', 'candidateModeChanges', ...
    'medianAbsRangeStepM', 'maxAbsRangeStepM', 'meanCostReduction'});
writetable(mechanism, fullfile(root, "mechanism_summary.csv"));
output = struct(diagnostics=diagnostics, ablation=ablation, ...
    status=status, mechanism=mechanism, estimationExecuted=false, ...
    finalDataRead=false);
save(fullfile(root, "posthoc_analysis.mat"), "output");
disp(ablation);
disp(status);
disp(mechanism);
end

function output = jointDiagnostics(results)
n = numel(results);
seed = zeros(n, 1);
snrDb = zeros(n, 1);
truthRangeM = zeros(n, 1);
paRangeM = zeros(n, 1);
initialRangeM = zeros(n, 1);
jointRangeM = zeros(n, 1);
costReduction = zeros(n, 1);
acceptedSteps = zeros(n, 1);
status = strings(n, 1);
selectedCandidate = zeros(n, 1);
frontSelected = zeros(n, 1);
for index = 1:n
    item = results{index};
    seed(index) = item.seed;
    snrDb(index) = item.snrDb;
    truthRangeM(index) = item.truthRangeM;
    paRangeM(index) = item.rangeM(1);
    initialRangeM(index) = item.h.joint.initialRangeM;
    jointRangeM(index) = item.h.joint.rangeM;
    costReduction(index) = item.h.joint.costReduction;
    acceptedSteps(index) = item.h.joint.acceptedSteps;
    status(index) = item.h.joint.status;
    selectedCandidate(index) = item.h.selectedFrontCandidateIndex;
    frontSelected(index) = item.h.front.selectedIndex;
end
paRangeErrorM = paRangeM-truthRangeM;
initialRangeErrorM = initialRangeM-truthRangeM;
jointRangeErrorM = jointRangeM-truthRangeM;
rangeStepM = jointRangeM-initialRangeM;
jointVsPaSquaredChange = jointRangeErrorM.^2-paRangeErrorM.^2;
output = table(seed, snrDb, truthRangeM, paRangeM, initialRangeM, ...
    jointRangeM, paRangeErrorM, initialRangeErrorM, jointRangeErrorM, ...
    rangeStepM, jointVsPaSquaredChange, costReduction, acceptedSteps, ...
    status, selectedCandidate, frontSelected);
end

function output = ablationComparisons(perUser)
methods = ["H_array", "H_joint", "F_L06"];
snrValues = unique(perUser.snrDb).';
output = table();
for method = methods
    for snrDb = [snrValues, nan]
        if isnan(snrDb)
            pa = perUser(perUser.method == "P_A", :);
            candidate = perUser(perUser.method == method, :);
        else
            pa = perUser(perUser.method == "P_A" ...
                &perUser.snrDb == snrDb, :);
            candidate = perUser(perUser.method == method ...
                &perUser.snrDb == snrDb, :);
        end
        angleRatio = mean(candidate.angleErrorDeg.^2) ...
            /mean(pa.angleErrorDeg.^2);
        rangeRatio = mean(candidate.rangeErrorM.^2) ...
            /mean(pa.rangeErrorM.^2);
        row = table(method, snrDb, angleRatio, ...
            100*(1-sqrt(angleRatio)), rangeRatio, ...
            100*(1-sqrt(rangeRatio)), ...
            mean(candidate.runtimeSeconds)/mean(pa.runtimeSeconds), ...
            'VariableNames', {'method', 'snrDb', 'angleMseRatio', ...
            'angleRmseImprovementPct', 'rangeMseRatio', ...
            'rangeRmseImprovementPct', 'runtimeRatio'});
        output = [output; row]; %#ok<AGROW>
    end
end
end
