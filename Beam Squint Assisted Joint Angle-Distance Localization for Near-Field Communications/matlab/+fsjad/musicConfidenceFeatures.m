function features = musicConfidenceFeatures(front, music)
%MUSICCONFIDENCEFEATURES Extract truth-free range-gating diagnostics.

initial = spectrumFeatures(music.initialSpectrum);
refined = spectrumFeatures(music.spectrum);
features.frontScore = front.score;
features.frontScoreGap = front.scoreGap;
features.frontConverged = double(front.converged);
features.rangeDeltaM = music.rangeM - front.rangeM;
features.absRangeDeltaM = abs(features.rangeDeltaM);
features.angleDeltaDeg = music.thetaDeg - front.thetaDeg;
features.absAngleDeltaDeg = abs(features.angleDeltaDeg);
features.initialBoundaryPeak = initial.boundaryPeak;
features.initialLogPeakToMedian = initial.logPeakToMedian;
features.initialCompetitorGap = initial.competitorGap;
features.initialRangeNeighborDrop = initial.rangeNeighborDrop;
features.initialAngleNeighborDrop = initial.angleNeighborDrop;
features.initialRangeBoundaryDistance = initial.rangeBoundaryDistance;
features.initialAngleBoundaryDistance = initial.angleBoundaryDistance;
features.refinedBoundaryPeak = refined.boundaryPeak;
features.refinedLogPeakToMedian = refined.logPeakToMedian;
features.refinedCompetitorGap = refined.competitorGap;
features.refinedRangeNeighborDrop = refined.rangeNeighborDrop;
features.refinedAngleNeighborDrop = refined.angleNeighborDrop;
features.refinedRangeBoundaryDistance = refined.rangeBoundaryDistance;
features.refinedAngleBoundaryDistance = refined.angleBoundaryDistance;
end

function metrics = spectrumFeatures(spectrum)
[numRows, numColumns] = size(spectrum);
[peakValue, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
exclusionRows = max(1, peakRow - 1):min(numRows, peakRow + 1);
exclusionColumns = max(1, peakColumn - 1):min(numColumns, peakColumn + 1);
competitorMask = true(size(spectrum));
competitorMask(exclusionRows, exclusionColumns) = false;
competitorValue = max(spectrum(competitorMask), [], "all");

rangeNeighbors = [peakRow - 1, peakRow + 1];
rangeNeighbors = rangeNeighbors(rangeNeighbors >= 1 & rangeNeighbors <= numRows);
angleNeighbors = [peakColumn - 1, peakColumn + 1];
angleNeighbors = angleNeighbors( ...
    angleNeighbors >= 1 & angleNeighbors <= numColumns);
rangeNeighborValue = max(spectrum(rangeNeighbors, peakColumn), [], "all");
angleNeighborValue = max(spectrum(peakRow, angleNeighbors), [], "all");

metrics.boundaryPeak = double(peakRow == 1 || peakRow == numRows ...
    || peakColumn == 1 || peakColumn == numColumns);
metrics.logPeakToMedian = log(max(peakValue, eps) ...
    / max(median(spectrum, "all"), eps));
metrics.competitorGap = max(peakValue - competitorValue, 0);
metrics.rangeNeighborDrop = max(peakValue - rangeNeighborValue, 0);
metrics.angleNeighborDrop = max(peakValue - angleNeighborValue, 0);
metrics.rangeBoundaryDistance = min(peakRow - 1, numRows - peakRow) ...
    / max(numRows - 1, 1);
metrics.angleBoundaryDistance = min(peakColumn - 1, ...
    numColumns - peakColumn) / max(numColumns - 1, 1);
end
