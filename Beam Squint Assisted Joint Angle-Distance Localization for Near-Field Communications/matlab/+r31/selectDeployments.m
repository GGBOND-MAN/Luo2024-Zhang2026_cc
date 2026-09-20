function [selection, selected] = selectDeployments(summary, baseline, protocol)
%SELECTDEPLOYMENTS Evaluate each candidate-output pair before Pareto selection.

arguments
    summary table
    baseline table
    protocol (1, 1) struct
end

deployments = unique(summary(:, ["candidateId", "method"]), "rows", "stable");
selection = table();
for index = 1:height(deployments)
    candidateId = deployments.candidateId(index);
    output = deployments.method(index);
    if ~ismember(output, ["H_L", "P_L"])
        continue;
    end
    metrics = deploymentMetrics(summary, baseline, ...
        candidateId, output, protocol);
    selection = [selection; metrics]; %#ok<AGROW>
end

objectives = [selection.maximumNormalizedRisk, ...
    selection.meanDeploymentSeconds, selection.meanEquivalentResponses];
selection.pareto = paretoMask(objectives);
qualified = selection.passAccuracy & selection.passComplexity;
if any(qualified)
    pool = selection(qualified & selection.pareto, :);
    if isempty(pool)
        pool = selection(qualified, :);
    end
    pool = sortrows(pool, ...
        ["meanDeploymentSeconds", "maximumNormalizedRisk"]);
    reason = "met-predeclared-engineering-thresholds";
else
    pool = selection(selection.pareto, :);
    pool = sortrows(pool, ...
        ["maximumNormalizedRisk", "meanDeploymentSeconds"]);
    reason = "no-deployment-met-all-thresholds-pareto-diagnostic-only";
end
pool = pool(1:min(protocol.maxSelectedDeployments, height(pool)), :);
selected = struct(candidateId=pool.candidateId, output=pool.output, ...
    reason=reason, thresholds=protocol.acceptance, developmentOnly=true, ...
    independentValidation=false, formalExpansionAllowed=any(qualified));
selection.selected = ismember( ...
    strcat(selection.candidateId, "|", selection.output), ...
    strcat(selected.candidateId, "|", selected.output));
selection.selectionReason = repmat(reason, height(selection), 1);
end

function metrics = deploymentMetrics(summary, baseline, ...
    candidateId, output, protocol)
maximumAngleRatio = 0;
maximumRangeRatio = 0;
maximumPositionRatio = 0;
maximumP95Ratio = 0;
maximumMissIncrease = 0;
for snrDb = [-10, 0, 20]
    row = summary(summary.candidateId == candidateId ...
        & summary.method == output & summary.snrDb == snrDb, :);
    c = baseline(baseline.method == "C_star" ...
        & baseline.snrDb == snrDb, :);
    h = baseline(baseline.method == "H_star" ...
        & baseline.snrDb == snrDb, :);
    maximumAngleRatio = max(maximumAngleRatio, ...
        row.angleRmseDeg/c.angleRmseDeg);
    maximumRangeRatio = max(maximumRangeRatio, ...
        row.rangeRmseM/min(c.rmseM, h.rmseM));
    maximumPositionRatio = max(maximumPositionRatio, ...
        row.positionRmseM/min(c.jointRmseM, h.jointRmseM));
    maximumP95Ratio = max(maximumP95Ratio, ...
        row.p95RangeM/min(c.p95M, h.p95M));
    maximumMissIncrease = max(maximumMissIncrease, ...
        row.missOver1m-min(c.missOver1m, h.missOver1m));
end

rows = summary(summary.candidateId == candidateId ...
    & summary.method == output, :);
meanEquivalent = mean(rows.meanEquivalentResponses);
meanSeconds = mean(rows.meanDeploymentSeconds);
normalizedRisk = [maximumAngleRatio/protocol.acceptance.angleRmseRatio, ...
    maximumRangeRatio/protocol.acceptance.rangeRmseRatio, ...
    maximumPositionRatio/protocol.acceptance.positionRmseRatio, ...
    maximumP95Ratio/protocol.acceptance.p95Ratio, ...
    max(0, maximumMissIncrease)/protocol.acceptance.missRateIncrease];
maximumNormalizedRisk = max(normalizedRisk);
passAccuracy = all(normalizedRisk <= 1);
passComplexity = meanEquivalent ...
    <= protocol.acceptance.maxFullEquivalentResponses;

metrics = table(candidateId, output, maximumAngleRatio, ...
    maximumRangeRatio, maximumPositionRatio, maximumP95Ratio, ...
    maximumMissIncrease, maximumNormalizedRisk, meanEquivalent, ...
    meanSeconds, passAccuracy, passComplexity, ...
    'VariableNames', {'candidateId', 'output', 'maximumAngleRatio', ...
    'maximumRangeRatio', 'maximumPositionRatio', 'maximumP95Ratio', ...
    'maximumMissIncrease', 'maximumNormalizedRisk', ...
    'meanEquivalentResponses', 'meanDeploymentSeconds', ...
    'passAccuracy', 'passComplexity'});
end

function keep = paretoMask(objectives)
count = size(objectives, 1);
keep = true(count, 1);
for index = 1:count
    noWorse = all(objectives <= objectives(index, :), 2);
    strictlyBetter = any(objectives < objectives(index, :), 2);
    keep(index) = ~any(noWorse & strictlyBetter);
end
end
