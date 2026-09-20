function result = estimate(cfg, observation, snapshots, scan, protocol)
%ESTIMATE Standalone PA-free Scheme H estimator from current z/Y.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    protocol (1, 1) struct = r42.config()
end

totalTimer = tic;
frontProtocol = r30.config();
frontProtocol.frontVersion = protocol.front.version;
frontProtocol.angleOffsetsDeg = protocol.front.angleOffsetsDeg;
front = r30.front(cfg, observation, scan, frontProtocol, r32.candidate());
carrierIndex = r30.selectLocalCarriers(cfg.numSubcarriers, ...
    protocol.array.carrierCount, front.peakCarrierIndex);
context = r42.prepareContext(cfg, scan, observation, ...
    snapshots(:, carrierIndex+1), carrierIndex);

arrayTimer = tic;
array = r42.arrayAblation(cfg, context, observation, scan, ...
    front.selected, protocol);
arraySeconds = toc(arrayTimer);

numCandidates = numel(front.refined);
candidateCost = inf(numCandidates, 1);
for index = 1:numCandidates
    candidate = front.refined{index};
    if isfinite(candidate.thetaDeg) && isfinite(candidate.rangeM) ...
            && candidate.rangeM > 0
        candidateCost(index) = r42.jointCost(cfg, context, ...
            candidate.thetaDeg, candidate.rangeM, protocol);
    end
end
[~, order] = sort(candidateCost, "ascend");
validOrder = order(isfinite(candidateCost(order)));
if isempty(validOrder)
    error("r42:NoValidFrontCandidate", ...
        "The L06 front did not provide a finite Scheme H start.");
end
selected = validOrder(1:min(protocol.joint.numStarts, numel(validOrder)));
refined = cell(numel(selected), 1);
for startIndex = 1:numel(selected)
    candidate = front.refined{selected(startIndex)};
    refined{startIndex} = r42.refineJoint(cfg, context, ...
        candidate.thetaDeg, candidate.rangeM, protocol);
end
finalCost = cellfun(@(item) item.cost, refined);
[~, best] = min(finalCost);
joint = refined{best};

result = struct(version=protocol.version, ...
    inputContract="current-z-current-Y-scan-known-config-only", ...
    thetaDeg=joint.thetaDeg, rangeM=joint.rangeM, ...
    front=front, array=array, joint=joint, jointStarts={refined}, ...
    selectedFrontCandidateIndex=selected(best), ...
    selectedStartRank=best, candidateCost=candidateCost, ...
    selectedCandidateIndex=selected, carrierIndex=carrierIndex, ...
    fullArrayEvaluationCount=sum(cellfun( ...
    @(item) item.evaluationCount, refined)) ...
    +array.angleGridEvaluationCount+array.angleOptimizerEvaluationCount, ...
    jointEvaluationCount=sum(cellfun(@(item) item.evaluationCount, refined)), ...
    completeProfilePassCount=0, arrayProfilePassCount=1, ...
    frontSeconds=front.runtimeSeconds, arraySeconds=arraySeconds, ...
    totalOnlineSeconds=toc(totalTimer));
end
