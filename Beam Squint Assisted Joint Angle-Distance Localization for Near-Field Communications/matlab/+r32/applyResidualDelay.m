function [observation, snapshots, phase] = applyResidualDelay( ...
    cfg, observation, snapshots, delaySeconds)
%APPLYRESIDUALDELAY Apply one common baseband linear phase to z and Y.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    snapshots (:, :) double
    delaySeconds (1, 1) double {mustBeFinite}
end

carrierIndex = (0:cfg.numSubcarriers-1).';
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
phase = exp(-1i*2*pi*(frequencyHz-cfg.fc)*delaySeconds);
observation = observation.*phase;
snapshots = snapshots.*phase.';
end
