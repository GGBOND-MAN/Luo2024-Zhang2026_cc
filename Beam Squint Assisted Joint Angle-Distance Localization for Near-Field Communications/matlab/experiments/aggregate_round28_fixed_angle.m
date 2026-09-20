function aggregate_round28_fixed_angle(outputRoot)
%AGGREGATE_ROUND28_FIXED_ANGLE Verify coverage and summarize paired results.

arguments
    outputRoot (1, 1) string = ""
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
if outputRoot == ""
    outputRoot = fullfile(project, "results", "full_spectrum", ...
        "round28_v1_0200_per_snr");
end
listing = dir(fullfile(outputRoot, "shard_*_of_*", "shard_result.mat"));
assert(~isempty(listing), "fsjad:Round28NoShards");
design = table();
results = cell(0, 1);
environments = cell(numel(listing), 1);
seen = zeros(numel(listing), 1);
for fileIndex = 1:numel(listing)
    saved = load(fullfile(listing(fileIndex).folder, listing(fileIndex).name));
    assert(isfile(fullfile(listing(fileIndex).folder, "COMPLETE.csv")), ...
        "fsjad:Round28IncompleteShard");
    if fileIndex == 1
        setup = saved.setup;
    else
        assert(isequaln(setup, saved.setup), "fsjad:Round28DifferentProtocols");
    end
    assert(numel(saved.results) == height(saved.design) ...
        && all(cellfun(@(item) ~isempty(item) && item.success, saved.results)), ...
        "fsjad:Round28FailedResults");
    design = [design; saved.design]; %#ok<AGROW>
    results = [results; saved.results]; %#ok<AGROW>
    environments{fileIndex} = saved.environment;
    seen(fileIndex) = saved.shardId;
end
assert(isequal(sort(seen), (1:setup.protocol.shardCount).'), ...
    "fsjad:Round28ShardCoverage");
[design, order] = sortrows(design, {'snrDb', 'trialIndex'});
results = results(order);
assert(height(design) == 3*setup.protocol.countPerSnr ...
    && numel(unique(design.seed)) == height(design), ...
    "fsjad:Round28TrialCoverage");

theta = cell2mat(cellfun(@(item) item.thetaDeg, results, UniformOutput=false));
range = cell2mat(cellfun(@(item) item.rangeM, results, UniformOutput=false));
angleError = theta-design.truthThetaDeg;
rangeError = range-design.truthRangeM;
jointError = jointPositionError(theta, range, design);
trials = design;
for methodIndex = 1:numel(setup.protocol.methodNames)
    name = setup.protocol.methodNames(methodIndex);
    trials.(name+"_thetaDeg") = theta(:, methodIndex);
    trials.(name+"_rangeM") = range(:, methodIndex);
    trials.(name+"_rangeErrorM") = rangeError(:, methodIndex);
end

comparisons = comparisonProtocol(setup.protocol.methodIndex);
methodSummary = table();
pairedSummary = table();
boundarySummary = table();
costSummary = table();
snrValues = [-10, 0, 20];
for snrIndex = 1:numel(snrValues)
    snrDb = snrValues(snrIndex);
    rows = design.snrDb == snrDb;
    for methodIndex = 1:numel(setup.protocol.methodNames)
        name = setup.protocol.methodNames(methodIndex);
        re = rangeError(rows, methodIndex);
        ae = angleError(rows, methodIndex);
        je = jointError(rows, methodIndex);
        q = empiricalPercentile(abs(re), [0.5, 0.9, 0.95, 0.99]);
        ci = bootstrapRmse(re, setup.protocol.bootstrapResamples, ...
            setup.protocol.bootstrapSeed+10000*snrIndex+methodIndex);
        entry = table(name, snrDb, numel(re), mean(re.^2), rms(re), ...
            ci(1), ci(2), rms(ae), rms(je), q(1), q(2), q(3), q(4), ...
            mean(abs(re) > 1), topSseShare(re, 0.01), topSseShare(re, 0.05), ...
            'VariableNames', {'method', 'snrDb', 'count', 'rangeMseM2', ...
            'rangeRmseM', 'rangeRmseCi95LowerM', 'rangeRmseCi95UpperM', ...
            'angleRmseDeg', 'jointPositionRmseM', 'rangeMedianAbsM', ...
            'rangeP90AbsM', 'rangeP95AbsM', 'rangeP99AbsM', ...
            'rangeMissOver1mRate', 'rangeTop1PercentSseShare', ...
            'rangeTop5PercentSseShare'});
        methodSummary = [methodSummary; entry]; %#ok<AGROW>
    end
    for comparisonIndex = 1:height(comparisons)
        methodError = rangeError(rows, comparisons.methodIndex(comparisonIndex));
        referenceError = rangeError(rows, comparisons.referenceIndex(comparisonIndex));
        bootstrap = pairedBootstrap(methodError, referenceError, ...
            setup.protocol.bootstrapResamples, setup.protocol.bootstrapSeed ...
            +100000*snrIndex+comparisonIndex);
        absoluteDelta = abs(methodError)-abs(referenceError);
        entry = table(comparisons.comparison(comparisonIndex), ...
            comparisons.method(comparisonIndex), ...
            comparisons.reference(comparisonIndex), snrDb, numel(methodError), ...
            mean(methodError.^2-referenceError.^2), bootstrap.mseLower, ...
            bootstrap.mseUpper, 100*(1-rms(methodError)/rms(referenceError)), ...
            bootstrap.reductionLower, bootstrap.reductionUpper, ...
            mean(absoluteDelta < -1e-12), mean(abs(absoluteDelta) <= 1e-12), ...
            bootstrap.twoSidedP, false, NaN, ...
            'VariableNames', {'comparison', 'method', 'reference', 'snrDb', ...
            'count', 'mseDifferenceM2', 'bootstrapCi95LowerM2', ...
            'bootstrapCi95UpperM2', 'rmseReductionPercent', ...
            'reductionCi95LowerPercent', 'reductionCi95UpperPercent', ...
            'methodWinRate', 'tieRate', 'bootstrapTwoSidedP', ...
            'primaryFamily', 'holmAdjustedP'});
        pairedSummary = [pairedSummary; entry]; %#ok<AGROW>
    end
    [boundaryEntry, costEntry] = summarizeDiagnostics( ...
        results(rows), setup.protocol.methodIndex, snrDb);
    boundarySummary = [boundarySummary; boundaryEntry]; %#ok<AGROW>
    costSummary = [costSummary; costEntry]; %#ok<AGROW>
end
primaryRows = pairedSummary.comparison == setup.protocol.primaryComparison;
pairedSummary.primaryFamily(primaryRows) = true;
pairedSummary.holmAdjustedP(primaryRows) = holmAdjust( ...
    pairedSummary.bootstrapTwoSidedP(primaryRows));

folder = fullfile(outputRoot, "aggregate");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(trials, fullfile(folder, "trials.csv"));
writetable(methodSummary, fullfile(folder, "method_summary.csv"));
writetable(pairedSummary, fullfile(folder, "paired_summary.csv"));
writetable(boundarySummary, fullfile(folder, "boundary_summary.csv"));
writetable(costSummary, fullfile(folder, "cost_summary.csv"));
writetable(design(:, {'seed', 'snrDb', 'trialIndex'}), ...
    fullfile(folder, "seed_list.csv"));
writetable(setup.source, fullfile(folder, "source_hashes.csv"));
save(fullfile(folder, "round28_aggregate.mat"), "setup", "design", ...
    "results", "trials", "methodSummary", "pairedSummary", ...
    "boundarySummary", "costSummary", "environments", "-v7.3");
fprintf("ROUND28_AGGREGATE_COMPLETE %s\n", folder);
end

function protocol = comparisonProtocol(index)
comparison = ["P_w-minus-M_w"; "M_w-minus-M_n-window"; ...
    "P_w-minus-P_n-window"; "P_w-minus-H"; "P_w-minus-P_F"; ...
    "M_n-minus-C-diagnostic"; "P_w-minus-D-solver-difference"; ...
    "P_adaptive_common-minus-M_adaptive_common"];
methodIndex = [index.Pw; index.Mw; index.Pw; index.Pw; index.Pw; ...
    index.Mn; index.Pw; index.PAdaptiveCommon];
referenceIndex = [index.Mw; index.Mn; index.Pn; index.H; index.PF; ...
    index.C; index.D; index.MAdaptiveCommon];
names = ["P_w"; "M_w"; "P_w"; "P_w"; "P_w"; "M_n"; "P_w"; ...
    "P_adaptive_common"];
references = ["M_w"; "M_n"; "P_n"; "H"; "P_F"; "C"; "D"; ...
    "M_adaptive_common"];
protocol = table(comparison, names, references, methodIndex, referenceIndex, ...
    'VariableNames', {'comparison', 'method', 'reference', ...
    'methodIndex', 'referenceIndex'});
end

function errorM = jointPositionError(thetaDeg, rangeM, design)
truthX = design.truthRangeM.*sind(design.truthThetaDeg);
truthY = design.truthRangeM.*cosd(design.truthThetaDeg);
estimateX = rangeM.*sind(thetaDeg);
estimateY = rangeM.*cosd(thetaDeg);
errorM = hypot(estimateX-truthX, estimateY-truthY);
end

function [boundary, cost] = summarizeDiagnostics(results, index, snrDb)
names = ["M_n"; "P_n"; "M_w"; "P_w"; "P_F"; ...
    "M_adaptive_common"; "P_adaptive_common"];
fields = ["Mn"; "Pn"; "Mw"; "Pw"; "PF"; ...
    "MAdaptiveCommon"; "PAdaptiveCommon"];
methodIndices = [index.Mn; index.Pn; index.Mw; index.Pw; index.PF; ...
    index.MAdaptiveCommon; index.PAdaptiveCommon];
boundary = table();
cost = table();
for item = 1:numel(fields)
    solvers = cellfun(@(result) result.solvers.(fields(item)), ...
        results, UniformOutput=false);
    boundaryFlag = cellfun(@(solver) solver.boundary, solvers);
    outward = cellfun(@(solver) solver.outwardTrend, solvers);
    evaluations = cellfun(@(solver) solver.evaluationCount, solvers);
    runtime = cellfun(@(result) runtimeFor(result, fields(item)), results);
    boundary = [boundary; table(names(item), methodIndices(item), snrDb, ...
        numel(solvers), mean(boundaryFlag), mean(outward), ...
        'VariableNames', {'method', 'methodIndex', 'snrDb', 'count', ...
        'boundaryRate', 'boundaryOutwardRate'})]; %#ok<AGROW>
    cost = [cost; table(names(item), snrDb, numel(solvers), ...
        mean(evaluations), median(evaluations), mean(runtime), median(runtime), ...
        'VariableNames', {'method', 'snrDb', 'count', ...
        'meanRequestedEvaluations', 'medianRequestedEvaluations', ...
        'meanRuntimeSeconds', 'medianRuntimeSeconds'})]; %#ok<AGROW>
end
end

function seconds = runtimeFor(result, field)
if isfield(result.runtimeSeconds, field)
    seconds = result.runtimeSeconds.(field);
else
    seconds = NaN;
end
end

function bounds = bootstrapRmse(error, count, seed)
stream = RandStream("mt19937ar", Seed=seed);
values = zeros(count, 1);
n = numel(error);
for first = 1:1000:count
    last = min(first+999, count);
    indices = randi(stream, n, n, last-first+1);
    values(first:last) = sqrt(mean(error(indices).^2, 1)).';
end
bounds = empiricalPercentile(values, [0.025, 0.975]);
end

function result = pairedBootstrap(methodError, referenceError, count, seed)
stream = RandStream("mt19937ar", Seed=seed);
n = numel(methodError);
mseDifference = zeros(count, 1);
reduction = zeros(count, 1);
for first = 1:1000:count
    last = min(first+999, count);
    indices = randi(stream, n, n, last-first+1);
    methodMse = mean(methodError(indices).^2, 1).';
    referenceMse = mean(referenceError(indices).^2, 1).';
    mseDifference(first:last) = methodMse-referenceMse;
    reduction(first:last) = 100*(1-sqrt(methodMse)./sqrt(referenceMse));
end
mseBounds = empiricalPercentile(mseDifference, [0.025, 0.975]);
reductionBounds = empiricalPercentile(reduction, [0.025, 0.975]);
result.mseLower = mseBounds(1);
result.mseUpper = mseBounds(2);
result.reductionLower = reductionBounds(1);
result.reductionUpper = reductionBounds(2);
result.twoSidedP = min(1, 2*min(mean(mseDifference <= 0), ...
    mean(mseDifference >= 0)));
end

function adjusted = holmAdjust(p)
[sorted, order] = sort(p(:));
scaled = (numel(sorted)-(1:numel(sorted)).'+1).*sorted;
scaled = cummax(scaled);
scaled = min(1, scaled);
adjusted = zeros(size(p(:)));
adjusted(order) = scaled;
adjusted = reshape(adjusted, size(p));
end

function percentiles = empiricalPercentile(values, probabilities)
values = sort(values(:));
positions = 1+(numel(values)-1)*probabilities;
lower = floor(positions);
upper = ceil(positions);
fraction = positions-lower;
percentiles = values(lower).'+fraction.*(values(upper).'-values(lower).');
end

function share = topSseShare(error, proportion)
squared = sort(error(:).^2, "descend");
if sum(squared) == 0
    share = 0;
else
    share = sum(squared(1:max(1, ceil(proportion*numel(squared)))))/sum(squared);
end
end
