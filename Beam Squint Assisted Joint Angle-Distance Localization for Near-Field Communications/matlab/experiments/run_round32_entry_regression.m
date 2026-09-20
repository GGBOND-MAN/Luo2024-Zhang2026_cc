function run_round32_entry_regression()
%RUN_ROUND32_ENTRY_REGRESSION Rebuild P_A for the first user at each SNR.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
raw = r31.loadRound30Raw(project);
oldFile = fullfile(project, "results", "full_spectrum", ...
    "round31_angle_controls_v2", "result.mat");
old = load(oldFile, "identity", "results");
protocol = r32.config();
cfg = raw.pilot.expected.cfg;
scan = fsjad.prepareScan(cfg);
rows = zeros(3, 1);
snrValues = [-10, 0, 20];
for index = 1:numel(snrValues)
    rows(index) = find(raw.pilot.design.snrDb == snrValues(index), 1);
end

summary = table();
minimal = cell(numel(rows), 1);
for index = 1:numel(rows)
    row = raw.pilot.design(rows(index), :);
    replay = fsjad.replayRound27Data(cfg, scan, row);
    current = r32.estimatePA(cfg, replay.observation, ...
        replay.snapshots, scan, protocol);
    historical = old.results{rows(index)};
    delta = [current.front.selected.thetaDeg-historical.front.thetaDeg, ...
        current.front.selected.rangeM-historical.front.rangeM, ...
        current.P_A.thetaDeg-historical.thetaDeg(3), ...
        current.P_A.rangeM-historical.rangeM(3)];
    pass = all(abs(delta) <= [1e-10, 1e-8, 1e-10, 1e-8]);
    if ~pass
        error("r32:IndependentEntryRegression", ...
            "The independent P_A entry did not reproduce seed %.0f.", row.seed);
    end
    entry = table(row.seed, row.snrDb, delta(1), delta(2), ...
        delta(3), delta(4), current.cost.totalOnlineSeconds, pass, ...
        'VariableNames', {'seed', 'snrDb', 'frontThetaDeltaDeg', ...
        'frontRangeDeltaM', 'paThetaDeltaDeg', 'paRangeDeltaM', ...
        'onlineSeconds', 'pass'});
    summary = [summary; entry]; %#ok<AGROW>
    minimal{index} = struct(seed=row.seed, snrDb=row.snrDb, ...
        truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
        front=current.front.selected, angle=current.angle, ...
        profile=current.profile, H_A=current.H_A, P_A=current.P_A, ...
        cost=current.cost, observationHash=r31.arrayHash(replay.observation), ...
        snapshotHash=r31.arrayHash(replay.snapshots));
end

folder = fullfile(project, "results", "full_spectrum", ...
    "round32_pa_finite_closeout_v1", "entry_regression");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(summary, fullfile(folder, "first_user_each_snr.csv"));
source = r32.manifest(project);
writetable(source, fullfile(folder, "source_hashes.csv"));
identity = struct(version="R32-independent-entry-regression-v1", ...
    protocol=protocol, oldIdentity=old.identity, ...
    pilotHash=raw.pilotHash, baselineHash=raw.baselineHash);
save(fullfile(folder, "result.mat"), "identity", "summary", ...
    "minimal", "source", "-v7.3");
fprintf("ROUND32_ENTRY_REGRESSION_COMPLETE users=%d\n", height(summary));
end
