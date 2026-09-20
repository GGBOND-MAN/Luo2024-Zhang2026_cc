function [state, musicCfg, cost] = prepareMusicState( ...
    cfg, snapshots, carrierIndex, thetaDeg, rangeM, subarraySize, ...
    gramProtocol, options)
%PREPAREMUSICSTATE Reuse geometry and optionally use the smaller Gram EVD.

arguments
    cfg (1, 1) struct
    snapshots (:, :) double
    carrierIndex (:, 1) double {mustBeInteger, mustBeNonnegative}
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    subarraySize (1, 1) double {mustBeInteger, mustBePositive}
    gramProtocol (1, 1) struct = r33.config().gram
    options.UseGram (1, 1) logical = true
end

if size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= numel(carrierIndex)
    error("r33:MusicSnapshotSize", ...
        "Snapshots must match the antenna and carrier dimensions.");
end
if subarraySize > cfg.numAntennas
    error("r33:MusicSubarraySize", ...
        "The subarray cannot exceed the physical array.");
end

totalTimer = tic;
geometryTimer = tic;
musicCfg = cfg;
musicCfg.subarraySize = subarraySize;
musicCfg.numSubarrays = cfg.numAntennas-subarraySize+1;
[~, ~, frequencyHz] = jad.trajectory(musicCfg, carrierIndex);
referenceStart = floor((musicCfg.numSubarrays+1)/2);
referenceIds = referenceStart:referenceStart+subarraySize-1;
referenceIndex = cfg.elementIndex(referenceIds);
referenceDistance = fresnelDistance( ...
    cfg, referenceIndex, thetaDeg, rangeM);
windowIds = (1:subarraySize).'+(0:musicCfg.numSubarrays-1);
windowIndex = cfg.elementIndex(windowIds);
windowDistance = fresnelDistance(cfg, windowIndex, thetaDeg, rangeM);
distanceDifference = referenceDistance-windowDistance;
geometrySeconds = toc(geometryTimer);
signalVectors = complex(zeros(subarraySize, numel(carrierIndex)));
method = strings(numel(carrierIndex), 1);
fallback = false(numel(carrierIndex), 1);
fallbackReason = strings(numel(carrierIndex), 1);
maximumEigenvalue = zeros(numel(carrierIndex), 1);
relativeEigengap = zeros(numel(carrierIndex), 1);
relativeResidual = zeros(numel(carrierIndex), 1);
matrixFormationMacs = zeros(numel(carrierIndex), 1);
evdCubicUnits = zeros(numel(carrierIndex), 1);
recoveryMacs = zeros(numel(carrierIndex), 1);
alignmentSeconds = 0;
subspaceSeconds = 0;

for carrier = 1:numel(carrierIndex)
    timer = tic;
    waveNumber = 2*pi*frequencyHz(carrier)/cfg.c;
    phase = exp(-1i*waveNumber*distanceDifference);
    snapshotWindows = reshape(snapshots(windowIds(:), carrier), ...
        size(windowIds));
    aligned = phase.*snapshotWindows;
    alignmentSeconds = alignmentSeconds+toc(timer);
    timer = tic;
    [signalVectors(:, carrier), diagnostic] = r33.principalVector( ...
        aligned, gramProtocol, UseGram=options.UseGram);
    subspaceSeconds = subspaceSeconds+toc(timer);
    method(carrier) = diagnostic.method;
    fallback(carrier) = diagnostic.fallback;
    fallbackReason(carrier) = diagnostic.fallbackReason;
    maximumEigenvalue(carrier) = diagnostic.maximumEigenvalue;
    relativeEigengap(carrier) = diagnostic.relativeEigengap;
    relativeResidual(carrier) = diagnostic.relativeResidual;
    matrixFormationMacs(carrier) = diagnostic.matrixFormationMacs;
    evdCubicUnits(carrier) = diagnostic.evdCubicUnits;
    recoveryMacs(carrier) = diagnostic.recoveryMacs;
end

state = struct(version="R33-frozen-local-MUSIC-subspace-v1", ...
    signalVectors=signalVectors, carrierIndex=carrierIndex, ...
    frequencyHz=frequencyHz, referenceIds=referenceIds, ...
    referencePositionM=cfg.elementIndex(referenceIds)*cfg.elementSpacing, ...
    subarraySize=subarraySize, coarseThetaDeg=thetaDeg, ...
    coarseRangeM=rangeM);
complexBytes = 16;
realBytes = 8;
cost = struct(seconds=toc(totalTimer), ...
    geometrySeconds=geometrySeconds, alignmentSeconds=alignmentSeconds, ...
    subspaceSeconds=subspaceSeconds, carrierCount=numel(carrierIndex), ...
    subarraySize=subarraySize, numSubarrays=musicCfg.numSubarrays, ...
    phaseAlignmentTerms=numel(carrierIndex)*subarraySize ...
        *musicCfg.numSubarrays, ...
    matrixFormationMacs=sum(matrixFormationMacs), ...
    evdCubicUnits=sum(evdCubicUnits), recoveryMacs=sum(recoveryMacs), ...
    fallbackCount=nnz(fallback), gramSuccessCount=nnz( ...
        method == "smaller-gram-eig-recovery"), ...
    directCount=nnz(startsWith(method, "direct")), ...
    maximumRelativeResidual=max(relativeResidual), ...
    minimumRelativeEigengap=min(relativeEigengap), ...
    estimatedPersistentStateBytes=complexBytes*numel(signalVectors) ...
        + realBytes*(numel(carrierIndex)+numel(frequencyHz) ...
        + numel(referenceIds)), ...
    estimatedPeakWorkingBytes=complexBytes*(subarraySize ...
        *musicCfg.numSubarrays+max(subarraySize, musicCfg.numSubarrays)^2) ...
        + realBytes*(numel(distanceDifference)+numel(windowIds)));
cost.method = method;
cost.fallback = fallback;
cost.fallbackReason = fallbackReason;
cost.maximumEigenvalue = maximumEigenvalue;
cost.relativeEigengap = relativeEigengap;
cost.relativeResidual = relativeResidual;
end

function distanceM = fresnelDistance(cfg, elementIndex, thetaDeg, rangeM)
x = elementIndex*cfg.elementSpacing;
distanceM = rangeM-x*sind(thetaDeg) ...
    + x.^2*cosd(thetaDeg)^2/(2*rangeM);
end
