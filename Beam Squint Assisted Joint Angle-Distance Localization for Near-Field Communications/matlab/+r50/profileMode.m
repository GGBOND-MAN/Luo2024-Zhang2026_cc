function output = profileMode(profile)
%PROFILEMODE Extract selected peak identity and alternative-score margin.

arguments
    profile (1, 1) struct
end

peakIndex = profile.peakIndex(:);
peakRange = profile.grid(peakIndex);
peakScore = profile.gridScore(peakIndex);
[~, selectedPeak] = min(abs(peakRange-profile.value));
selectedGridIndex = peakIndex(selectedPeak);
selectedPeakRange = peakRange(selectedPeak);
alternative = peakScore;
alternative(selectedPeak) = -inf;
secondScore = max(alternative);
if ~isfinite(secondScore)
    secondScore = -inf;
end
output = struct(selectedRangeM=profile.value, ...
    selectedScore=profile.score, selectedPeakRangeM=selectedPeakRange, ...
    selectedPeakGridIndex=selectedGridIndex, ...
    secondPeakGridScore=secondScore, ...
    scoreMargin=profile.score-secondScore, ...
    retainedPeakCount=numel(peakIndex));
end
