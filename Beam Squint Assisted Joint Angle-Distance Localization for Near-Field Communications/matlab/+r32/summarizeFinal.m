function output = summarizeFinal(design, results, protocol)
%SUMMARIZEFINAL Apply the frozen position-cluster final-test analysis.

arguments
    design table
    results cell
    protocol (1, 1) struct = r32.config()
end

if height(design) ~= 1400 || numel(results) ~= height(design) ...
        || any(cellfun(@isempty, results))
    error("r32:IncompleteFinalResults", ...
        "The final analysis requires all 1400 frozen paired trials.");
end
failed = cellfun(@(x) ~x.success, results);
if any(failed)
    error("r32:FinalFailuresRequireAudit", ...
        "Final failures must be audited before the primary estimand is formed.");
end

methodNames = results{1}.methodNames;
theta = cell2mat(cellfun(@(x) x.thetaDeg, results, UniformOutput=false));
range = cell2mat(cellfun(@(x) x.rangeM, results, UniformOutput=false));
perUser = table();
summary = table();
for methodIndex = 1:numel(methodNames)
    [angleError, rangeError, positionError] = errors( ...
        design, theta(:, methodIndex), range(:, methodIndex));
    rows = table(design.positionId, design.seed, design.snrDb, ...
        repmat(methodNames(methodIndex), height(design), 1), ...
        theta(:, methodIndex), range(:, methodIndex), angleError, ...
        rangeError, positionError, 'VariableNames', {'positionId', ...
        'seed', 'snrDb', 'method', 'thetaDeg', 'rangeM', ...
        'angleErrorDeg', 'rangeErrorM', 'positionErrorM'});
    perUser = [perUser; rows]; %#ok<AGROW>
    for snrDb = protocol.finalTest.snrDb
        selected = rows.snrDb == snrDb;
        summary = [summary; methodRow(rows(selected, :))]; %#ok<AGROW>
    end
end

primary = primaryFamilies(perUser, protocol);
secondary = table();
for reference = ["C_enhanced", "H_A", "C_public"]
    for snrDb = protocol.finalTest.snrDb
        pa = perUser(perUser.method == "P_A" & perUser.snrDb == snrDb, :);
        other = perUser(perUser.method == reference ...
            & perUser.snrDb == snrDb, :);
        for metric = ["angle", "range", "position"]
            secondary = [secondary; pairedRow(pa, other, metric, reference)]; %#ok<AGROW>
        end
    end
end
output = struct(perUser=perUser, summary=summary, primary=primary, ...
    secondary=secondary, failed=failed);
end

function output = primaryFamilies(perUser, protocol)
snrValues = protocol.finalTest.snrDb;
positionIds = unique(perUser.positionId, "stable");
n = numel(positionIds);
rangeDelta = zeros(n, numel(snrValues));
for snrIndex = 1:numel(snrValues)
    snrDb = snrValues(snrIndex);
    pa = sortrows(perUser(perUser.method == "P_A" ...
        & perUser.snrDb == snrDb, :), "positionId");
    c = sortrows(perUser(perUser.method == "C_enhanced" ...
        & perUser.snrDb == snrDb, :), "positionId");
    rangeDelta(:, snrIndex) = pa.rangeErrorM.^2-c.rangeErrorM.^2;
end

stream = RandStream("mt19937ar", Seed=20260910);
bootstrapCount = 20000;
indices = randi(stream, n, n, bootstrapCount);
rangeObserved = mean(rangeDelta, 1);
rangeBootstrap = zeros(bootstrapCount, numel(snrValues));
angleObserved = zeros(1, numel(snrValues));
angleBootstrap = zeros(bootstrapCount, numel(snrValues));
for snrIndex = 1:numel(snrValues)
    rangeBootstrap(:, snrIndex) = squeeze(mean( ...
        rangeDelta(indices, snrIndex), 1));
    pa = sortrows(perUser(perUser.method == "P_A" ...
        & perUser.snrDb == snrValues(snrIndex), :), "positionId");
    c = sortrows(perUser(perUser.method == "C_enhanced" ...
        & perUser.snrDb == snrValues(snrIndex), :), "positionId");
    paSquared = pa.angleErrorDeg.^2;
    cSquared = c.angleErrorDeg.^2;
    angleObserved(snrIndex) = log(mean(paSquared)/mean(cSquared));
    paBoot = squeeze(mean(paSquared(indices), 1));
    cBoot = squeeze(mean(cSquared(indices), 1));
    angleBootstrap(:, snrIndex) = log(paBoot./cBoot);
end

rangeUpper = simultaneousUpper(rangeObserved, rangeBootstrap);
angleUpperLog = simultaneousUpper(angleObserved, angleBootstrap);
output = table(snrValues(:), rangeObserved(:), rangeUpper(:), ...
    rangeUpper(:) < 0, exp(angleObserved(:)), exp(angleUpperLog(:)), ...
    exp(angleUpperLog(:)) < protocol.finalTest.angleClaimMarginMseRatio, ...
    'VariableNames', {'snrDb', 'rangeMseDifferencePaMinusC', ...
    'rangeSimultaneousUpper95', 'rangeSuperiorityPass', ...
    'angleMseRatioPaOverC', 'angleRatioSimultaneousUpper95', ...
    'angleNoninferiorityPass'});
end

function upper = simultaneousUpper(observed, bootstrap)
scale = std(bootstrap, 0, 1);
active = scale > 0;
statistics = zeros(size(bootstrap));
statistics(:, active) = (bootstrap(:, active)-observed(active))./scale(active);
critical = quantile(max(statistics, [], 2), 0.95);
upper = observed+critical*scale;
upper(~active) = observed(~active);
end

function entry = methodRow(rows)
angleSquared = rows.angleErrorDeg.^2;
rangeSquared = rows.rangeErrorM.^2;
positionSquared = rows.positionErrorM.^2;
ordered = sort(rangeSquared, "descend");
tailCount = max(1, ceil(0.10*height(rows)));
tailShare = sum(ordered(1:tailCount))/max(sum(ordered), realmin);
entry = table(rows.snrDb(1), rows.method(1), height(rows), ...
    sqrt(mean(angleSquared)), sqrt(mean(rangeSquared)), ...
    sqrt(mean(positionSquared)), median(abs(rows.rangeErrorM)), ...
    quantile(abs(rows.rangeErrorM), 0.90), ...
    quantile(abs(rows.rangeErrorM), 0.95), ...
    quantile(abs(rows.rangeErrorM), 0.99), ...
    mean(abs(rows.rangeErrorM) > 1), tailShare, ...
    'VariableNames', {'snrDb', 'method', 'n', 'angleRmseDeg', ...
    'rangeRmseM', 'positionRmseM', 'medianRangeM', 'p90RangeM', ...
    'p95RangeM', 'p99RangeM', 'missOver1m', 'top10RangeSseShare'});
end

function entry = pairedRow(pa, reference, metric, referenceName)
switch metric
    case "angle"
        a = abs(pa.angleErrorDeg);
        b = abs(reference.angleErrorDeg);
    case "range"
        a = abs(pa.rangeErrorM);
        b = abs(reference.rangeErrorM);
    otherwise
        a = pa.positionErrorM;
        b = reference.positionErrorM;
end
delta = a.^2-b.^2;
entry = table(pa.snrDb(1), referenceName, metric, mean(delta), ...
    mean(a < b), mean(a == b), mean(a <= b), ...
    'VariableNames', {'snrDb', 'reference', 'metric', ...
    'meanSquaredErrorDifference', 'strictWinRate', 'tieRate', ...
    'nonWorseRate'});
end

function [angleError, rangeError, positionError] = errors(design, theta, range)
angleError = theta-design.truthThetaDeg;
rangeError = range-design.truthRangeM;
xError = range.*sind(theta)-design.truthRangeM.*sind(design.truthThetaDeg);
yError = range.*cosd(theta)-design.truthRangeM.*cosd(design.truthThetaDeg);
positionError = hypot(xError, yError);
end
