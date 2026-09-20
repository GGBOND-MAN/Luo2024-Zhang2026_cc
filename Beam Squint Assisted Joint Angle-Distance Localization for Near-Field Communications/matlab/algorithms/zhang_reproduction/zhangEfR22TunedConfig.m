function algorithm = zhangEfR22TunedConfig
%ZHANGEFR22TUNEDCONFIG Round 22 calibration-selected Zhang-style candidate.

algorithm.version = "Zhang-EF-R22-tuned";
algorithm.fusionCarrierCount = 385;
algorithm.subarraySize = 96;
algorithm.localHalfWidthDeg = 0.02;
algorithm.localHalfWidthM = 0.02;
algorithm.gridSizes = [49, 35, 25];
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
end
