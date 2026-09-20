function algorithm = fsjadRound23ComparisonConfig
%FSJADROUND23COMPARISONCONFIG Freeze the effective Round 23 FSJAD settings.

algorithm.version = "FSJAD-Compressed-R23-comparison-locked";
algorithm.fusionCarrierCount = 513;
algorithm.subarraySize = 96;
algorithm.localHalfWidthDeg = 0.02;
algorithm.localHalfWidthM = 0.02;
algorithm.gridSizes = [37, 27, 19];
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
algorithm.profileHalfWidthM = 1;
algorithm.profileSpacingM = 0.15;
algorithm.profileLambda = 0.9;
end
