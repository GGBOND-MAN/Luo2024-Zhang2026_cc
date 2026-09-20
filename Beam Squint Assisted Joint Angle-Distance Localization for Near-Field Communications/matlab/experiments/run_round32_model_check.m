function run_round32_model_check()
%RUN_ROUND32_MODEL_CHECK Run the frozen 20-position residual-delay check.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
raw = r31.loadRound30Raw(project);
oldFile = fullfile(project, "results", "full_spectrum", ...
    "round31_angle_controls_v2", "result.mat");
old = load(oldFile, "identity", "results");
protocol = r32.config();
cfg = raw.pilot.expected.cfg;
scan = fsjad.prepareScan(cfg);
indices = find(raw.pilot.design.snrDb == protocol.modelCheck.snrDb);
indices = indices(1:protocol.modelCheck.positionCount);
rows = table();

for localIndex = 1:numel(indices)
    rowIndex = indices(localIndex);
    row = raw.pilot.design(rowIndex, :);
    replay = fsjad.replayRound27Data(cfg, scan, row);
    oldResult = old.results{rowIndex};
    zeroTheta = oldResult.thetaDeg(3);
    zeroRange = oldResult.rangeM(3);
    for delaySeconds = protocol.modelCheck.residualDelaySeconds
        if delaySeconds == 0
            thetaDeg = zeroTheta;
            rangeM = zeroRange;
            frontThetaDeg = oldResult.front.thetaDeg;
            frontRangeM = oldResult.front.rangeM;
            reusedZero = true;
            zMagnitudeDifference = 0;
            yProjectionDifference = 0;
            onlineSeconds = 0;
        else
            [zDelayed, yDelayed] = r32.applyResidualDelay(cfg, ...
                replay.observation, replay.snapshots, delaySeconds);
            zMagnitudeDifference = max(abs(abs(zDelayed).^2 ...
                - abs(replay.observation).^2));
            numerator = sum(conj(replay.snapshots).*yDelayed, 1);
            denominator = vecnorm(replay.snapshots, 2, 1) ...
                .*vecnorm(yDelayed, 2, 1);
            yProjectionDifference = max(abs(1-abs(numerator./denominator).^2));
            estimate = r32.estimatePA(cfg, zDelayed, yDelayed, scan, protocol);
            thetaDeg = estimate.P_A.thetaDeg;
            rangeM = estimate.P_A.rangeM;
            frontThetaDeg = estimate.front.selected.thetaDeg;
            frontRangeM = estimate.front.selected.rangeM;
            reusedZero = false;
            onlineSeconds = estimate.cost.totalOnlineSeconds;
        end
        entry = table(row.seed, row.snrDb, row.truthThetaDeg, ...
            row.truthRangeM, delaySeconds, delaySeconds*1e9, ...
            reusedZero, thetaDeg, rangeM, thetaDeg-zeroTheta, ...
            rangeM-zeroRange, frontThetaDeg, frontRangeM, ...
            zMagnitudeDifference, yProjectionDifference, onlineSeconds, ...
            'VariableNames', {'seed', 'snrDb', 'truthThetaDeg', ...
            'truthRangeM', 'delaySeconds', 'delayNs', 'reusedZero', ...
            'paThetaDeg', 'paRangeM', 'thetaShiftFromZeroDeg', ...
            'rangeShiftFromZeroM', 'frontThetaDeg', 'frontRangeM', ...
            'zPowerMaximumDifference', 'yColumnProjectionDifference', ...
            'onlineSeconds'});
        rows = [rows; entry]; %#ok<AGROW>
    end
end

summary = summarizeDelay(rows);
numericalPass = max(rows.zPowerMaximumDifference) ...
    <= protocol.modelCheck.magnitudeTolerance ...
    && max(rows.yColumnProjectionDifference) ...
    <= protocol.modelCheck.stateProjectionTolerance ...
    && all(isfinite(rows.paThetaDeg)) && all(isfinite(rows.paRangeM));
assessment = struct(numericalInvariancePass=numericalPass, ...
    physicalScope="conditional-idealized-z-plus-Y-acquisition-model", ...
    synchronizationRequired=true, ...
    interpretation="A common residual linear frequency phase is " + ...
    "invisible to z power and per-carrier Y projectors but not to the " + ...
    "coherent full-spectrum profile; any range shift is a synchronization " + ...
    "sensitivity result, not a tuned robustness result.");

folder = fullfile(project, "results", "full_spectrum", ...
    "round32_pa_finite_closeout_v1", "model_check");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(rows, fullfile(folder, "residual_delay_rows.csv"));
writetable(summary, fullfile(folder, "residual_delay_summary.csv"));
source = r32.manifest(project);
writetable(source, fullfile(folder, "source_hashes.csv"));
identity = struct(version="R32-residual-delay-check-v1", ...
    protocol=protocol, selectedSeeds=raw.pilot.design.seed(indices), ...
    pilotHash=raw.pilotHash, oldIdentity=old.identity);
save(fullfile(folder, "result.mat"), "identity", "rows", ...
    "summary", "assessment", "source", "-v7.3");
fprintf("ROUND32_MODEL_CHECK_COMPLETE conditions=%d pass=%d\n", ...
    height(rows), numericalPass);
end

function summary = summarizeDelay(rows)
metrics = ["thetaShiftFromZeroDeg", "rangeShiftFromZeroM", ...
    "zPowerMaximumDifference", "yColumnProjectionDifference"];
summary = table();
for delayNs = unique(rows.delayNs, "stable").'
    selected = rows.delayNs == delayNs;
    values = zeros(1, numel(metrics)*3);
    names = strings(1, numel(metrics)*3);
    cursor = 1;
    for metric = metrics
        vector = rows.(metric)(selected);
        values(cursor:cursor+2) = [mean(vector), max(abs(vector)), ...
            median(vector)];
        names(cursor:cursor+2) = ["mean_"+metric, ...
            "maxAbs_"+metric, "median_"+metric];
        cursor = cursor + 3;
    end
    entry = array2table(values, VariableNames=cellstr(names));
    entry = addvars(entry, delayNs, nnz(selected), Before=1, ...
        NewVariableNames=["delayNs", "n"]);
    summary = [summary; entry]; %#ok<AGROW>
end
end
