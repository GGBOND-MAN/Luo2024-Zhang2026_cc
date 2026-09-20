function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R56 development row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r56.config()
end

result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.base.base.r34);
    backend = r56.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol);
    methods = ["P_FA", "P_FALF", "P_FALF_QB", "P_FALF_SC"];
    for method = methods
        if backend.(method).thetaDeg ~= backend.P_FA.thetaDeg
            error("r56:AngleIdentity", ...
                "Every R56 method must preserve the frozen P_FA angle.");
        end
    end
    result.success = true;
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.C_enhanced = location( ...
        shared.C_enhanced.thetaDeg, shared.C_enhanced.rangeM);
    for method = methods
        result.(method) = backend.(method);
    end
    result.consensus = backend.consensus;
    result.consensusSwitch = backend.consensusSwitch;
    result.qSelectedCandidateIndex = backend.qSelectedCandidateIndex;
    result.selectedCandidateIndex = backend.selectedCandidateIndex;
    result.oddBestCandidateIndex = backend.oddBestCandidateIndex;
    result.evenBestCandidateIndex = backend.evenBestCandidateIndex;
    result.jointBestCandidateIndex = backend.jointBestCandidateIndex;
    result.pfalfLargeShift = ...
        abs(result.P_FALF.rangeM-result.P_FA.rangeM) > 0.1;
    result.scLargeShift = ...
        abs(result.P_FALF_SC.rangeM-result.P_FA.rangeM) > 0.1;
    pfaSquared = (result.P_FA.rangeM-row.truthRangeM)^2;
    pfalfSquared = (result.P_FALF.rangeM-row.truthRangeM)^2;
    scSquared = (result.P_FALF_SC.rangeM-row.truthRangeM)^2;
    result.pfalfHarmful = pfalfSquared > pfaSquared;
    result.scHarmful = scSquared > pfaSquared;
    result.pfalfLargeShiftHarmful = ...
        result.pfalfLargeShift && result.pfalfHarmful;
    result.scLargeShiftHarmful = result.scLargeShift && result.scHarmful;
    result.backendSeconds = backend.backendSeconds;
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end
