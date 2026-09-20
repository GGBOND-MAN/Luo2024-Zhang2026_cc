function [selection, selected] = selectCandidates(summary, baseline, protocol)
%SELECTCANDIDATES Apply frozen engineering thresholds and retain at most two.

arguments
    summary table
    baseline table
    protocol (1, 1) struct
end

selection = table();
for candidateId = unique(summary.candidateId, "stable").'
    methodRows = table();
    for method = ["H_L", "P_L"]
        maximumAngleRatio = 0;
        maximumRangeRatio = 0;
        maximumPositionRatio = 0;
        maximumP95Ratio = 0;
        maximumMissIncrease = 0;
        for snrDb = [-10, 0, 20]
            row = summary(summary.candidateId == candidateId ...
                & summary.method == method & summary.snrDb == snrDb, :);
            c = baseline(baseline.method == "C_star" ...
                & baseline.snrDb == snrDb, :);
            h = baseline(baseline.method == "H_star" ...
                & baseline.snrDb == snrDb, :);
            angleRatio = row.angleRmseDeg/c.angleRmseDeg;
            rangeRatio = row.rangeRmseM/min(c.rmseM, h.rmseM);
            positionRatio = row.positionRmseM/min(c.jointRmseM, h.jointRmseM);
            p95Ratio = row.p95RangeM/min(c.p95M, h.p95M);
            maximumAngleRatio = max(maximumAngleRatio, angleRatio);
            maximumRangeRatio = max(maximumRangeRatio, rangeRatio);
            maximumPositionRatio = max(maximumPositionRatio, positionRatio);
            maximumP95Ratio = max(maximumP95Ratio, p95Ratio);
            maximumMissIncrease = max(maximumMissIncrease, ...
                row.missOver1m-min(c.missOver1m, h.missOver1m));
        end
        maximumRatio = max([maximumAngleRatio, maximumRangeRatio, ...
            maximumPositionRatio, maximumP95Ratio]);
        allRows = summary(summary.candidateId == candidateId ...
            & summary.method == method, :);
        meanEquivalent = mean(allRows.meanEquivalentResponses);
        passAccuracy = maximumAngleRatio ...
            <= protocol.acceptance.angleRmseRatio ...
            && maximumRangeRatio <= protocol.acceptance.rangeRmseRatio ...
            && maximumPositionRatio ...
            <= protocol.acceptance.positionRmseRatio ...
            && maximumP95Ratio <= protocol.acceptance.p95Ratio ...
            && maximumMissIncrease <= protocol.acceptance.missRateIncrease;
        passComplexity = meanEquivalent ...
            <= protocol.acceptance.maxFullEquivalentResponses;
        methodRows = [methodRows; table(candidateId, method, ...
            maximumAngleRatio, maximumRangeRatio, maximumPositionRatio, ...
            maximumP95Ratio, maximumRatio, maximumMissIncrease, ...
            meanEquivalent, passAccuracy, passComplexity)]; %#ok<AGROW>
    end
    [~, best] = min(methodRows.maximumRatio);
    selection = [selection; methodRows(best, :)]; %#ok<AGROW>
end

selection.pareto = paretoMask(selection.maximumRatio, ...
    selection.meanEquivalent);
qualified = selection.passAccuracy & selection.passComplexity;
if any(qualified)
    pool = selection(qualified, :);
    pool = sortrows(pool, ["meanEquivalent", "maximumRatio"]);
    reason = "met-predeclared-engineering-thresholds";
else
    pool = selection(selection.pareto, :);
    pool = sortrows(pool, ["maximumRatio", "meanEquivalent"]);
    reason = "no-candidate-met-all-thresholds-pareto-diagnostic-only";
end
pool = pool(1:min(protocol.maxSelectedCandidates, height(pool)), :);
selected = struct(candidateId=pool.candidateId, ...
    preferredOutput=pool.method, reason=reason, ...
    thresholds=protocol.acceptance, ...
    developmentOnly=true, independentValidation=false);
selection.selected = ismember(selection.candidateId, selected.candidateId);
selection.selectionReason = repmat(reason, height(selection), 1);
end

function keep = paretoMask(accuracyCost, computationCost)
count = numel(accuracyCost);
keep = true(count, 1);
for index = 1:count
    noWorse = accuracyCost <= accuracyCost(index) ...
        & computationCost <= computationCost(index);
    strictlyBetter = accuracyCost < accuracyCost(index) ...
        | computationCost < computationCost(index);
    keep(index) = ~any(noWorse & strictlyBetter);
end
end
