function run_round32_online_timing(options)
%RUN_ROUND32_ONLINE_TIMING Time four complete online paths on three users.

arguments
    options.Repetitions (1, 1) double {mustBeInteger, mustBePositive} = 3
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
raw = r31.loadRound30Raw(project, IncludeBaselineResults=false);
protocol = r32.config();
cfg = raw.pilot.expected.cfg;
scan = fsjad.prepareScan(cfg);
positions = raw.pilot.design(raw.pilot.design.snrDb == protocol.timing.snrDb, :);
positions = positions(1:protocol.timing.positionCount, :);
methods = protocol.timing.baseOrder;
output = table();
executionOrder = table();
folder = fullfile(project, "results", "full_spectrum", ...
    "round32_pa_finite_closeout_v1", "complete_online_timing");
rawFile = fullfile(folder, "raw_timing_rows.csv");
orderFile = fullfile(folder, "execution_order.csv");
expectedRows = height(positions)*options.Repetitions*numel(methods);
if isfile(rawFile) && isfile(orderFile)
    recovered = readtable(rawFile, TextType="string");
    recoveredOrder = readtable(orderFile, TextType="string");
    if height(recovered) == expectedRows ...
            && height(recoveredOrder) == expectedRows
        finalize(recovered, recoveredOrder, project, raw, protocol, ...
            positions, options.Repetitions, folder, true);
        return;
    end
end

for positionIndex = 1:height(positions)
    replay = fsjad.replayRound27Data(cfg, scan, positions(positionIndex, :));
    for method = methods
        runMethod(method, cfg, replay, scan, protocol); % unified warm-up
    end
    for repetition = 1:options.Repetitions
        shift = mod((positionIndex-1)*options.Repetitions+repetition-1, ...
            numel(methods));
        order = circshift(methods, -shift);
        for orderIndex = 1:numel(order)
            method = order(orderIndex);
            wallTimer = tic;
            result = runMethod(method, cfg, replay, scan, protocol);
            wallSeconds = toc(wallTimer);
            output = [output; timingRow(result, method, cfg, ...
                positions(positionIndex, :), positionIndex, repetition, ...
                orderIndex, wallSeconds, protocol)]; %#ok<AGROW>
            executionOrder = [executionOrder; table(positionIndex, ...
                repetition, orderIndex, method)]; %#ok<AGROW>
        end
    end
end

if ~isfolder(folder)
    mkdir(folder);
end
writetable(output, rawFile);
writetable(executionOrder, orderFile);
finalize(output, executionOrder, project, raw, protocol, positions, ...
    options.Repetitions, folder, false);
end

function finalize(output, executionOrder, project, raw, protocol, ...
    positions, repetitions, folder, recoveredAfterSummaryFailure)
summary = summarizeTiming(output);
writetable(summary, fullfile(folder, "timing_summary.csv"));
source = r32.manifest(project);
writetable(source, fullfile(folder, "source_hashes.csv"));
environment = struct(matlabVersion=version, computer=computer, ...
    execution="sequential-single-MATLAB-process-no-parpool", ...
    warmupsPerMethodPerPosition=1, repetitions=repetitions, ...
    methodOrderPolicy=protocol.timing.orderPolicy, ...
    simulationDataGenerationExcluded=true, ...
    recoveredAfterSummaryFailure=recoveredAfterSummaryFailure, ...
    timestamp=string(datetime("now")));
identity = struct(version="R32-complete-online-timing-v1", ...
    protocol=protocol, positions=positions, pilotHash=raw.pilotHash);
save(fullfile(folder, "result.mat"), "identity", "output", ...
    "executionOrder", "summary", "environment", "source", "-v7.3");
fprintf("ROUND32_COMPLETE_ONLINE_TIMING_COMPLETE rows=%d\n", height(output));
end

function summary = summarizeTiming(output)
metrics = ["wallSeconds", "reportedTotalSeconds", "frontSeconds", ...
    "stateSeconds", "angleOrJointSeconds", "profileSeconds"];
summary = table();
for method = unique(output.method, "stable").'
    rows = output.method == method;
    values = zeros(1, numel(metrics)*3);
    names = strings(1, numel(metrics)*3);
    cursor = 1;
    for metric = metrics
        vector = output.(metric)(rows);
        values(cursor:cursor+2) = [mean(vector), median(vector), std(vector)];
        names(cursor:cursor+2) = ["mean_"+metric, ...
            "median_"+metric, "std_"+metric];
        cursor = cursor + 3;
    end
    entry = array2table(values, VariableNames=cellstr(names));
    entry = addvars(entry, method, nnz(rows), Before=1, ...
        NewVariableNames=["method", "n"]);
    summary = [summary; entry]; %#ok<AGROW>
end
end

function result = runMethod(method, cfg, replay, scan, protocol)
switch method
    case "C_enhanced"
        result = r32.estimateC(cfg, replay.observation, ...
            replay.snapshots, scan, protocol);
    case "H_A"
        result = r32.estimateHA(cfg, replay.observation, ...
            replay.snapshots, scan, protocol);
    case "P_A"
        result = r32.estimatePA(cfg, replay.observation, ...
            replay.snapshots, scan, protocol);
    case "C_public"
        result = r32.estimatePublic(cfg, replay.observation, ...
            replay.snapshots, scan, protocol);
    otherwise
        error("r32:UnknownTimingMethod", "Unknown method %s.", method);
end
end

function row = timingRow(result, method, cfg, position, positionIndex, ...
    repetition, orderIndex, wallSeconds, protocol)
if method == "P_A"
    thetaDeg = result.P_A.thetaDeg;
    rangeM = result.P_A.rangeM;
    angleOrJointSeconds = result.cost.angleSeconds;
    profileSeconds = result.cost.profileSeconds;
    carrierCount = protocol.music.carrierCount;
    subarraySize = protocol.music.subarraySize;
    angleHalfWidthDeg = protocol.music.angleHalfWidthDeg;
    rangeHalfWidthM = protocol.profile.halfWidthM;
elseif method == "H_A"
    thetaDeg = result.H_A.thetaDeg;
    rangeM = result.H_A.rangeM;
    angleOrJointSeconds = result.cost.angleSeconds;
    profileSeconds = 0;
    carrierCount = protocol.music.carrierCount;
    subarraySize = protocol.music.subarraySize;
    angleHalfWidthDeg = protocol.music.angleHalfWidthDeg;
    rangeHalfWidthM = 0;
else
    thetaDeg = result.estimate.thetaDeg;
    rangeM = result.estimate.rangeM;
    angleOrJointSeconds = result.cost.searchSeconds;
    profileSeconds = 0;
    if method == "C_enhanced"
        carrierCount = protocol.enhancedC.carrierCount;
        subarraySize = protocol.enhancedC.subarraySize;
        angleHalfWidthDeg = protocol.enhancedC.angleHalfWidthDeg;
        rangeHalfWidthM = protocol.enhancedC.rangeHalfWidthM;
    else
        carrierCount = protocol.publicC.carrierCount;
        subarraySize = protocol.publicC.subarraySize;
        angleHalfWidthDeg = protocol.publicC.angleHalfWidthDeg;
        rangeHalfWidthM = protocol.publicC.rangeHalfWidthM;
    end
end
row = table(position.seed, position.snrDb, positionIndex, repetition, ...
    orderIndex, method, wallSeconds, result.cost.totalOnlineSeconds, ...
    result.cost.frontSeconds, result.cost.stateSeconds, ...
    angleOrJointSeconds, profileSeconds, cfgValue(result, "frontEquivalentResponses"), ...
    cfgValue(result, "phaseAlignmentTerms"), ...
    cfgValue(result, "covarianceMacs"), cfgValue(result, "evdCubicUnits"), ...
    carrierCount, subarraySize, 256-subarraySize+1, ...
    cfg.numSubcarriers, angleHalfWidthDeg, rangeHalfWidthM, ...
    "41/31/21", thetaDeg, rangeM, ...
    'VariableNames', {'seed', 'snrDb', 'positionIndex', 'repetition', ...
    'orderIndex', 'method', 'wallSeconds', 'reportedTotalSeconds', ...
    'frontSeconds', 'stateSeconds', 'angleOrJointSeconds', ...
    'profileSeconds', 'frontEquivalentResponses', 'phaseAlignmentTerms', ...
    'covarianceMacs', 'evdCubicUnits', 'carrierCount', 'subarraySize', ...
    'numSubarrays', 'numSubcarriers', 'angleHalfWidthDeg', ...
    'rangeHalfWidthM', 'gridDescription', 'thetaDeg', 'rangeM'});
end

function value = cfgValue(result, field)
value = result.cost.(field);
end
