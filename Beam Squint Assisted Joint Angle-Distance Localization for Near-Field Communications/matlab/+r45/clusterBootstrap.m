function output = clusterBootstrap(perUser, protocol, seedOffset)
%CLUSTERBOOTSTRAP Position-cluster ratios for P_FA versus P_A.

arguments
    perUser table
    protocol (1, 1) struct = r45.config()
    seedOffset (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
end

positions = unique(perUser.positionId, "stable");
snrValues = protocol.design.snrDb(:);
numPositions = numel(positions);
numSnr = numel(snrValues);
angleCandidate = zeros(numPositions, numSnr);
angleReference = zeros(numPositions, numSnr);
rangeCandidate = zeros(numPositions, numSnr);
rangeReference = zeros(numPositions, numSnr);
for positionIndex = 1:numPositions
    for snrIndex = 1:numSnr
        selected = perUser.positionId == positions(positionIndex) ...
            & perUser.snrDb == snrValues(snrIndex);
        if nnz(selected) ~= 1
            error("r45:BootstrapClusterBalance", ...
                "Every position must contribute one row per SNR.");
        end
        angleCandidate(positionIndex, snrIndex) = ...
            perUser.angleError_P_FA(selected)^2;
        angleReference(positionIndex, snrIndex) = ...
            perUser.angleError_P_A(selected)^2;
        rangeCandidate(positionIndex, snrIndex) = ...
            perUser.rangeError_P_FA(selected)^2;
        rangeReference(positionIndex, snrIndex) = ...
            perUser.rangeError_P_A(selected)^2;
    end
end
angleObserved = equalSnrRatio(angleCandidate, angleReference, 1:numPositions);
rangeObserved = equalSnrRatio(rangeCandidate, rangeReference, 1:numPositions);
stream = RandStream("mt19937ar", ...
    Seed=protocol.bootstrap.seed+seedOffset);
angleRatio = zeros(protocol.bootstrap.count, 1);
rangeRatio = zeros(protocol.bootstrap.count, 1);
for replicate = 1:protocol.bootstrap.count
    sampled = randi(stream, numPositions, numPositions, 1);
    angleRatio(replicate) = equalSnrRatio( ...
        angleCandidate, angleReference, sampled);
    rangeRatio(replicate) = equalSnrRatio( ...
        rangeCandidate, rangeReference, sampled);
end
confidence = protocol.bootstrap.confidence;
angleUpper = quantile(angleRatio, confidence);
rangeUpper = quantile(rangeRatio, confidence);
metric = ["angle-superiority"; "range-noninferiority"];
observedRatio = [angleObserved; rangeObserved];
upper95 = [angleUpper; rangeUpper];
limit = [protocol.bootstrap.angleUpperLimit; ...
    protocol.bootstrap.rangeUpperLimit];
pass = upper95 < limit;
summary = table(metric, observedRatio, upper95, limit, pass);
output = struct(version="R45-position-cluster-bootstrap-v1", ...
    positionCount=numPositions, snrDb=snrValues, ...
    replicateCount=protocol.bootstrap.count, ...
    seed=protocol.bootstrap.seed+seedOffset, summary=summary, ...
    angleRatio=angleRatio, rangeRatio=rangeRatio);
end

function ratio = equalSnrRatio(candidate, reference, selected)
candidateMse = mean(candidate(selected, :), 1);
referenceMse = mean(reference(selected, :), 1);
ratio = mean(candidateMse)/mean(referenceMse);
end
