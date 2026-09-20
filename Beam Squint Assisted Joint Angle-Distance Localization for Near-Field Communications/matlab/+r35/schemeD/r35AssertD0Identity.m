function audit = r35AssertD0Identity(pa, d0, protocol)
%R35ASSERTD0IDENTITY Require uniform weighted fusion to reproduce P_A.

arguments
    pa (1, 1) struct
    d0 (1, 1) struct
    protocol (1, 1) struct = r35SchemeDConfig()
end

paStages = pa.estimate.stages;
d0Stages = d0.stages;
if numel(paStages) ~= numel(d0Stages)
    error("r35:D0StageCountMismatch", ...
        "D0 and P_A do not have the same number of angle stages.");
end

gridPass = true;
indexPass = true;
thetaPass = true;
scoreDifference = zeros(numel(paStages), 1);
for level = 1:numel(paStages)
    gridPass = gridPass && isequal(paStages(level).thetaGridDeg, ...
        d0Stages(level).thetaGridDeg);
    indexPass = indexPass && paStages(level).selectedIndex ...
        == d0Stages(level).selectedIndex;
    thetaPass = thetaPass && abs(paStages(level).selectedThetaDeg ...
        -d0Stages(level).selectedThetaDeg) ...
        <= protocol.d0ThetaToleranceDeg;
    if isequal(size(paStages(level).score), size(d0Stages(level).score))
        scoreDifference(level) = max(abs( ...
            paStages(level).score-d0Stages(level).score));
    else
        scoreDifference(level) = inf;
    end
end
finalThetaDifferenceDeg = abs(pa.thetaDeg-d0.thetaDeg);
passed = gridPass && indexPass && thetaPass ...
    && finalThetaDifferenceDeg <= protocol.d0ThetaToleranceDeg ...
    && max(scoreDifference) <= protocol.d0ScoreTolerance;
audit = struct(passed=passed, gridPass=gridPass, ...
    selectedIndexPass=indexPass, selectedThetaPass=thetaPass, ...
    maximumStageScoreDifference=max(scoreDifference), ...
    stageMaximumScoreDifference=scoreDifference, ...
    finalThetaDifferenceDeg=finalThetaDifferenceDeg);
if ~passed
    error("r35:D0UniformFusionIdentityFailure", ...
        "D0 did not reproduce the frozen P_A angle search.");
end
end
