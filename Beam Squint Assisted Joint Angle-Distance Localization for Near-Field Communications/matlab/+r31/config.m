function protocol = config()
%CONFIG Frozen Round31 correctness-repair and angle-control protocol.

protocol.version = "R31-correctness-angle-control-v2";
protocol.scalarSearchVersion = "R31-retained-candidate-scalar-search-v1";
protocol.scoreTolerance = 1e-10;
protocol.angleToleranceDeg = 1e-7;
protocol.profileToleranceM = 1e-6;
protocol.profileHalfWidthM = 2;
protocol.controlGridSizes = [41, 31, 21];
protocol.maxSelectedDeployments = 2;
protocol.dataRole = "existing-Round30-60-user-development-only";

protocol.acceptance.angleRmseRatio = 1.10;
protocol.acceptance.rangeRmseRatio = 1.10;
protocol.acceptance.positionRmseRatio = 1.10;
protocol.acceptance.p95Ratio = 1.15;
protocol.acceptance.missRateIncrease = 0.01;
protocol.acceptance.maxFullEquivalentResponses = 12000;
end
