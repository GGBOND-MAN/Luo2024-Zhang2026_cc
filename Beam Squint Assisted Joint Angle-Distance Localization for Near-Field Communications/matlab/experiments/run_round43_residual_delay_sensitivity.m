function output = run_round43_residual_delay_sensitivity(options)
%RUN_ROUND43_RESIDUAL_DELAY_SENSITIVITY Audit coherent-Y timing sensitivity.

arguments
    options.NumWorkers (1, 1) double {mustBeInteger, mustBePositive} = 4
    options.PoolType (1, 1) string ...
        {mustBeMember(options.PoolType, ["Threads", "Processes"])} = "Threads"
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
addpath(fullfile(project, "+r38", "schemeF"));
folder = fullfile(project, "results", "full_spectrum", ...
    "round43_coherent_sequential_development_v1", "positions_10");
saved = load(fullfile(folder, "result.mat"), ...
    "design", "results", "protocol", "identity");
if ~saved.identity.pilotPass || saved.identity.finalTrialsReadOrExecuted ~= 0
    error("r43:DelayAuditIdentity", ...
        "The delay audit requires the completed R43 development pilot.");
end
selected = find(saved.design.snrDb == 0);
delays = [-0.1e-9, 0.1e-9];
numRows = numel(selected)*numel(delays);
thetaDeg = zeros(numel(selected), 1);
frontRangeM = zeros(numel(selected), 1);
zeroRangeM = zeros(numel(selected), 1);
carrierIndex = cell(numel(selected), 1);
for index = 1:numel(selected)
    trial = saved.results{selected(index)};
    thetaDeg(index) = trial.h.angle.thetaDeg;
    frontRangeM(index) = trial.h.front.selected.rangeM;
    zeroRangeM(index) = trial.h.H_seqY.rangeM;
    carrierIndex{index} = trial.h.contextCarrierIndex;
end
clear trial

pool = gcp("nocreate");
requiredClass = "parallel.ThreadPool";
if options.PoolType == "Processes"
    requiredClass = "parallel.ProcessPool";
end
if ~isempty(pool) && string(class(pool)) ~= requiredClass
    delete(pool);
    pool = [];
end
if isempty(pool)
    parpool(options.PoolType, options.NumWorkers);
end
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
records = cell(numRows, 1);
parfor outputIndex = 1:numRows
    positionIndex = ceil(outputIndex/numel(delays));
    delayIndex = mod(outputIndex-1, numel(delays))+1;
    designIndex = selected(positionIndex);
    row = saved.design(designIndex, :);
    replay = fsjad.replayRound27Data(cfg, scan, row);
    [~, delayedSnapshots] = r32.applyResidualDelay(cfg, ...
        replay.observation, replay.snapshots, delays(delayIndex));
    carriers = carrierIndex{positionIndex};
    context = r42.prepareContext(cfg, scan, replay.observation, ...
        delayedSnapshots(:, carriers+1), carriers);
    profile = r43.profileRange(cfg, context, replay.observation, scan, ...
        thetaDeg(positionIndex), frontRangeM(positionIndex), ...
        "Y", saved.protocol);
    expectedShiftM = cfg.c*delays(delayIndex);
    records{outputIndex} = table(row.positionId, row.seed, row.snrDb, ...
        row.truthThetaDeg, row.truthRangeM, delays(delayIndex), ...
        delays(delayIndex)*1e9, zeroRangeM(positionIndex), profile.value, ...
        profile.value-zeroRangeM(positionIndex), expectedShiftM, ...
        profile.value-zeroRangeM(positionIndex)-expectedShiftM, ...
        profile.value-row.truthRangeM, profile.runtimeSeconds, ...
        'VariableNames', {'positionId', 'seed', 'snrDb', ...
        'truthThetaDeg', 'truthRangeM', 'delaySeconds', 'delayNs', ...
        'zeroRangeM', 'delayedRangeM', 'rangeShiftM', ...
        'expectedShiftM', 'shiftResidualM', 'rangeErrorM', ...
        'profileRuntimeSeconds'});
end
rows = vertcat(records{:});
zeroError = zeroRangeM-saved.design.truthRangeM(selected);
zeroRmseM = sqrt(mean(zeroError.^2));
delayNs = delays(:)*1e9;
meanRangeShiftM = zeros(numel(delays), 1);
stdRangeShiftM = zeros(numel(delays), 1);
maxAbsShiftResidualM = zeros(numel(delays), 1);
rangeRmseM = zeros(numel(delays), 1);
for delayIndex = 1:numel(delays)
    selectedDelay = rows.delaySeconds == delays(delayIndex);
    meanRangeShiftM(delayIndex) = mean(rows.rangeShiftM(selectedDelay));
    stdRangeShiftM(delayIndex) = std(rows.rangeShiftM(selectedDelay));
    maxAbsShiftResidualM(delayIndex) = ...
        max(abs(rows.shiftResidualM(selectedDelay)));
    rangeRmseM(delayIndex) = ...
        sqrt(mean(rows.rangeErrorM(selectedDelay).^2));
end
zeroRangeRmseM = repmat(zeroRmseM, numel(delays), 1);
mseRatioToZero = (rangeRmseM/zeroRmseM).^2;
summary = table(delayNs, meanRangeShiftM, stdRangeShiftM, ...
    maxAbsShiftResidualM, rangeRmseM, zeroRangeRmseM, mseRatioToZero);
writetable(rows, fullfile(folder, "residual_delay_rows.csv"));
writetable(summary, fullfile(folder, "residual_delay_summary.csv"));
identity = struct(version="R43-coherent-Y-delay-sensitivity-v1", ...
    date="2026-09-17", evidenceRole="secondary-model-audit", ...
    snrDb=0, delaysSeconds=delays, positionCount=numel(selected), ...
    estimatorSelectionChanged=false, finalDataRead=false, ...
    interpretation="Y-only residual timing phase; z/front/angle frozen");
save(fullfile(folder, "residual_delay_result.mat"), ...
    "identity", "rows", "summary");
output = struct(identity=identity, rows=rows, summary=summary);
disp(summary);
end
