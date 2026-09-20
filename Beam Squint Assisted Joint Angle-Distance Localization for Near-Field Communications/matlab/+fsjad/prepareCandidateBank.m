function bank = prepareCandidateBank(cfg, thetaGridDeg, rangeGridM, scan)
%PREPARECANDIDATEBANK Precompute full-spectrum responses on a 2-D grid.

arguments
    cfg (1, 1) struct
    thetaGridDeg (:, 1) double
    rangeGridM (:, 1) double {mustBePositive}
    scan (1, 1) struct = fsjad.prepareScan(cfg)
end

[thetaMeshDeg, rangeMeshM] = meshgrid(thetaGridDeg, rangeGridM);
bank.thetaDeg = thetaMeshDeg(:);
bank.rangeM = rangeMeshM(:);
numCandidates = numel(bank.thetaDeg);
bank.response = complex(zeros(cfg.numSubcarriers, numCandidates));
for candidateIndex = 1:numCandidates
    bank.response(:, candidateIndex) = fsjad.exactSpectralResponse( ...
        cfg, deg2rad(bank.thetaDeg(candidateIndex)), ...
        bank.rangeM(candidateIndex), scan);
end
bank.energy = real(sum(abs(bank.response).^2, 1)).';
end
