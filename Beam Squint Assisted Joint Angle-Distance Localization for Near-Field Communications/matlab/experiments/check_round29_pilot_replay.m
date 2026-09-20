function check_round29_pilot_replay()
%CHECK_ROUND29_PILOT_REPLAY One preselected user's serial-versus-worker wiring check.
project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
setup = r29.setup(project,"pilot");
root = fullfile(project,"results","full_spectrum","round29_pilot_v1");
file = fullfile(root,"replay_check.mat");
identity = struct(setup=setup,seed=setup.design.seed(1));
if isfile(file)
    saved = load(file,"identity");
    r29.assertIdentity(saved.identity,identity);
    fprintf("R29_REPLAY_ALREADY_COMPLETE\n");
    return;
end
shard = load(fullfile(root,"shard_01_of_01","result.mat"));
r29.assertIdentity(shard.identity.setup,setup);
reference = shard.results{1};
row = setup.design(1,:);
scan = fsjad.prepareScan(setup.cfg);
repeated = r29.trial(setup.cfg,setup.algorithm,setup.protocol,scan,row);
assert(reference.success && repeated.success,"r29:ReplayExecutionFailed");
protocol = setup.protocol;
angleDifference = max(abs(reference.thetaDeg-repeated.thetaDeg));
rangeDifference = max(abs(reference.rangeM-repeated.rangeM));
scoreDifference = abs(reference.front.selected.score-repeated.front.selected.score);
observationDifference = max(abs(reference.replay.observation-repeated.replay.observation));
snapshotDifference = max(abs(reference.replay.snapshots-repeated.replay.snapshots),[],"all");
sameCarriers = isequal(reference.frozen.carrierIndex,repeated.frozen.carrierIndex);
sameMode = angleDifference<=protocol.modeAngleDeg && rangeDifference<=protocol.modeRangeM;
passed = observationDifference<=1e-12 && snapshotDifference<=1e-12 && sameCarriers ...
    && scoreDifference<=protocol.scoreTolerance && angleDifference<=protocol.angleToleranceDeg ...
    && rangeDifference<=protocol.rangeToleranceM && sameMode;
summary = table(row.seed,observationDifference,snapshotDifference, ...
    angleDifference,rangeDifference,scoreDifference,sameCarriers,sameMode,passed);
save(file,"identity","summary","reference","repeated","passed","-v7.3");
writetable(summary,fullfile(root,"replay_check.csv"));
fprintf("ROUND29_PILOT_REPLAY passed=%d\n",passed);
end
