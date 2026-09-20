function protocol = r36SchemeEConfig()
%R36SCHEMEECONFIG Freeze the range-orthogonal one-step estimator.

protocol.version = "R36-schemeE-range-orthogonal-one-step-v1";
protocol.commonVersion = "R36-range-orthogonal-angle-protocol-v1";
protocol.evaluationPoint = "P_A-theta-and-P_A-profile-range";
protocol.objective = "uniform-all-carrier-subspace-residual-least-squares";
protocol.derivatives = "analytic-first-order-residual-Jacobian";
protocol.angleUnit = "radian";
protocol.rangeUnit = "meter";
protocol.nuisanceElimination = "Gauss-Newton-Schur-complement";
protocol.updateCount = 1;
protocol.optimizer = "none";
protocol.bracketRule = "actual-final-grid-two-sided-neighbors";
protocol.invalidInformationPolicy = "retain-P_A";
protocol.endpointPolicy = "retain-P_A";
protocol.candidateSelection = "valid-clipped-one-step-otherwise-P_A";
protocol.scoreUsedForSelection = false;
protocol.informationScaleTolerance = 100*eps;
protocol.thetaToleranceDeg = 1e-12;
protocol.developmentUserCount = 60;
protocol.snrDb = [-10, 0, 20];
protocol.calibrationAuthorized = false;
end
