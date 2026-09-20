function result = fullSpectrumMusicEstimate( ...
    cfg, scalarObservation, snapshots, carrierIndex, scan)
%FULLSPECTRUMMUSICESTIMATE Full-spectrum coarse stage followed by local MUSIC.

arguments
    cfg (1, 1) struct
    scalarObservation (:, 1) double
    snapshots (:, :) double
    carrierIndex (:, 1) double
    scan (1, 1) struct = fsjad.prepareScan(cfg)
end

refinedEstimate = fsjad.peakInitializedProfileEstimate( ...
    cfg, scalarObservation, scan);
musicEstimate = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
    refinedEstimate.thetaDeg, refinedEstimate.rangeM);

result.thetaDeg = musicEstimate.thetaDeg;
result.rangeM = musicEstimate.rangeM;
result.refinedCoarse = refinedEstimate;
result.music = musicEstimate;
end
