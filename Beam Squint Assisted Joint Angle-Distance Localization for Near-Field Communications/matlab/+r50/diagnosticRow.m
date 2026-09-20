function output = diagnosticRow(cfg, scan, row, saved, rowIndex, protocol)
%DIAGNOSTICROW Compute R50 diagnostics for one frozen R48 row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    saved (1, 1) struct
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r50.config()
end

output = failureResult(row, rowIndex);
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    context = r33.prepareResponseContext(cfg, scan, replay.observation);
    frontRangeM = saved.backend.frontRangeM;
    thetaA = saved.P_A.thetaDeg;
    rangeA = saved.P_A.rangeM;
    thetaFA = saved.P_FA.thetaDeg;
    rangeFA = saved.P_FA.rangeM;
    angle = saved.backend.angle;
    [~, gridBest] = max(angle.gridScore);
    thetaGrid = angle.gridDeg(gridBest);

    profileA = r33.profileAtAngle(cfg, replay.observation, scan, ...
        thetaA, frontRangeM, protocol.localProfile);
    profileFA = r33.profileAtAngle(cfg, replay.observation, scan, ...
        thetaFA, frontRangeM, protocol.localProfile);
    assertClose(profileA.value, rangeA, 1e-7, "P_A");
    assertClose(profileFA.value, rangeFA, 1e-7, "P_FA");
    profileGrid = r33.profileAtAngle(cfg, replay.observation, scan, ...
        thetaGrid, frontRangeM, protocol.localProfile);
    oracleLocal = r33.profileAtAngle(cfg, replay.observation, scan, ...
        row.truthThetaDeg, frontRangeM, protocol.localProfile);
    oracleGlobal = r50.globalProfileAtAngle(cfg, row.truthThetaDeg, ...
        context, frontRangeM, protocol);

    hessianA = r50.qHessian(cfg, context, thetaA, rangeA, protocol);
    hessianFA = r50.qHessian(cfg, context, thetaFA, rangeFA, protocol);
    modeA = r50.profileMode(profileA);
    modeFA = r50.profileMode(profileFA);
    peakDifferenceM = abs(modeFA.selectedPeakRangeM ...
        -modeA.selectedPeakRangeM);
    kappaMean = mean([hessianA.kappaMPerDeg, ...
        hessianFA.kappaMPerDeg], "omitnan");
    if ~isfinite(kappaMean)
        predictedRangeDifferenceM = nan;
    else
        predictedRangeDifferenceM = kappaMean*(thetaFA-thetaA);
    end

    output.success = true;
    output.truthThetaDeg = row.truthThetaDeg;
    output.truthRangeM = row.truthRangeM;
    output.frontThetaDeg = saved.backend.frontThetaDeg;
    output.frontRangeM = frontRangeM;
    output.thetaA = thetaA;
    output.rangeA = rangeA;
    output.thetaFA = thetaFA;
    output.rangeFA = rangeFA;
    output.rangeFAM5 = saved.P_FAM5.rangeM;
    output.thetaGrid = thetaGrid;
    output.rangeGrid = profileGrid.value;
    output.rangeOracleLocal = oracleLocal.value;
    output.rangeOracleGlobal = oracleGlobal.value;
    output.profileA = compactProfile(profileA);
    output.profileFA = compactProfile(profileFA);
    output.profileGrid = compactProfile(profileGrid);
    output.oracleLocal = compactProfile(oracleLocal);
    output.oracleGlobal = compactProfile(oracleGlobal);
    output.hessianA = hessianA;
    output.hessianFA = hessianFA;
    output.modeA = modeA;
    output.modeFA = modeFA;
    output.selectedPeakDifferenceM = peakDifferenceM;
    output.predictedRangeDifferenceM = predictedRangeDifferenceM;
    output.actualRangeDifferenceM = rangeFA-rangeA;
    output.responseEvaluations = profileA.evaluationCount ...
        +profileFA.evaluationCount+profileGrid.evaluationCount ...
        +oracleLocal.evaluationCount+oracleGlobal.evaluationCount ...
        +hessianA.evaluationCount+hessianFA.evaluationCount;
catch exception
    output.errorIdentifier = string(exception.identifier);
    output.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end

function assertClose(actual, expected, tolerance, label)
if abs(actual-expected) > tolerance
    error("r50:FrozenRangeIdentityMismatch", ...
        "%s profile replay differs from the frozen R48 value.", label);
end
end

function output = compactProfile(input)
output = struct(value=input.value, score=input.score, ...
    interval=input.interval, endpointHit=input.endpointHit, ...
    nearBoundary=input.nearBoundary, evaluationCount=input.evaluationCount, ...
    selectedMode=r50.profileMode(input));
end

function output = failureResult(row, rowIndex)
output = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
end
