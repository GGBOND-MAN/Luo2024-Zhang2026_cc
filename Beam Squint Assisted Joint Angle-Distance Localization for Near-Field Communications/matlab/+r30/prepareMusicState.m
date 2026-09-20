function [state, musicCfg, cost] = prepareMusicState( ...
    cfg, snapshots, carrierIndex, thetaDeg, rangeM, subarraySize)
%PREPAREMUSICSTATE Build geometry-compensated rank-one signal vectors.

arguments
    cfg (1, 1) struct
    snapshots (:, :) double
    carrierIndex (:, 1) double {mustBeInteger, mustBeNonnegative}
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    subarraySize (1, 1) double {mustBeInteger, mustBePositive}
end

if size(snapshots, 1) ~= cfg.numAntennas ...
        || size(snapshots, 2) ~= numel(carrierIndex)
    error("r30:MusicSnapshotSize", ...
        "Snapshots must match the antenna and selected-carrier dimensions.");
end
if subarraySize > cfg.numAntennas
    error("r30:MusicSubarraySize", ...
        "The MUSIC subarray cannot exceed the physical array.");
end

timer = tic;
musicCfg = cfg;
musicCfg.subarraySize = subarraySize;
musicCfg.numSubarrays = cfg.numAntennas - subarraySize + 1;
[~, ~, frequencyHz] = jad.trajectory(musicCfg, carrierIndex);
referenceStart = floor((musicCfg.numSubarrays + 1)/2);
referenceIds = referenceStart:referenceStart+subarraySize-1;
referenceIndex = cfg.elementIndex(referenceIds);
referenceDistance = fresnelDistance( ...
    cfg, referenceIndex, thetaDeg, rangeM);
signalVectors = complex(zeros(subarraySize, numel(carrierIndex)));

for carrier = 1:numel(carrierIndex)
    aligned = complex(zeros(subarraySize, musicCfg.numSubarrays));
    waveNumber = 2*pi*frequencyHz(carrier)/cfg.c;
    for subarray = 1:musicCfg.numSubarrays
        ids = subarray:subarray+subarraySize-1;
        currentIndex = cfg.elementIndex(ids);
        currentDistance = fresnelDistance( ...
            cfg, currentIndex, thetaDeg, rangeM);
        phase = exp(-1i*waveNumber*(referenceDistance-currentDistance));
        aligned(:, subarray) = phase.*snapshots(ids, carrier);
    end
    covariance = aligned*aligned'/musicCfg.numSubarrays;
    covariance = (covariance + covariance')/2;
    [eigenvectors, eigenvalues] = eig(covariance, "vector");
    [~, order] = sort(real(eigenvalues), "descend");
    signalVectors(:, carrier) = eigenvectors(:, order(1));
end

state = struct(signalVectors=signalVectors, carrierIndex=carrierIndex, ...
    frequencyHz=frequencyHz, referenceIds=referenceIds, ...
    referencePositionM=cfg.elementIndex(referenceIds)*cfg.elementSpacing, ...
    subarraySize=subarraySize, coarseThetaDeg=thetaDeg, coarseRangeM=rangeM);
cost.seconds = toc(timer);
cost.carrierCount = numel(carrierIndex);
cost.subarraySize = subarraySize;
cost.numSubarrays = musicCfg.numSubarrays;
cost.phaseAlignmentTerms = numel(carrierIndex)*subarraySize*musicCfg.numSubarrays;
cost.covarianceMacs = numel(carrierIndex)*musicCfg.numSubarrays*subarraySize^2;
cost.evdCubicUnits = numel(carrierIndex)*subarraySize^3;
end

function distanceM = fresnelDistance(cfg, elementIndex, thetaDeg, rangeM)
x = elementIndex*cfg.elementSpacing;
distanceM = rangeM - x*sind(thetaDeg) ...
    + x.^2*cosd(thetaDeg)^2/(2*rangeM);
end
