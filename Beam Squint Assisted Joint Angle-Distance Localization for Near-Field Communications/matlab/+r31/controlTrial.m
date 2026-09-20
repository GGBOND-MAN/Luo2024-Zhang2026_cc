function result = controlTrial(cfg, scan, row, replay, inputHash, ...
    pilotItem, baselineItem, enhancedAlgorithm, protocol, l06Candidate)
%CONTROLTRIAL Run fixed-front C/A/B controls on one saved development user.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    replay (1, 1) struct
    inputHash (1, 1) struct
    pilotItem (1, 1) struct
    baselineItem (1, 1) struct
    enhancedAlgorithm (1, 1) struct
    protocol (1, 1) struct
    l06Candidate (1, :) table
end

result = struct(success=false, errorIdentifier="", errorMessage="", ...
    seed=row.seed, snrDb=row.snrDb, version=protocol.version);
sessionTimer = tic;
try
    if pilotItem.candidateId ~= "L06" || baselineItem.candidateId ~= "L06"
        error("r31:IncorrectControlCandidate", ...
            "The control experiment must reuse the saved L06 front.");
    end
    if ~isequaln(pilotItem.front, baselineItem.front)
        error("r31:FrontReuseMismatch", ...
            "The pilot and baseline files do not contain the same L06 front.");
    end
    front = pilotItem.front.selected;
    control = baselineItem.enhancedBaseline;
    [stateA, musicCfg] = r31.stateFromBaseline(cfg, control.estimate, ...
        control.carrierIndex, front.thetaDeg, front.rangeM, ...
        enhancedAlgorithm.subarraySize);
    carrierB = r30.selectLocalCarriers(cfg.numSubcarriers, ...
        l06Candidate.musicCarrierCount, replay.peakCarrierIndex);
    [stateB, columnB] = r31.subsetState(stateA, carrierB);

    timer = tic;
    angleA = r31.stagedAngleMusic(musicCfg, stateA, front.thetaDeg, ...
        front.rangeM, enhancedAlgorithm.localHalfWidthDeg, ...
        enhancedAlgorithm.gridSizes);
    angleASeconds = toc(timer);
    timer = tic;
    profileA = r31.profileAtAngle(cfg, replay.observation, scan, ...
        angleA.thetaDeg, front.rangeM, protocol);
    profileASeconds = toc(timer);

    timer = tic;
    angleB = r31.stagedAngleMusic(musicCfg, stateB, front.thetaDeg, ...
        front.rangeM, enhancedAlgorithm.localHalfWidthDeg, ...
        enhancedAlgorithm.gridSizes);
    angleBSeconds = toc(timer);
    timer = tic;
    profileB = r31.profileAtAngle(cfg, replay.observation, scan, ...
        angleB.thetaDeg, front.rangeM, protocol);
    profileBSeconds = toc(timer);

    result.methodNames = ["C_enhanced", "H_A", "P_A", "H_B", "P_B"];
    result.thetaDeg = [control.estimate.thetaDeg, angleA.thetaDeg, ...
        angleA.thetaDeg, angleB.thetaDeg, angleB.thetaDeg];
    result.rangeM = [control.estimate.rangeM, front.rangeM, ...
        profileA.value, front.rangeM, profileB.value];
    result.front = front;
    compactEstimate = rmfield(control.estimate, "signalVectors");
    result.controlC = struct(label=control.label, ...
        estimate=compactEstimate, carrierIndex=control.carrierIndex, ...
        seconds=control.seconds, gridPoints=control.gridPoints, ...
        carrierGridPoints=control.carrierGridPoints);
    result.angleA = angleA;
    result.profileA = profileA;
    result.angleB = angleB;
    result.profileB = profileB;
    result.carrierA = stateA.carrierIndex;
    result.carrierB = stateB.carrierIndex;
    result.carrierBColumnInA = columnB;
    result.checks.frontExactReuse = true;
    result.checks.carrierBSubsetA = all( ...
        stateA.carrierIndex(columnB) == stateB.carrierIndex);
    result.checks.signalVectorColumnsExact = isequal( ...
        stateA.signalVectors(:, columnB), stateB.signalVectors);
    result.checks.didNotUseControlEstimateAsStart = true;
    result.hash = inputHash;
    result.cost.frontHistoricalSeconds = pilotItem.front.runtimeSeconds;
    result.cost.angleASeconds = angleASeconds;
    result.cost.profileASeconds = profileASeconds;
    result.cost.angleBSeconds = angleBSeconds;
    result.cost.profileBSeconds = profileBSeconds;
    result.cost.angleAEvaluations = angleA.evaluationCount;
    result.cost.angleBEvaluations = angleB.evaluationCount;
    result.cost.profileAEvaluations = profileA.evaluationCount;
    result.cost.profileBEvaluations = profileB.evaluationCount;
    result.success = all(isfinite([result.thetaDeg, result.rangeM])) ...
        && result.checks.carrierBSubsetA ...
        && result.checks.signalVectorColumnsExact;
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
result.experimentSessionSeconds = toc(sessionTimer);
end
