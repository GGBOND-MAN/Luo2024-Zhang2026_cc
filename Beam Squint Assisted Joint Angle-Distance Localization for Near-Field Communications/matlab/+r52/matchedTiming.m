function output = matchedTiming(design, cfg, scan, protocol)
%MATCHEDTIMING Compare complete standalone P_FARC2 and C_enhanced runtime.

arguments
    design table
    cfg (1, 1) struct
    scan (1, 1) struct
    protocol (1, 1) struct = r52.config()
end

selected = ismember(design.positionId, protocol.timing.positionIds) ...
    & design.snrDb == protocol.timing.snrDb;
timingDesign = sortrows(design(selected, :), "positionId");
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
                record.trigger, 'VariableNames', {'positionId', 'seed', ...
                'repetition', 'orderIndex', 'method', 'wallSeconds', ...
                'reportedSeconds', 'trigger'})]; %#ok<AGROW>
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
        'medianWallSeconds', 'stdWallSeconds', 'meanReportedSeconds'})]; %#ok<AGROW>
end
candidate = summary(summary.method == "P_FARC2", :);
reference = summary(summary.method == "C_enhanced", :);
comparison = table("P_FARC2", "C_enhanced", ...
    candidate.meanWallSeconds/reference.meanWallSeconds, ...
    candidate.medianWallSeconds/reference.medianWallSeconds, ...
    candidate.meanWallSeconds < reference.meanWallSeconds, ...
    'VariableNames', {'candidate', 'reference', 'meanRuntimeRatio', ...
    'medianRuntimeRatio', 'pass'});
output = struct(version="R52-matched-standalone-timing-v1", ...
    design=timingDesign, rows=rows, summary=summary, comparison=comparison);
end

function output = execute(method, cfg, scan, replay, protocol)
if method == "P_FARC2"
    estimate = r52.estimatePFARC2(cfg, replay.observation, ...
        replay.snapshots, scan, protocol);
    output = struct(reportedSeconds=estimate.totalOnlineSeconds, ...
        trigger=estimate.certificate.trigger);
else
    estimate = r34.estimate(cfg, replay.observation, replay.snapshots, ...
        scan, "C_enhanced", protocol.base.r34);
    output = struct(reportedSeconds=estimate.cost.totalOnlineSeconds, ...
        trigger=false);
end
end
