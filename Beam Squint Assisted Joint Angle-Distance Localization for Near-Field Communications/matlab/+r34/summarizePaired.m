function output = summarizePaired(design, results, protocol)
%SUMMARIZEPAIRED Apply the frozen paired estimands on a complete cluster design.
% This general-size entry exists for deterministic software tests. The final
% aggregator calls summarizeFinal, which additionally enforces the 1400-row hash.

arguments
    design table
    results cell
    protocol (1, 1) struct = r34.config()
end

validateInputs(design, results, protocol);
methodNames = ["P_A", "C_enhanced", "H_A", "C_public", "F_L06"];
theta = zeros(height(design), numel(methodNames));
range = zeros(height(design), numel(methodNames));
for index = 1:height(design)
    theta(index, :) = results{index}.thetaDeg;
    range(index, :) = results{index}.rangeM;
end

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
        selectedRows = sortrows(rows(rows.snrDb == snrDb, :), ...
            "positionId");
        summary = [summary; methodRow(selectedRows, protocol)]; %#ok<AGROW>
    end
end

[primary, bootstrapAudit] = primaryFamilies(perUser, protocol);
secondary = table();
for reference = ["C_enhanced", "H_A", "C_public"]
    for snrDb = protocol.finalTest.snrDb
        pa = sortrows(perUser(perUser.method == "P_A" ...
            & perUser.snrDb == snrDb, :), "positionId");
        other = sortrows(perUser(perUser.method == reference ...
            & perUser.snrDb == snrDb, :), "positionId");
        for metric = ["angle", "range", "position"]
            secondary = [secondary; pairedRow( ...
                pa, other, metric, reference)]; %#ok<AGROW>
        end
    end
end
output = struct(perUser=perUser, summary=summary, primary=primary, ...
    secondary=secondary, failed=false(height(design), 1), ...
    bootstrapAudit=bootstrapAudit);
end

function validateInputs(design, results, protocol)
required = ["positionId", "seed", "snrDb", ...
    "truthThetaDeg", "truthRangeM"];
if ~all(ismember(required, string(design.Properties.VariableNames)))
    error("r34:FinalDesignColumns", ...
        "The paired design is missing a required field.");
end
if numel(results) ~= height(design) || any(cellfun(@isempty, results))
    error("r34:IncompleteFinalResults", ...
        "Every paired design row requires exactly one result.");
end
keys = design(:, cellstr(["positionId", "snrDb"]));
if height(unique(keys, "rows")) ~= height(design) ...
        || numel(unique(design.seed)) ~= height(design)
    error("r34:DuplicateFinalRows", ...
        "Position/SNR keys and trial seeds must be unique.");
end
snrValues = protocol.finalTest.snrDb(:).';
positionIds = unique(design.positionId);
if height(design) ~= numel(positionIds)*numel(snrValues)
    error("r34:IncompletePositionClusters", ...
        "Every position must contain every frozen SNR exactly once.");
end
for position = positionIds.'
    rows = design.positionId == position;
    if ~isequal(sort(design.snrDb(rows)).', sort(snrValues)) ...
            || numel(unique(design.truthThetaDeg(rows))) ~= 1 ...
            || numel(unique(design.truthRangeM(rows))) ~= 1
        error("r34:IncompletePositionClusters", ...
            "Each position cluster must preserve truth across all SNR rows.");
    end
end

expectedMethods = ["P_A", "C_enhanced", "H_A", "C_public", "F_L06"];
for index = 1:height(design)
    item = results{index};
    itemRequired = ["success", "seed", "positionId", "snrDb", ...
        "methodNames", "thetaDeg", "rangeM"];
    if ~all(isfield(item, itemRequired))
        error("r34:MalformedFinalResult", ...
            "A result lacks frozen identity or estimate fields.");
    end
    if ~item.success
        error("r34:FinalFailuresRequireAudit", ...
            "Failed trials must be audited before primary inference.");
    end
    if item.seed ~= design.seed(index) ...
            || item.positionId ~= design.positionId(index) ...
            || item.snrDb ~= design.snrDb(index) ...
            || ~isequal(string(item.methodNames), expectedMethods) ...
            || numel(item.thetaDeg) ~= numel(expectedMethods) ...
            || numel(item.rangeM) ~= numel(expectedMethods) ...
            || any(~isfinite(item.thetaDeg)) ...
            || any(~isfinite(item.rangeM))
        error("r34:FinalResultIdentityMismatch", ...
            "A result does not match its exact design row and method order.");
    end
end
end

function [output, audit] = primaryFamilies(perUser, protocol)
snrValues = protocol.finalTest.snrDb(:).';
positionIds = unique(perUser.positionId);
clusterCount = numel(positionIds);
snrCount = numel(snrValues);
rangeDelta = zeros(clusterCount, snrCount);
paAngleSquared = zeros(clusterCount, snrCount);
cAngleSquared = zeros(clusterCount, snrCount);
for snrIndex = 1:snrCount
    pa = methodRows(perUser, "P_A", snrValues(snrIndex));
    c = methodRows(perUser, "C_enhanced", snrValues(snrIndex));
    if ~isequal(pa.positionId, positionIds) ...
            || ~isequal(c.positionId, positionIds)
        error("r34:PositionClusterAlignment", ...
            "Paired methods do not share the same ordered position clusters.");
    end
    rangeDelta(:, snrIndex) = pa.rangeErrorM.^2-c.rangeErrorM.^2;
    paAngleSquared(:, snrIndex) = pa.angleErrorDeg.^2;
    cAngleSquared(:, snrIndex) = c.angleErrorDeg.^2;
end

stream = RandStream("mt19937ar", Seed=protocol.statistics.bootstrapSeed);
bootstrapCount = protocol.statistics.bootstrapCount;
indices = randi(stream, clusterCount, clusterCount, bootstrapCount);
rangeObserved = mean(rangeDelta, 1);
rangeBootstrap = r34.clusterBootstrapMeans(rangeDelta, indices);
rangeUpper = r34.simultaneousUpper( ...
    rangeObserved, rangeBootstrap, 0.95);

paObserved = mean(paAngleSquared, 1);
cObserved = mean(cAngleSquared, 1);
[angleObservedLog, observedDefined] = safeLogRatio(paObserved, cObserved);
paBootstrap = r34.clusterBootstrapMeans(paAngleSquared, indices);
cBootstrap = r34.clusterBootstrapMeans(cAngleSquared, indices);
[angleBootstrapLog, bootstrapDefined] = ...
    safeLogRatio(paBootstrap, cBootstrap);
angleFamilyDefined = all(observedDefined) && all(bootstrapDefined, "all");
angleUpperLog = nan(1, snrCount);
if angleFamilyDefined
    angleUpperLog = r34.simultaneousUpper( ...
        angleObservedLog, angleBootstrapLog, 0.95);
end
angleRatio = exp(angleObservedLog);
angleUpper = exp(angleUpperLog);
anglePass = angleFamilyDefined ...
    & angleUpper < protocol.finalTest.angleClaimMarginMseRatio;

output = table(snrValues(:), rangeObserved(:), rangeUpper(:), ...
    rangeUpper(:) < 0, angleRatio(:), angleUpper(:), ...
    repmat(angleFamilyDefined, snrCount, 1), anglePass(:), ...
    'VariableNames', {'snrDb', 'rangeMseDifferencePaMinusC', ...
    'rangeSimultaneousUpper95', 'rangeSuperiorityPass', ...
    'angleMseRatioPaOverC', 'angleRatioSimultaneousUpper95', ...
    'angleFamilyDefined', 'angleNoninferiorityPass'});
audit = struct(version=protocol.statisticsVersion, ...
    clusterCount=clusterCount, bootstrapCount=bootstrapCount, ...
    bootstrapSeed=protocol.statistics.bootstrapSeed, ...
    sharedIndicesAcrossSnr=true, ...
    indexShape=size(indices), indexHash=r31.arrayHash(indices), ...
    implementation="reshape-index-vector-then-column-mean", ...
    confidence=0.95, separateFamilies=true);
end

function rows = methodRows(perUser, method, snrDb)
rows = sortrows(perUser(perUser.method == method ...
    & perUser.snrDb == snrDb, :), "positionId");
end

function [logRatio, defined] = safeLogRatio(numerator, denominator)
logRatio = nan(size(numerator));
positiveDenominator = denominator > 0;
logRatio(positiveDenominator) = log( ...
    numerator(positiveDenominator)./denominator(positiveDenominator));
positiveOverZero = denominator == 0 & numerator > 0;
logRatio(positiveOverZero) = inf;
defined = isfinite(logRatio);
end

function entry = methodRow(rows, protocol)
angleSquared = rows.angleErrorDeg.^2;
rangeSquared = rows.rangeErrorM.^2;
positionSquared = rows.positionErrorM.^2;
ordered = sort(rangeSquared, "descend");
tailCount = max(1, ceil(protocol.statistics.tailFraction*height(rows)));
tailShare = sum(ordered(1:tailCount))/max(sum(ordered), realmin);
entry = table(rows.snrDb(1), rows.method(1), height(rows), ...
    sqrt(mean(angleSquared)), sqrt(mean(rangeSquared)), ...
    sqrt(mean(positionSquared)), median(abs(rows.rangeErrorM)), ...
    quantile(abs(rows.rangeErrorM), 0.90), ...
    quantile(abs(rows.rangeErrorM), 0.95), ...
    quantile(abs(rows.rangeErrorM), 0.99), ...
    mean(abs(rows.rangeErrorM) > protocol.statistics.missThresholdM), ...
    tailShare, 'VariableNames', {'snrDb', 'method', 'n', ...
    'angleRmseDeg', 'rangeRmseM', 'positionRmseM', 'medianRangeM', ...
    'p90RangeM', 'p95RangeM', 'p99RangeM', 'missOver1m', ...
    'top10RangeSseShare'});
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
xError = range.*sind(theta) ...
    - design.truthRangeM.*sind(design.truthThetaDeg);
yError = range.*cosd(theta) ...
    - design.truthRangeM.*cosd(design.truthThetaDeg);
positionError = hypot(xError, yError);
end
