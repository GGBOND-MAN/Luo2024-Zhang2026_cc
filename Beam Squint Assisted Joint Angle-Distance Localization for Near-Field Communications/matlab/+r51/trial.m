function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one normal or controlled-stress R51 row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r51.config()
end

result = failureResult(row, rowIndex);
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.base.r34);
    front = shared.front;
    stressAudit = struct(enabled=false, stressType="none");
    if ismember("stressType", string(row.Properties.VariableNames))
        [front, stressAudit] = r51.applyStressFront(front, row, protocol);
        stressAudit.enabled = true;
    end
    backend = r51.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, front, protocol);
    coverage = candidateCoverage(shared.front, row, protocol);

    result.success = true;
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.C_enhanced = location( ...
        shared.C_enhanced.thetaDeg, shared.C_enhanced.rangeM);
    result.P_FA = backend.P_FA;
    result.P_FARC = backend.P_FARC;
    result.trigger_only = backend.trigger_only;
    result.unconditional_wide_global = backend.unconditional_wide_global;
    result.backend = backend;
    result.candidateCoverage = coverage;
    result.stressAudit = stressAudit;
    result.sharedAudit = struct(totalDirectEvdCount= ...
        shared.solverAudit.totalDirectCount, totalGramCount= ...
        shared.solverAudit.totalGramCount, totalFallbackCount= ...
        shared.solverAudit.totalFallbackCount);
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function output = candidateCoverage(front, row, protocol)
count = numel(front.refined);
thetaDeg = zeros(count, 1);
rangeM = zeros(count, 1);
for index = 1:count
    thetaDeg(index) = front.refined{index}.thetaDeg;
    rangeM(index) = front.refined{index}.rangeM;
end
angleError = abs(thetaDeg-row.truthThetaDeg);
rangeError = abs(rangeM-row.truthRangeM);
covered = angleError <= protocol.certificate.sameBasinAngleDeg ...
    & rangeError <= protocol.certificate.sameBasinRangeM;
output = struct(top8Count=count, top8TruthBasinCovered=any(covered), ...
    minimumTop8AngleErrorDeg=min(angleError), ...
    minimumTop8RangeErrorM=min(rangeError), ...
    minimumTop8JointNormalized=min(sqrt( ...
        (angleError/protocol.certificate.sameBasinAngleDeg).^2 ...
        +(rangeError/protocol.certificate.sameBasinRangeM).^2)));
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end

function result = failureResult(row, rowIndex)
result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
end
