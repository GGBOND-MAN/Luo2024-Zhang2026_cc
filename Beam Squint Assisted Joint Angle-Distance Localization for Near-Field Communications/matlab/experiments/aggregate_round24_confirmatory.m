function aggregate_round24_confirmatory(outputRoot)
%AGGREGATE_ROUND24_CONFIRMATORY Merge and verify all locked MC shards.

arguments
    outputRoot (1, 1) string = ""
end
projectFolder = fileparts(fileparts(mfilename("fullpath")));
if strlength(outputRoot) == 0
    outputRoot = fullfile(projectFolder, "results", "full_spectrum", ...
        "round24_confirmatory");
end
listing = dir(fullfile(outputRoot, "shard_*_of_*"));
listing = listing([listing.isdir]);
assert(~isempty(listing), "fsjad:Round24NoShards", ...
    "No Round 24 shard folders were found.");

allDesign = table();
allResults = struct();
referenceProtocol = struct();
zhangAlgorithm = struct();
oursAlgorithm = struct();
seenShardIds = [];
for index = 1:numel(listing)
    shardFile = fullfile(listing(index).folder, listing(index).name, ...
        "shard_result.mat");
    markerFile = fullfile(listing(index).folder, listing(index).name, ...
        "COMPLETE.txt");
    assert(isfile(shardFile) && isfile(markerFile), ...
        "fsjad:Round24IncompleteShard", ...
        "Shard %s is incomplete.", listing(index).name);
    shard = load(shardFile);
    assert(shard.completedRows == height(shard.design) ...
        && all(shard.results.success), ...
        "fsjad:Round24IncompleteShard", ...
        "Shard %s contains incomplete or failed trials.", ...
        listing(index).name);
    if index == 1
        referenceProtocol = withoutShardId(shard.protocol);
        zhangAlgorithm = shard.zhangAlgorithm;
        oursAlgorithm = shard.oursAlgorithm;
        allResults = shard.results;
    else
        assert(isequal(withoutShardId(shard.protocol), referenceProtocol) ...
            && isequal(shard.zhangAlgorithm, zhangAlgorithm) ...
            && isequal(shard.oursAlgorithm, oursAlgorithm), ...
            "fsjad:Round24ProtocolMismatch", ...
            "All shards must use the same locked protocol.");
        allResults = appendResults(allResults, shard.results);
    end
    seenShardIds(end + 1) = shard.protocol.shardId; %#ok<AGROW>
    allDesign = [allDesign; shard.design]; %#ok<AGROW>
end

expectedShardIds = 1:referenceProtocol.shardCount;
assert(isequal(sort(seenShardIds), expectedShardIds), ...
    "fsjad:Round24MissingShard", ...
    "Expected shard IDs %s but found %s.", ...
    mat2str(expectedShardIds), mat2str(sort(seenShardIds)));
[allDesign, order] = sortrows(allDesign, ["snrDb", "trialIndex"]);
allResults = reorderResults(allResults, order);
validateCoverage(allDesign, referenceProtocol.countPerSnr);
trials = makeTrialTable(allDesign, allResults);
[comparisonSummary, pairedSummary, mechanismSummary] = ...
    summarizeTrials(trials, zhangAlgorithm, oursAlgorithm);

aggregateFolder = fullfile(outputRoot, "aggregate");
if ~isfolder(aggregateFolder)
    mkdir(aggregateFolder);
end
writetable(trials, fullfile(aggregateFolder, "all_trials.csv"));
writetable(comparisonSummary, fullfile(aggregateFolder, ...
    "comparison_summary.csv"));
writetable(pairedSummary, fullfile(aggregateFolder, ...
    "paired_summary.csv"));
writetable(mechanismSummary, fullfile(aggregateFolder, ...
    "mechanism_summary.csv"));
writetable(struct2table(referenceProtocol), ...
    fullfile(aggregateFolder, "protocol.csv"));
save(fullfile(aggregateFolder, "round24_confirmatory.mat"), ...
    "referenceProtocol", "trials", "comparisonSummary", ...
    "pairedSummary", "mechanismSummary", "zhangAlgorithm", ...
    "oursAlgorithm", "-v7.3");
plotComparison(comparisonSummary, fullfile(aggregateFolder, ...
    "round24_range_rmse.png"));
disp(comparisonSummary);
disp(pairedSummary);
disp(mechanismSummary);
fprintf("Round 24 aggregate complete: %s\n", aggregateFolder);
end

function protocol = withoutShardId(protocol)
protocol = rmfield(protocol, "shardId");
end

function combined = appendResults(combined, addition)
fields = string(fieldnames(combined));
for field = fields.'
    combined.(field) = [combined.(field); addition.(field)];
end
end

function results = reorderResults(results, order)
fields = string(fieldnames(results));
for field = fields.'
    results.(field) = results.(field)(order);
end
end

function validateCoverage(design, countPerSnr)
[uniqueKeys, ~] = unique(design(:, ["snrDb", "trialIndex"]), "rows");
assert(height(uniqueKeys) == height(design), ...
    "fsjad:Round24DuplicateTrial", ...
    "Duplicate SNR/trial-index pairs were found.");
snrValuesDb = [-10; 0; 20];
for snrDb = snrValuesDb.'
    actual = sort(design.trialIndex(design.snrDb == snrDb));
    assert(isequal(actual, (1:countPerSnr).'), ...
        "fsjad:Round24Coverage", ...
        "SNR %g dB does not contain every required trial index.", snrDb);
end
assert(numel(unique(design.seed)) == height(design), ...
    "fsjad:Round24DuplicateSeed", "Noise seeds must be globally unique.");
end

function tableOut = makeTrialTable(design, results)
tableOut = design;
fields = string(fieldnames(results));
for field = fields.'
    tableOut.(field) = results.(field);
end
tableOut.zhangAngleErrorDeg = tableOut.zhangThetaDeg ...
    - tableOut.truthThetaDeg;
tableOut.zhangRangeErrorM = tableOut.zhangRangeM ...
    - tableOut.truthRangeM;
tableOut.oursAngleErrorDeg = tableOut.oursThetaDeg ...
    - tableOut.truthThetaDeg;
tableOut.oursRangeErrorM = tableOut.oursRangeM ...
    - tableOut.truthRangeM;
end

function [summary, paired, mechanism] = summarizeTrials( ...
    trials, zhangAlgorithm, oursAlgorithm)
snrValuesDb = [-10; 0; 20];
methodNames = [zhangAlgorithm.version; oursAlgorithm.version];
method = repmat(methodNames, numel(snrValuesDb), 1);
snrDb = repelem(snrValuesDb, 2);
sampleCount = zeros(size(snrDb));
angleRmseDeg = zeros(size(snrDb));
rangeRmseM = zeros(size(snrDb));
rangeMaeM = zeros(size(snrDb));
rangeMedianAbsM = zeros(size(snrDb));
rangeP90AbsM = zeros(size(snrDb));
rangeP95AbsM = zeros(size(snrDb));
rangeP99AbsM = zeros(size(snrDb));
medianRuntimeMs = zeros(size(snrDb));
medianSharedFrontRuntimeMs = zeros(size(snrDb));

pairedCount = zeros(numel(snrValuesDb), 1);
mseChangeM2 = zeros(numel(snrValuesDb), 1);
ci95LowerM2 = zeros(numel(snrValuesDb), 1);
ci95UpperM2 = zeros(numel(snrValuesDb), 1);
rmseReductionPercent = zeros(numel(snrValuesDb), 1);
mseReductionPercent = zeros(numel(snrValuesDb), 1);
absoluteErrorWinRate = zeros(numel(snrValuesDb), 1);

for snrIndex = 1:numel(snrValuesDb)
    chosen = trials.snrDb == snrValuesDb(snrIndex);
    rows = (snrIndex - 1) * 2 + (1:2);
    zhangAngle = trials.zhangAngleErrorDeg(chosen);
    oursAngle = trials.oursAngleErrorDeg(chosen);
    zhangRange = trials.zhangRangeErrorM(chosen);
    oursRange = trials.oursRangeErrorM(chosen);
    angleErrors = {zhangAngle; oursAngle};
    rangeErrors = {zhangRange; oursRange};
    runtimes = {trials.zhangRuntimeMs(chosen); ...
        trials.oursRuntimeMs(chosen)};
    sampleCount(rows) = sum(chosen);
    for methodIndex = 1:2
        row = rows(methodIndex);
        absoluteRange = abs(rangeErrors{methodIndex});
        angleRmseDeg(row) = rms(angleErrors{methodIndex});
        rangeRmseM(row) = rms(rangeErrors{methodIndex});
        rangeMaeM(row) = mean(absoluteRange);
        rangeMedianAbsM(row) = median(absoluteRange);
        rangeP90AbsM(row) = empiricalPercentile(absoluteRange, 90);
        rangeP95AbsM(row) = empiricalPercentile(absoluteRange, 95);
        rangeP99AbsM(row) = empiricalPercentile(absoluteRange, 99);
        medianRuntimeMs(row) = median(runtimes{methodIndex});
        medianSharedFrontRuntimeMs(row) = ...
            median(trials.frontRuntimeMs(chosen));
    end
    squaredChange = oursRange.^2 - zhangRange.^2;
    pairedCount(snrIndex) = sum(chosen);
    mseChangeM2(snrIndex) = mean(squaredChange);
    halfWidth = 1.96 * std(squaredChange) / sqrt(sum(chosen));
    ci95LowerM2(snrIndex) = mseChangeM2(snrIndex) - halfWidth;
    ci95UpperM2(snrIndex) = mseChangeM2(snrIndex) + halfWidth;
    zhangMse = mean(zhangRange.^2);
    oursMse = mean(oursRange.^2);
    rmseReductionPercent(snrIndex) = 100 ...
        * (1 - sqrt(oursMse / zhangMse));
    mseReductionPercent(snrIndex) = 100 * (1 - oursMse / zhangMse);
    absoluteErrorWinRate(snrIndex) = mean(abs(oursRange) ...
        < abs(zhangRange));
end
summary = table(method, snrDb, sampleCount, angleRmseDeg, ...
    rangeRmseM, rangeMaeM, rangeMedianAbsM, rangeP90AbsM, ...
    rangeP95AbsM, rangeP99AbsM, medianSharedFrontRuntimeMs, ...
    medianRuntimeMs);
comparison = repmat("Ours minus Joint-MC Zhang", numel(snrValuesDb), 1);
paired = table(comparison, snrValuesDb, pairedCount, mseChangeM2, ...
    ci95LowerM2, ci95UpperM2, rmseReductionPercent, ...
    mseReductionPercent, absoluteErrorWinRate, ...
    'VariableNames', {'comparison', 'snrDb', 'sampleCount', ...
    'mseChangeM2', 'ci95LowerM2', 'ci95UpperM2', ...
    'rmseReductionPercent', 'mseReductionPercent', ...
    'absoluteErrorWinRate'});

zhangBoundaryRate = zeros(numel(snrValuesDb), 1);
oursBoundaryRate = zeros(numel(snrValuesDb), 1);
zhangTruthInWindowRate = zeros(numel(snrValuesDb), 1);
oursTruthInWindowRate = zeros(numel(snrValuesDb), 1);
for snrIndex = 1:numel(snrValuesDb)
    chosen = trials.snrDb == snrValuesDb(snrIndex);
    zhangBoundaryRate(snrIndex) = mean(trials.zhangBoundaryPeak(chosen));
    oursBoundaryRate(snrIndex) = mean(trials.oursBoundaryPeak(chosen));
    zhangTruthInWindowRate(snrIndex) = ...
        mean(trials.zhangTruthInWindow(chosen));
    oursTruthInWindowRate(snrIndex) = ...
        mean(trials.oursTruthInWindow(chosen));
end
mechanism = table(snrValuesDb, pairedCount, zhangBoundaryRate, ...
    oursBoundaryRate, zhangTruthInWindowRate, oursTruthInWindowRate, ...
    'VariableNames', {'snrDb', 'sampleCount', 'zhangBoundaryRate', ...
    'oursBoundaryRate', 'zhangTruthInWindowRate', ...
    'oursTruthInWindowRate'});
end

function value = empiricalPercentile(samples, probability)
samples = sort(samples(:));
position = 1 + (numel(samples) - 1) * probability / 100;
lowerIndex = floor(position);
upperIndex = ceil(position);
weight = position - lowerIndex;
value = samples(lowerIndex) * (1 - weight) + samples(upperIndex) * weight;
end

function plotComparison(summary, outputFile)
figureHandle = figure("Visible", "off", "Color", "w", ...
    "Position", [100, 100, 760, 460]);
cleanupFigure = onCleanup(@() close(figureHandle));
axisHandle = axes(figureHandle);
hold(axisHandle, "on");
methods = unique(summary.method, "stable");
for methodIndex = 1:numel(methods)
    chosen = summary.method == methods(methodIndex);
    semilogy(axisHandle, summary.snrDb(chosen), ...
        summary.rangeRmseM(chosen), "-o", "LineWidth", 1.5, ...
        "DisplayName", methods(methodIndex));
end
grid(axisHandle, "on");
xlabel(axisHandle, "SNR (dB)");
ylabel(axisHandle, "Range RMSE (m)");
title(axisHandle, "Round 24 locked 10,000-trial confirmation");
legend(axisHandle, "Location", "best");
exportgraphics(figureHandle, outputFile, "Resolution", 180);
end
