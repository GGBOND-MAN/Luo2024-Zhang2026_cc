function result = localMusicEstimate(cfg, snapshots, carrierIndex, coarseThetaDeg, coarseRangeM, options)
%LOCALMUSICESTIMATE Geometry-compensated local MUSIC in (30)-(45).

arguments
    cfg (1, 1) struct
    snapshots (:, :) double
    carrierIndex (:, 1) double
    coarseThetaDeg (1, 1) double
    coarseRangeM (1, 1) double {mustBePositive}
    options.ConstrainToInitialWindow (1,1) logical = false
end

if size(snapshots, 1) ~= cfg.numAntennas
    error("jad:InvalidSnapshotSize", ...
        "Snapshots must have cfg.numAntennas rows.");
end
if size(snapshots, 2) ~= numel(carrierIndex)
    error("jad:InvalidCarrierCount", ...
        "One carrier index is required per snapshot column.");
end

[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
signalVectors = geometryCompensatedSignalVectors( ...
    cfg, snapshots, frequencyHz, coarseThetaDeg, coarseRangeM);

thetaCenter = coarseThetaDeg;
rangeCenter = coarseRangeM;
thetaHalfWidth = cfg.localHalfWidthDeg;
rangeHalfWidth = cfg.localHalfWidthM;
initialThetaBounds=coarseThetaDeg+[-1,1]*thetaHalfWidth;
initialRangeBounds=coarseRangeM+[-1,1]*rangeHalfWidth;
stages=repmat(struct('thetaLower',0,'thetaUpper',0, ...
    'rangeLower',0,'rangeUpper',0,'thetaBoundary',false, ...
    'rangeBoundary',false),numel(cfg.gridSizes),1);

for level = 1:numel(cfg.gridSizes)
    gridSize = cfg.gridSizes(level);
    thetaGrid = linspace(thetaCenter - thetaHalfWidth, ...
        thetaCenter + thetaHalfWidth, gridSize);
    rangeGrid = linspace(rangeCenter - rangeHalfWidth, ...
        rangeCenter + rangeHalfWidth, gridSize);
    if options.ConstrainToInitialWindow
        thetaGrid=linspace(max(thetaGrid(1),initialThetaBounds(1)), ...
            min(thetaGrid(end),initialThetaBounds(2)),gridSize);
        rangeGrid=linspace(max(rangeGrid(1),initialRangeBounds(1)), ...
            min(rangeGrid(end),initialRangeBounds(2)),gridSize);
    end
    [spectrum, peakRow, peakColumn] = evaluateSpectrum( ...
        cfg, signalVectors, frequencyHz, thetaGrid, rangeGrid);
    if level == 1
        initialThetaGrid = thetaGrid;
        initialRangeGrid = rangeGrid;
        initialSpectrum = spectrum / max(spectrum, [], "all");
    end
    thetaCenter = thetaGrid(peakColumn);
    rangeCenter = rangeGrid(peakRow);
    stages(level).thetaLower=thetaGrid(1);
    stages(level).thetaUpper=thetaGrid(end);
    stages(level).rangeLower=rangeGrid(1);
    stages(level).rangeUpper=rangeGrid(end);
    stages(level).thetaBoundary=peakColumn==1 || peakColumn==gridSize;
    stages(level).rangeBoundary=peakRow==1 || peakRow==gridSize;

    thetaStep = thetaGrid(2) - thetaGrid(1);
    rangeStep = rangeGrid(2) - rangeGrid(1);
    thetaHalfWidth = 2 * thetaStep;
    rangeHalfWidth = 2 * rangeStep;
end

result.thetaDeg = thetaCenter;
result.rangeM = rangeCenter;
result.thetaGridDeg = thetaGrid;
result.rangeGridM = rangeGrid;
result.spectrum = spectrum / max(spectrum, [], "all");
result.initialThetaGridDeg = initialThetaGrid;
result.initialRangeGridM = initialRangeGrid;
result.initialSpectrum = initialSpectrum;
result.signalVectors = signalVectors;
result.stages=stages;
result.initialThetaBoundary=stages(1).thetaBoundary;
result.initialRangeBoundary=stages(1).rangeBoundary;
result.finalThetaBoundary=stages(end).thetaBoundary;
result.finalRangeBoundary=stages(end).rangeBoundary;
end

function signalVectors = geometryCompensatedSignalVectors( ...
    cfg, snapshots, frequencyHz, coarseThetaDeg, coarseRangeM)

numCarriers = numel(frequencyHz);
subarraySize = cfg.subarraySize;
numSubarrays = cfg.numSubarrays;
referenceStart = floor((numSubarrays + 1) / 2);
referenceIds = referenceStart:(referenceStart + subarraySize - 1);
referenceIndex = cfg.elementIndex(referenceIds);
referenceDistance = fresnelDistance( ...
    cfg, referenceIndex, coarseThetaDeg, coarseRangeM);
signalVectors = complex(zeros(subarraySize, numCarriers));

for k = 1:numCarriers
    aligned = complex(zeros(subarraySize, numSubarrays));
    waveNumber = 2 * pi * frequencyHz(k) / cfg.c;
    for p = 1:numSubarrays
        ids = p:(p + subarraySize - 1);
        currentIndex = cfg.elementIndex(ids);
        currentDistance = fresnelDistance( ...
            cfg, currentIndex, coarseThetaDeg, coarseRangeM);
        phase = exp(-1i * waveNumber * (referenceDistance - currentDistance));
        aligned(:, p) = phase .* snapshots(ids, k);
    end
    covariance = aligned * aligned' / numSubarrays;
    covariance = (covariance + covariance') / 2;
    [eigenvectors, eigenvalues] = eig(covariance, "vector");
    [~, order] = sort(real(eigenvalues), "descend");
    signalVectors(:, k) = eigenvectors(:, order(1));
end
end

function [spectrum, peakRow, peakColumn] = evaluateSpectrum( ...
    cfg, signalVectors, frequencyHz, thetaGrid, rangeGrid)

[thetaMesh, rangeMesh] = meshgrid(thetaGrid, rangeGrid);
thetaVector = thetaMesh(:).';
rangeVector = rangeMesh(:).';
numPoints = numel(thetaVector);
numSubarrays = cfg.numSubarrays;
referenceStart = floor((numSubarrays + 1) / 2);
ids = referenceStart:(referenceStart + cfg.subarraySize - 1);
x = cfg.elementIndex(ids) * cfg.elementSpacing;
logSpectrum = zeros(1, numPoints);

for k = 1:numel(frequencyHz)
    thetaRad = deg2rad(thetaVector);
    distance = rangeVector - x * sin(thetaRad) ...
        + x.^2 * (cos(thetaRad).^2 ./ (2 * rangeVector));
    steering = exp(-1i * 2 * pi * frequencyHz(k) / cfg.c .* distance);
    steering = steering / sqrt(cfg.subarraySize);
    denominator = 1 - abs(signalVectors(:, k)' * steering).^2;
    denominator = max(real(denominator), eps);
    logSpectrum = logSpectrum - log(denominator);
end

spectrum = reshape(exp(logSpectrum / numel(frequencyHz)), size(thetaMesh));
[~, peakLinear] = max(spectrum, [], "all", "linear");
[peakRow, peakColumn] = ind2sub(size(spectrum), peakLinear);
end

function distanceM = fresnelDistance(cfg, elementIndex, thetaDeg, rangeM)
thetaRad = deg2rad(thetaDeg);
x = elementIndex * cfg.elementSpacing;
distanceM = rangeM - x * sin(thetaRad) ...
    + x.^2 * cos(thetaRad)^2 / (2 * rangeM);
end
