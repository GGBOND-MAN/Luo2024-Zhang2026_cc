function output = qCandidates(profile)
%QCANDIDATES Extract one refined candidate and bracket per retained q peak.

arguments
    profile (1, 1) struct
end

peakIndex = profile.peakIndex(:);
count = numel(peakIndex);
candidateIndex = (1:count).';
peakGridIndex = peakIndex;
peakRangeM = profile.grid(peakIndex);
lowerM = zeros(count, 1);
upperM = zeros(count, 1);
rangeM = peakRangeM;
qScore = profile.gridScore(peakIndex);
for index = 1:count
    lowerIndex = max(1, peakIndex(index)-1);
    upperIndex = min(numel(profile.grid), peakIndex(index)+1);
    lowerM(index) = profile.grid(lowerIndex);
    upperM(index) = profile.grid(upperIndex);
    if height(profile.refinement) >= index ...
            && profile.refinement.accepted(index) ...
            && isfinite(profile.refinement.value(index)) ...
            && isfinite(profile.refinement.score(index))
        rangeM(index) = profile.refinement.value(index);
        qScore(index) = profile.refinement.score(index);
    end
end
[~, qSelectedIndex] = min(abs(rangeM-profile.value));
isQSelected = candidateIndex == qSelectedIndex;
output = table(candidateIndex, peakGridIndex, peakRangeM, ...
    lowerM, upperM, rangeM, qScore, isQSelected);
end
