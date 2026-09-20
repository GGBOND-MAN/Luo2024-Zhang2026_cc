function protocol = r38SchemeFConfig()
%R38SCHEMEFCONFIG Freeze conditional raw-array variable-projection ML.

protocol.version = "R38-schemeF-raw-array-conditional-vpml-v1";
protocol.commonVersion = r38CommonProtocol().version;
protocol.dataDomain = "full-N-raw-array-snapshots";
protocol.carrierRule = "exact-frozen-P_A-K-carrier-set";
protocol.model = "y_m=alpha_m*a_m(theta,r_P)+equal-variance-noise";
protocol.gainModel = "independent-complex-alpha-per-carrier";
protocol.gainElimination = "analytic-variable-projection";
protocol.objective = "globally-normalized-total-explained-energy";
protocol.rangeDuringAngle = "fixed-P_A-profile-range";
protocol.steeringModel = "frozen-Fresnel-full-array";
protocol.bracket = "actual-final-P_A-grid-immediate-neighbors";
protocol.optimizer = "fminbnd-bounded-one-dimensional";
protocol.tolXDeg = 1e-10;
protocol.scoreScaleTolerance = 100*eps;
protocol.fixedCandidateRule = "left-P_A-right";
protocol.candidateRetention = "best-evaluated-score";
protocol.endpointPolicy = "retain-best-legal-fixed-candidate";
protocol.newAngleRangeRule = "rerun-frozen-q-only-profile";
protocol.thetaIdentityToleranceDeg = 1e-12;
protocol.developmentUsers = 60;
protocol.calibrationAuthorized = false;
protocol.finalAuthorized = false;
end
