function output = auditR46(perUser, protocol)
%AUDITR46 Read-only paired and robust sensitivity audit of R46 final rows.

arguments
    perUser table
    protocol (1, 1) struct = r50.config()
end

snrValues = unique(perUser.snrDb, "stable").';
scopes = [string(snrValues), "equal-SNR"];
paired = table();
robust = table();
seedOffset = 0;
for scope = scopes
    selected = selectScope(perUser, scope);
    subset = perUser(selected, :);
    [fa, pa, positions] = errorMatrices(subset, scope, snrValues);
    difference = fa-pa;
    observedDifference = mean(difference, "all");
    observedRatio = mean(fa, "all")/mean(pa, "all");
    seedOffset = seedOffset+1;
    stream = RandStream("mt19937ar", ...
        Seed=protocol.r46Audit.seed+seedOffset);
    meanDifference = zeros(protocol.r46Audit.count, 1);
    mseRatio = zeros(protocol.r46Audit.count, 1);
    for b = 1:protocol.r46Audit.count
        sampled = randi(stream, positions, positions, 1);
        meanDifference(b) = mean(difference(sampled, :), "all");
        mseRatio(b) = mean(fa(sampled, :), "all") ...
            /mean(pa(sampled, :), "all");
    end
    alpha = (1-protocol.r46Audit.confidence)/2;
    paired = [paired; table(scope, positions, observedDifference, ...
        quantile(meanDifference, alpha), ...
        quantile(meanDifference, 1-alpha), std(meanDifference), ...
        observedRatio, quantile(mseRatio, alpha), ...
        quantile(mseRatio, 1-alpha), std(mseRatio), ...
        'VariableNames', {'scope', 'positionCount', ...
        'meanSquaredErrorDifferenceM2', 'differenceLower95', ...
        'differenceUpper95', 'differenceBootstrapStd', 'mseRatio', ...
        'ratioLower95', 'ratioUpper95', 'ratioBootstrapStd'})]; %#ok<AGROW>

    flatDifference = difference(:);
    flatFA = fa(:);
    flatPA = pa(:);
    [~, order] = sort(abs(flatDifference), "descend");
    trimCount = floor(protocol.r46Audit.trimFraction*numel(order));
    keepTrim = order(trimCount+1:end);
    keep3 = order(min(3, numel(order))+1:end);
    keep5 = order(min(5, numel(order))+1:end);
    robust = [robust; table(scope, numel(order), ...
        mean(flatFA(keepTrim))/mean(flatPA(keepTrim)), ...
        median(flatFA), median(flatPA), ...
        mean(sqrt(flatFA)>protocol.r46Audit.missThresholdM), ...
        mean(sqrt(flatPA)>protocol.r46Audit.missThresholdM), ...
        mean(flatFA(keep3))/mean(flatPA(keep3)), ...
        mean(flatFA(keep5))/mean(flatPA(keep5)), ...
        'VariableNames', {'scope', 'n', 'pairedTrimmed5PctMseRatio', ...
        'medianSquaredErrorPFA', 'medianSquaredErrorPA', ...
        'missRatePFA', 'missRatePA', 'ratioAfterTop3Removal', ...
        'ratioAfterTop5Removal'})]; %#ok<AGROW>
end

allDifference = perUser.rangeError_P_FA.^2-perUser.rangeError_P_A.^2;
[~, order] = sort(abs(allDifference), "descend");
tail = table();
for fraction = protocol.r46Audit.topFractions
    count = max(1, ceil(fraction*numel(order)));
    selected = order(1:count);
    tail = [tail; table(fraction, count, ...
        sum(allDifference(selected))/sum(allDifference), ...
        sum(abs(allDifference(selected)))/sum(abs(allDifference)), ...
        'VariableNames', {'fraction', 'rowCount', ...
        'netDifferenceShare', 'absoluteDifferenceShare'})]; %#ok<AGROW>
end
topCount = min(20, numel(order));
topRows = perUser(order(1:topCount), ...
    ["positionId", "snrDb", "truthThetaDeg", "truthRangeM", ...
    "rangeError_P_FA", "rangeError_P_A"]);
topRows.squaredErrorDifference = allDifference(order(1:topCount));
output = struct(version="R50-R46-read-only-robust-audit-v1", ...
    paired=paired, robust=robust, tail=tail, topRows=topRows, ...
    frozenPrimaryConclusionUnchanged=true);
end

function [fa, pa, positionCount] = errorMatrices(subset, scope, snrValues)
if scope == "equal-SNR"
    positions = unique(subset.positionId, "stable");
    positionCount = numel(positions);
    fa = zeros(positionCount, numel(snrValues));
    pa = zeros(positionCount, numel(snrValues));
    for i = 1:positionCount
        for j = 1:numel(snrValues)
            selected = subset.positionId == positions(i) ...
                & subset.snrDb == snrValues(j);
            fa(i, j) = subset.rangeError_P_FA(selected)^2;
            pa(i, j) = subset.rangeError_P_A(selected)^2;
        end
    end
else
    positionCount = height(subset);
    fa = subset.rangeError_P_FA.^2;
    pa = subset.rangeError_P_A.^2;
end
end

function selected = selectScope(perUser, scope)
if scope == "equal-SNR"
    selected = true(height(perUser), 1);
else
    selected = perUser.snrDb == str2double(scope);
end
end
