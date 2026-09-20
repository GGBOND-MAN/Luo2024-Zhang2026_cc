function diagnostics = localSpectrumDiagnostics( ...
    spectrum, thetaGridDeg, rangeGridM, evaluationRow, evaluationColumn)
%LOCALSPECTRUMDIAGNOSTICS Measure boundary and angle-range curvature.

arguments
    spectrum (:, :) double {mustBeFinite, mustBeNonnegative}
    thetaGridDeg (1, :) double {mustBeFinite}
    rangeGridM (1, :) double {mustBeFinite, mustBePositive}
    evaluationRow (1, 1) double = NaN
    evaluationColumn (1, 1) double = NaN
end

if ~isequal(size(spectrum), ...
        [numel(rangeGridM), numel(thetaGridDeg)])
    error("jad:SpectrumGridSizeMismatch", ...
        "Spectrum dimensions must match the range and angle grids.");
end
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
if isnan(evaluationRow)
    evaluationRow = peakRow;
end
if isnan(evaluationColumn)
    evaluationColumn = peakColumn;
end
if evaluationRow < 1 || evaluationRow > size(spectrum, 1) ...
        || evaluationColumn < 1 ...
        || evaluationColumn > size(spectrum, 2) ...
        || evaluationRow ~= floor(evaluationRow) ...
        || evaluationColumn ~= floor(evaluationColumn)
    error("jad:InvalidSpectrumEvaluationIndex", ...
        "Evaluation indices must identify an existing grid point.");
end

diagnostics.peakRow = peakRow;
diagnostics.peakColumn = peakColumn;
diagnostics.peakThetaDeg = thetaGridDeg(peakColumn);
diagnostics.peakRangeM = rangeGridM(peakRow);
diagnostics.thetaBoundary = peakColumn == 1 ...
    || peakColumn == size(spectrum, 2);
diagnostics.rangeBoundary = peakRow == 1 ...
    || peakRow == size(spectrum, 1);
diagnostics.evaluationRow = evaluationRow;
diagnostics.evaluationColumn = evaluationColumn;
diagnostics.evaluationThetaDeg = thetaGridDeg(evaluationColumn);
diagnostics.evaluationRangeM = rangeGridM(evaluationRow);
diagnostics.hessian = nan(2);
diagnostics.curvatureCoupling = NaN;
diagnostics.ridgeSlopeMPerDeg = NaN;
diagnostics.locallyConcave = false;

isInterior = evaluationRow > 1 ...
    && evaluationRow < size(spectrum, 1) ...
    && evaluationColumn > 1 ...
    && evaluationColumn < size(spectrum, 2);
if ~isInterior
    return;
end

logSpectrum = log(max(spectrum, realmin));
thetaStep = thetaGridDeg(evaluationColumn + 1) ...
    - thetaGridDeg(evaluationColumn);
rangeStep = rangeGridM(evaluationRow + 1) ...
    - rangeGridM(evaluationRow);
row = evaluationRow;
column = evaluationColumn;
hThetaTheta = (logSpectrum(row, column + 1) ...
    - 2 * logSpectrum(row, column) ...
    + logSpectrum(row, column - 1)) / thetaStep^2;
hRangeRange = (logSpectrum(row + 1, column) ...
    - 2 * logSpectrum(row, column) ...
    + logSpectrum(row - 1, column)) / rangeStep^2;
hThetaRange = (logSpectrum(row + 1, column + 1) ...
    - logSpectrum(row + 1, column - 1) ...
    - logSpectrum(row - 1, column + 1) ...
    + logSpectrum(row - 1, column - 1)) ...
    / (4 * thetaStep * rangeStep);
hessian = [hThetaTheta, hThetaRange; ...
    hThetaRange, hRangeRange];
denominator = sqrt(abs(hThetaTheta * hRangeRange));
if denominator > 0
    diagnostics.curvatureCoupling = abs(hThetaRange) / denominator;
end
if hRangeRange ~= 0
    diagnostics.ridgeSlopeMPerDeg = -hThetaRange / hRangeRange;
end
diagnostics.hessian = hessian;
diagnostics.locallyConcave = all(eig((hessian + hessian.') / 2) < 0);
end
