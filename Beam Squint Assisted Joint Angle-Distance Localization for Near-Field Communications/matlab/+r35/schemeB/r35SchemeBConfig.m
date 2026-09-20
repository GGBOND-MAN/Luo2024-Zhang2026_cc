function protocol = r35SchemeBConfig()
%R35SCHEMEB_CONFIG Freeze conditional full-spectrum angle refinement.

protocol.version = "R35-schemeB-spectral-angle-v1";
protocol.commonVersion = "R35-angle-improvement-common-protocol-v1";
protocol.objective = "R33-q-only-normalized-concentrated-log-score";
protocol.response = "exact-spherical-full-spectrum";
protocol.fixedPrimaryRange = "P_A-profile-range-r_P";
protocol.optimizer = "fminbnd";
protocol.tolXDeg = 1e-10;
protocol.maximumFunctionEvaluations = 100;
protocol.maximumIterations = 100;
protocol.scoreTolerance = 1e-12;
protocol.bracketRule = "final-MUSIC-grid-neighbors";
protocol.feasibleBoundaryPolicy = "actual-one-sided-grid-interval";
protocol.gridCandidateAlwaysRetained = true;
protocol.developmentUserCount = 60;
protocol.snrDb = [-10, 0, 20];
protocol.aComparisonSource = "saved-SchemeA-per-user-CSV-read-only";
protocol.aComparisonSha256 = ...
    "1f1f950e96e8d61ebe7083c0fd1b49fe0c25763951c48327084341522f16e8ff";
protocol.rangeRefreshRequiresAllPrimaryAngleGates = true;
protocol.calibrationAuthorized = false;
end
