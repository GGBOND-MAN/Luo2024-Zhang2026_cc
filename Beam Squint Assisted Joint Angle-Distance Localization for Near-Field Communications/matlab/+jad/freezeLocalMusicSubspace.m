function state = freezeLocalMusicSubspace( ...
    cfg, snapshots, carrierIndex, coarseThetaDeg, coarseRangeM)
%FREEZELOCALMUSICSUBSPACE Build one geometry-compensated MUSIC subspace.

arguments
    cfg (1, 1) struct
    snapshots (:, :) double
    carrierIndex (:, 1) double {mustBeInteger, mustBeNonnegative}
    coarseThetaDeg (1, 1) double {mustBeFinite}
    coarseRangeM (1, 1) double {mustBeFinite, mustBePositive}
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
subarraySize = cfg.subarraySize;
numSubarrays = cfg.numSubarrays;
referenceStart = floor((numSubarrays + 1) / 2);
referenceIds = referenceStart:(referenceStart + subarraySize - 1);
referenceIndex = cfg.elementIndex(referenceIds);
referenceDistance = fresnelDistance( ...
    cfg, referenceIndex, coarseThetaDeg, coarseRangeM);
signalVectors = complex(zeros(subarraySize, numel(frequencyHz)));

for carrier = 1:numel(frequencyHz)
    aligned = complex(zeros(subarraySize, numSubarrays));
    waveNumber = 2*pi*frequencyHz(carrier)/cfg.c;
    for subarray = 1:numSubarrays
        ids = subarray:(subarray + subarraySize - 1);
        currentIndex = cfg.elementIndex(ids);
        currentDistance = fresnelDistance( ...
            cfg, currentIndex, coarseThetaDeg, coarseRangeM);
        phase = exp(-1i*waveNumber*(referenceDistance - currentDistance));
        aligned(:, subarray) = phase.*snapshots(ids, carrier);
    end
    covariance = aligned*aligned'/numSubarrays;
    covariance = (covariance + covariance')/2;
    [eigenvectors, eigenvalues] = eig(covariance, "vector");
    [~, order] = sort(real(eigenvalues), "descend");
    signalVectors(:, carrier) = eigenvectors(:, order(1));
end

state.version = "Frozen-Local-MUSIC-Subspace-v1";
state.signalVectors = signalVectors;
state.carrierIndex = carrierIndex;
state.frequencyHz = frequencyHz;
state.referenceStart = referenceStart;
state.referenceIds = referenceIds;
state.referenceElementIndex = referenceIndex;
state.referencePositionM = referenceIndex*cfg.elementSpacing;
state.coarseThetaDeg = coarseThetaDeg;
state.coarseRangeM = coarseRangeM;
state.subarraySize = subarraySize;
state.numSubarrays = numSubarrays;
end

function distanceM = fresnelDistance(cfg, elementIndex, thetaDeg, rangeM)
thetaRad = deg2rad(thetaDeg);
x = elementIndex*cfg.elementSpacing;
distanceM = rangeM - x*sin(thetaRad) ...
    + x.^2*cos(thetaRad)^2/(2*rangeM);
end
