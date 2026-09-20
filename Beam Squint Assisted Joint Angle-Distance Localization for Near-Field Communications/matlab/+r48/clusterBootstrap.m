function output = clusterBootstrap(perUser, protocol, seedOffset)
%CLUSTERBOOTSTRAP Bootstrap P_FAM5 range ratios to P_A and hard P_FA.

arguments
    perUser table
    protocol (1, 1) struct = r48.config()
    seedOffset (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
end

positions = unique(perUser.positionId, "stable");
snrValues = protocol.design.snrDb(:);
numPositions = numel(positions);
numSnr = numel(snrValues);
candidate = zeros(numPositions, numSnr);
pa = zeros(numPositions, numSnr);
hard = zeros(numPositions, numSnr);
for i = 1:numPositions
    for j = 1:numSnr
        selected = perUser.positionId == positions(i) ...
            & perUser.snrDb == snrValues(j);
        candidate(i, j) = perUser.rangeError_P_FAM5(selected)^2;
        pa(i, j) = perUser.rangeError_P_A(selected)^2;
        hard(i, j) = perUser.rangeError_P_FA(selected)^2;
    end
end
observedPA = ratio(candidate, pa, 1:numPositions);
observedHard = ratio(candidate, hard, 1:numPositions);
stream = RandStream("mt19937ar", Seed=protocol.bootstrap.seed+seedOffset);
ratioPA = zeros(protocol.bootstrap.count, 1);
ratioHard = zeros(protocol.bootstrap.count, 1);
for b = 1:protocol.bootstrap.count
    sampled = randi(stream, numPositions, numPositions, 1);
    ratioPA(b) = ratio(candidate, pa, sampled);
    ratioHard(b) = ratio(candidate, hard, sampled);
end
metric = ["range-noninferiority-to-PA"; ...
    "range-superiority-to-hard-PFA"];
observedRatio = [observedPA; observedHard];
upper95 = [quantile(ratioPA, protocol.bootstrap.confidence); ...
    quantile(ratioHard, protocol.bootstrap.confidence)];
limit = [protocol.bootstrap.paUpperLimit; ...
    protocol.bootstrap.hardUpperLimit];
pass = upper95 < limit;
output = struct(summary=table(metric, observedRatio, upper95, limit, pass), ...
    positionCount=numPositions, ratioPA=ratioPA, ratioHard=ratioHard);
end

function value = ratio(candidate, reference, selected)
value = mean(mean(candidate(selected, :), 1)) ...
    /mean(mean(reference(selected, :), 1));
end
