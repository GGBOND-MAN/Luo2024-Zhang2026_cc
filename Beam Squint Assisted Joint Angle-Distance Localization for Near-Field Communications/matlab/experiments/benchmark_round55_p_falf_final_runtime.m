function output = benchmark_round55_p_falf_final_runtime(options)
%BENCHMARK_ROUND55_P_FALF_FINAL_RUNTIME Benchmark lean final throughput.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 8
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
    options.Repetitions (1, 1) double {mustBeInteger, mustBePositive} = 2
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
protocol = r55.config();
locations = r55.paths(project);
if isfolder(locations.benchmarkFolder)
    error("r55:BenchmarkExists", ...
        "The immutable R55 runtime benchmark already exists.");
end
mkdir(locations.benchmarkFolder);
calibrationDesign = r54.design(protocol.r54);
selected = ismember(calibrationDesign.positionId, 1:8);
design = calibrationDesign(selected, :);
if height(design) ~= 24
    error("r55:BenchmarkDesign", "Expected 24 balanced benchmark rows.");
end
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
pool = preparePool(options.PoolType, options.NumWorkers);
warmup = r55.finalTrial(cfg, scan, design(1, :), 1, protocol);
if ~warmup.success
    error("r55:BenchmarkWarmup", warmup.errorMessage);
end
wallSeconds = zeros(options.Repetitions, 1);
for repetition = 1:options.Repetitions
    results = cell(height(design), 1);
    timer = tic;
    parfor index = 1:height(design)
        results{index} = r55.finalTrial( ...
            cfg, scan, design(index, :), index, protocol);
    end
    wallSeconds(repetition) = toc(timer);
    if any(cellfun(@(item) ~item.success, results))
        error("r55:BenchmarkTrialFailure", ...
            "At least one runtime benchmark row failed.");
    end
end
secondsPerRow = median(wallSeconds)/height(design);
projectedComputeHours = secondsPerRow*protocol.design.expectedRows/3600;
postprocessHours = 10/60;
recommendedUpperHours = 1.15*projectedComputeHours+postprocessHours;
conservativeRawHours = protocol.complexity.rawLinearProjectionHours;
exceedsFourHours = max(recommendedUpperHours, conservativeRawHours) ...
    > protocol.complexity.autoRunMaximumHours;
estimate = table(options.NumWorkers, height(design), options.Repetitions, ...
    mean(wallSeconds), median(wallSeconds), secondsPerRow, ...
    projectedComputeHours, postprocessHours, recommendedUpperHours, ...
    conservativeRawHours, exceedsFourHours, ...
    'VariableNames', {'workers', 'benchmarkRows', 'repetitions', ...
    'meanWallSeconds', 'medianWallSeconds', 'effectiveSecondsPerRow', ...
    'projectedComputeHours1400', 'postprocessHours', ...
    'recommendedUpperHours', 'conservativeRawHours', ...
    'exceedsFourHours'});
identity = struct(version="R55-runtime-benchmark-v1", ...
    usesFinalRows=false, source="R54-calibration-design-runtime-only", ...
    sourceDigest=r32.sourceDigest(r55.sourceManifest(project)), ...
    completedAt=string(datetime("now", "TimeZone", "Asia/Shanghai")));
writetable(design, fullfile(locations.benchmarkFolder, "design.csv"));
writetable(estimate, fullfile(locations.benchmarkFolder, "estimate.csv"));
save(locations.benchmarkFile, "identity", "estimate", ...
    "wallSeconds", "design", "-v7");
output = struct(identity=identity, estimate=estimate, ...
    folder=locations.benchmarkFolder);
disp(estimate);
end

function pool = preparePool(poolType, workers)
pool = gcp("nocreate");
requiredClass = "parallel.ThreadPool";
if poolType == "Processes"
    requiredClass = "parallel.ProcessPool";
end
if ~isempty(pool) && (pool.NumWorkers ~= workers ...
        || string(class(pool)) ~= requiredClass)
    delete(pool);
    pool = [];
end
if isempty(pool)
    pool = parpool(poolType, workers);
end
end
