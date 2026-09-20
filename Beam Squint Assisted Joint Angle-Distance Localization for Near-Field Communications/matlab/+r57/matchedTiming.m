function output = matchedTiming(design, cfg, scan, protocol)
%MATCHEDTIMING Compare standalone P_FACR and C_enhanced runtime.
%   Mirrors r53.matchedTiming. Only the deployable primary method is timed;
%   the reporting-only ablation branches are excluded, as R53 excluded its
%   Y-only diagnostic profile. This is the quantity gate G10 reads.

arguments
    design table
    cfg (1, 1) struct
    scan (1, 1) struct
    protocol (1, 1) struct = r57.config()
end

selected = ismember(design.positionId, protocol.timing.positionIds) ...
    & design.snrDb == protocol.timing.snrDb;
timingDesign = sortrows(design(selected, :), "positionId");
if height(timingDesign) ~= numel(protocol.timing.positionIds)
    error("r57:TimingDesignMismatch", ...
        "The R57 timing rows are not unique and complete.");
end
methods = protocol.timing.methods;
rows = table();
for positionIndex = 1:height(timingDesign)
    replay = fsjad.replayRound27Data(cfg, scan, timingDesign(positionIndex, :));
    for warmup = 1:protocol.timing.warmups
        for method = methods
            execute(method, cfg, scan, replay, protocol);
        end
    end
    for repetition = 1:protocol.timing.repetitions
        shift = mod(positionIndex+repetition-2, numel(methods));
        order = circshift(methods, -shift);
        for orderIndex = 1:numel(order)
            method = order(orderIndex);
            timer = tic;
            record = execute(method, cfg, scan, replay, protocol);
            wallSeconds = toc(timer);
            rows = [rows; table(timingDesign.positionId(positionIndex), ...
                timingDesign.seed(positionIndex), repetition, orderIndex, ...
                method, wallSeconds, record.reportedSeconds, ...
                'VariableNames', {'positionId', 'seed', 'repetition', ...
                'orderIndex', 'method', 'wallSeconds', ...
                'reportedSeconds'})]; %#ok<AGROW>
        end
    end
end
summary = table();
for method = methods
    selectedRows = rows(rows.method == method, :);
    summary = [summary; table(method, height(selectedRows), ...
        mean(selectedRows.wallSeconds), median(selectedRows.wallSeconds), ...
        std(selectedRows.wallSeconds), mean(selectedRows.reportedSeconds), ...
        'VariableNames', {'method', 'n', 'meanWallSeconds', ...
        'medianWallSeconds', 'stdWallSeconds', ...
        'meanReportedSeconds'})]; %#ok<AGROW>
end
candidate = summary(summary.method == "P_FACR", :);
reference = summary(summary.method == "C_enhanced", :);
ratio = candidate.meanWallSeconds/reference.meanWallSeconds;
comparison = table("P_FACR", "C_enhanced", ratio, ...
    candidate.medianWallSeconds/reference.medianWallSeconds, ...
    ratio < protocol.gate.maxMatchedRuntimeRatioToC, ...
    'VariableNames', {'candidate', 'reference', 'meanRuntimeRatio', ...
    'medianRuntimeRatio', 'pass'});
output = struct(version="R57-matched-standalone-timing-v1", ...
    design=timingDesign, rows=rows, summary=summary, comparison=comparison);
end

function output = execute(method, cfg, scan, replay, protocol)
if method == "P_FACR"
    estimate = r57.estimatePFACR(cfg, replay.observation, ...
        replay.snapshots, scan, protocol);
    output = struct(reportedSeconds=estimate.totalOnlineSeconds);
else
    estimate = r34.estimate(cfg, replay.observation, replay.snapshots, ...
        scan, "C_enhanced", protocol.base.base.r34);
    output = struct(reportedSeconds=estimate.cost.totalOnlineSeconds);
end
end
