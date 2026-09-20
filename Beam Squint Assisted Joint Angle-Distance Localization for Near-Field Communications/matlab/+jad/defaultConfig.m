function cfg = defaultConfig()
%DEFAULTCONFIG Parameters stated in Table II and documented assumptions.

cfg.c = 299792458;
cfg.fc = 60e9;
cfg.bandwidth = 3e9;
cfg.numSubcarriers = 2048;
cfg.numAntennas = 256;
cfg.elementSpacing = cfg.c / cfg.fc / 2;
cfg.subarraySize = 128;
cfg.thetaLimitsDeg = [-60, 60];
cfg.rangeLimitsM = [15, 50];

% Fusion count and grid sizes are reproduction implementation choices.
cfg.numFusionCarriers = 5;
% Zhang p. 8 explicitly gives these two local half-widths.
cfg.localHalfWidthDeg = 1;
cfg.localHalfWidthM = 1;
cfg.gridSizes = [41, 31, 21];
cfg.numMonteCarlo = 12;
cfg.snrDb = -10:5:20;
cfg.randomSeed = 20260901;

cfg.elementIndex = (0:cfg.numAntennas - 1).' - (cfg.numAntennas - 1) / 2;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
end
