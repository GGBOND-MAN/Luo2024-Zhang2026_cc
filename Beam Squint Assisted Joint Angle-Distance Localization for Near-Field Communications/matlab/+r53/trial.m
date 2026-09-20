function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R53 development row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r53.config()
end

result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
        replay.snapshots, scan, protocol.base.r34);
    backend = r53.fromFront(cfg, replay.observation, replay.snapshots, ...
        scan, shared.front, protocol);
    yOnly = r53.profileRange(cfg, backend.context, ...
        backend.P_FA.thetaDeg, shared.front.selected.rangeM, "Y", protocol);
    qProfile = r33.profileAtAngle(cfg, replay.observation, scan, ...
        backend.P_FA.thetaDeg, shared.front.selected.rangeM, ...
        protocol.base.r34.r33);
    if abs(qProfile.value-backend.P_FA.rangeM) > 1e-7
        error("r53:FrozenPfaRangeMismatch", ...
            "The diagnostic q profile does not reproduce frozen P_FA.");
    end
    commonCurvature = r53.curvature(cfg, backend.context, ...
        backend.P_FA.thetaDeg, backend.P_FA.rangeM, protocol);
    selectedCurvature = r53.curvature(cfg, backend.context, ...
        backend.P_FA.thetaDeg, backend.P_FALF.rangeM, protocol);
    qMode = r50.profileMode(qProfile);
    jointQPeak = nearestPeak(qProfile, backend.P_FALF.rangeM);
    yQPeak = nearestPeak(qProfile, yOnly.value);

    result.success = true;
    result.P_A = location(shared.P_A.thetaDeg, shared.P_A.rangeM);
    result.P_FA = backend.P_FA;
    result.Y_only = location(backend.P_FA.thetaDeg, yOnly.value);
    result.P_FALF = backend.P_FALF;
    result.frontThetaDeg = shared.front.selected.thetaDeg;
    result.frontRangeM = shared.front.selected.rangeM;
    result.angleIdentityDifferenceDeg = ...
        abs(result.P_FALF.thetaDeg-result.P_FA.thetaDeg);
    result.rangeShiftM = result.P_FALF.rangeM-result.P_FA.rangeM;
    result.qPeakChanged = jointQPeak ~= qMode.selectedPeakGridIndex;
    result.yOnlyZBasinAgreement = yQPeak == qMode.selectedPeakGridIndex;
    result.qSelectedPeakGridIndex = qMode.selectedPeakGridIndex;
    result.jointNearestQPeakGridIndex = jointQPeak;
    result.yNearestQPeakGridIndex = yQPeak;
    result.commonCurvature = commonCurvature;
    result.selectedCurvature = selectedCurvature;
    result.qProfile = compactProfile(qProfile);
    result.yProfile = compactProfile(yOnly);
    result.jointProfile = compactProfile(backend.jointProfile);
    result.runtime = struct(pfaBackendSeconds=backend.pfa.backendSeconds, ...
        jointProfileSeconds=backend.jointProfile.runtimeSeconds, ...
        yDiagnosticSeconds=yOnly.runtimeSeconds, ...
        researchBackendSeconds=backend.backendSeconds);
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function index = nearestPeak(profile, rangeM)
peakIndex = profile.peakIndex(:);
[~, selected] = min(abs(profile.grid(peakIndex)-rangeM));
index = peakIndex(selected);
end

function output = compactProfile(input)
mode = r50.profileMode(input);
output = struct(value=input.value, score=input.score, ...
    interval=input.interval, endpointHit=input.endpointHit, ...
    nearBoundary=input.nearBoundary, evaluationCount=input.evaluationCount, ...
    selectedPeakGridIndex=mode.selectedPeakGridIndex, ...
    scoreMargin=mode.scoreMargin);
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end
