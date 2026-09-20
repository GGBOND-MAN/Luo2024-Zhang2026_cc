function output = injectDelay(cfg, observation, snapshots, tauSeconds, mode)
%INJECTDELAY Apply a common timing offset to the stress-branch observations.
%   A timing offset multiplies every carrier by exp(-j 2 pi f_m tau). In
%   "array" mode only the array block carries it, which is the mechanism
%   test: the free per-carrier gain of P_FALF absorbs it exactly and P_A
%   never sees it, so both must be invariant. In "common" mode the scalar
%   block carries it too, which is the physical case.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    snapshots (:, :) double
    tauSeconds (1, 1) double {mustBeFinite}
    mode (1, 1) string {mustBeMember(mode, ["array", "common"])}
end

[~, ~, frequencyHz] = jad.trajectory(cfg, (0:cfg.numSubcarriers-1).');
phase = exp(-1i*2*pi*tauSeconds*frequencyHz(:));
output = struct(version="R57-delay-injection-v1", ...
    tauSeconds=tauSeconds, mode=mode, ...
    observation=observation, snapshots=snapshots);
output.snapshots = snapshots.*phase.';
if mode == "common"
    output.observation = observation.*phase;
end
end
