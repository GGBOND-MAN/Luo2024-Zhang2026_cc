function output = matchedTiming(design, cfg, scan, protocol)
%MATCHEDTIMING Compare complete standalone P_FARC and C_enhanced runtime.

arguments
    design table
    cfg (1, 1) struct
    scan (1, 1) struct
    protocol (1, 1) struct = r51.config()
end

selected = ismember(design.positionId, protocol.timing.positionIds) ...
    & design.snrDb == protocol.timing.snrDb;
timingDesign = sortrows(design(selected, :), "positionId");
if height(timingDesign) ~= numel(protocol.timing.positionIds)
    error("r51:TimingDesignMismatch", ...
        "The R51 timing rows are not unique and complete.");
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
                record.trigger, record.recoveryAccepted, ...
                'VariableNames', {'positionId', 'seed', 'repetition', ...
                'orderIndex', 'method', 'wallSeconds', 'reportedSeconds', ...
                'trigger', 'recoveryAccepted'})]; %#ok<AGROW>
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
candidate = summary(summary.method == "P_FARC", :);
reference = summary(summary.method == "C_enhanced", :);
comparison = table("P_FARC", "C_enhanced", ...
    candidate.meanWallSeconds/reference.meanWallSeconds, ...
    candidate.medianWallSeconds/reference.medianWallSeconds, ...
    candidate.meanWallSeconds < reference.meanWallSeconds, ...
    'VariableNames', {'candidate', 'reference', 'meanRuntimeRatio', ...
    'medianRuntimeRatio', 'pass'});
output = struct(version="R51-matched-standalone-timing-v1", ...
    design=timingDesign, rows=rows, summary=summary, comparison=comparison);
end

function output = execute(method, cfg, scan, replay, protocol)
if method == "P_FARC"
    estimate = r51.estimatePFARC(cfg, replay.observation, ...
        replay.snapshots, scan, protocol);
    output = struct(reportedSeconds=estimate.totalOnlineSeconds, ...
        trigger=estimate.certificate.trigger, ...
        recoveryAccepted=estimate.recovery.accepted);
else
    estimate = r34.estimate(cfg, replay.observation, replay.snapshots, ...
        scan, "C_enhanced", protocol.base.r34);
    output = struct(reportedSeconds=estimate.cost.totalOnlineSeconds, ...
        trigger=false, recoveryAccepted=false);
end
end
