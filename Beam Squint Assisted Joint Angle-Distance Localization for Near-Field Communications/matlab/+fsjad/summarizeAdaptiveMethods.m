function [details, summary] = summarizeAdaptiveMethods(trials, thresholdDb)
%SUMMARIZEADAPTIVEMETHODS Compare front, fixed, and gated estimators.

numTrials = height(trials);
methodNames = ["Full-spectrum front"; "Fixed narrow MUSIC"; ...
    "Adaptive angle-MUSIC/range-gate"];
numMethods = numel(methodNames);
method = repmat(methodNames, numTrials, 1);
snrDb = repelem(trials.snrDb, numMethods);

adaptiveRange = trials.frontRangeErrorM;
useMusicRange = trials.snrDb <= thresholdDb;
adaptiveRange(useMusicRange) = trials.musicRangeErrorM(useMusicRange);

angleErrorDeg = [trials.frontAngleErrorDeg.'; ...
    trials.musicAngleErrorDeg.'; trials.musicAngleErrorDeg.'];
rangeErrorM = [trials.frontRangeErrorM.'; ...
    trials.musicRangeErrorM.'; adaptiveRange.'];
angleErrorDeg = angleErrorDeg(:);
rangeErrorM = rangeErrorM(:);
angleErrorSquared = angleErrorDeg.^2;
rangeErrorSquared = rangeErrorM.^2;
captured = abs(angleErrorDeg) <= 1 & abs(rangeErrorM) <= 1;
boundaryPeak = [false(1, numTrials); trials.musicBoundaryPeak.'; ...
    trials.musicBoundaryPeak.'];
boundaryPeak = boundaryPeak(:);

details = table(method, snrDb, angleErrorDeg, rangeErrorM, ...
    angleErrorSquared, rangeErrorSquared, captured, boundaryPeak);
summary = groupsummary(details, ["method", "snrDb"], "mean", ...
    ["angleErrorSquared", "rangeErrorSquared", "captured", ...
    "boundaryPeak"]);
summary.angleRmseDeg = sqrt(summary.mean_angleErrorSquared);
summary.rangeRmseM = sqrt(summary.mean_rangeErrorSquared);
end
