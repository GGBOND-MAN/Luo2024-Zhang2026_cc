function scan = prepareScan(cfg)
%PREPARESCAN Precompute quantities shared by all candidate locations.

arguments
    cfg (1, 1) struct
end

carrierIndex = (0:cfg.numSubcarriers - 1).';
[focusThetaDeg, focusRangeM, frequencyHz] = jad.trajectory(cfg, carrierIndex);
x = cfg.elementIndex * cfg.elementSpacing;
focusDistance = sqrt(focusRangeM.'.^2 + x.^2 ...
    - 2 * x * focusRangeM.' .* sind(focusThetaDeg.'));
wavenumber = 2 * pi * frequencyHz / cfg.c;

scan.x = x;
scan.wavenumber = wavenumber;
scan.beamformer = exp(-1i * focusDistance .* wavenumber.') ...
    / sqrt(cfg.numAntennas);
scan.focusThetaDeg = focusThetaDeg;
scan.focusRangeM = focusRangeM;
end
