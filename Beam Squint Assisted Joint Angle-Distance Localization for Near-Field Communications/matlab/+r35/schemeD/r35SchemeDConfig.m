function protocol = r35SchemeDConfig()
%R35SCHEMEDCONFIG Freeze parameter-free all-carrier MUSIC weighting.

protocol.version = "R35-schemeD-weighted-all-carrier-MUSIC-v1";
protocol.commonVersion = "R35-angle-improvement-common-protocol-v1";
protocol.methods = ["D0_uniform", "D1_gap", "D2_information", "D3_mix"];
protocol.gridSizes = [41, 31, 21];
protocol.reference = "frozen-L06-front-theta-and-range";
protocol.gapEpsilon = eps;
protocol.mixRule = "sqrt-rho-gap-times-rho-information";
protocol.derivativeUnit = "per-radian";
protocol.d0ScoreTolerance = 1e-10;
protocol.d0ThetaToleranceDeg = 1e-12;
protocol.weightSumTolerance = 1e-12;
protocol.edgeFractionPerSide = 0.10;
protocol.centerFraction = 0.20;
protocol.developmentUserCount = 60;
protocol.snrDb = [-10, 0, 20];
protocol.calibrationAuthorized = false;
end
