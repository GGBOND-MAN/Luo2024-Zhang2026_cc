function algorithm = fsjadCompressedConfig
%FSJADCOMPRESSEDCONFIG Candidate compressed algorithm configuration.

algorithm.version = "FSJAD-Compressed-R21-locked";
algorithm.fusionCarrierCount = 513;
algorithm.gridSizes = [37, 27, 19];
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
algorithm.profileHalfWidthM = 1;
algorithm.profileSpacingM = 0.15;
algorithm.profileLambda = 0.9;
end
