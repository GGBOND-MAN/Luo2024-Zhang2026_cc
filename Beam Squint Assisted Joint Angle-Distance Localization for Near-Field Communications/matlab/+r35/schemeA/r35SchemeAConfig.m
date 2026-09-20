function protocol = r35SchemeAConfig()
%R35SCHEMEACONFIG Freeze bounded continuous MUSIC-angle refinement.

protocol.version = "R35-schemeA-continuous-MUSIC-angle-v1";
protocol.commonVersion = "R35-angle-improvement-common-protocol-v1";
protocol.optimizer = "fminbnd";
protocol.tolXDeg = 1e-10;
protocol.maximumFunctionEvaluations = 100;
protocol.maximumIterations = 100;
protocol.scoreTolerance = 1e-12;
protocol.bracketRule = "final-grid-left-and-right-neighbors";
protocol.endpointPolicy = "retain-grid-without-refinement";
protocol.gridCandidateAlwaysRetained = true;
protocol.developmentUserCount = 60;
protocol.snrDb = [-10, 0, 20];
protocol.runtimeStatistic = "mean-complete-independent-online-runtime";
protocol.calibrationAuthorized = false;
end
