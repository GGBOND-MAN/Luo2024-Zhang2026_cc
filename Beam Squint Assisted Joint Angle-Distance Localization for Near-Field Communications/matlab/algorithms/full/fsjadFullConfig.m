function algorithm = fsjadFullConfig
%FSJADFULLCONFIG Frozen full-complexity algorithm configuration.

algorithm.version = "FSJAD-Full-513-v1";
algorithm.fusionCarrierCount = 513;
algorithm.gridSizes = [61, 41, 31];
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
algorithm.profileHalfWidthM = 1;
algorithm.profileSpacingM = 0.1;
algorithm.profileLambda = 0.9;
end
