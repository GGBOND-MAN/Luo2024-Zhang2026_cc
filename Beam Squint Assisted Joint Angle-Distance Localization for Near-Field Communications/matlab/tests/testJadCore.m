function tests = testJadCore
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectDir = fileparts(fileparts(mfilename("fullpath")));
addpath(projectDir);
testCase.TestData.projectDir = projectDir;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.projectDir);
end

function testTrajectoryEndpointsAndMonotonicAngle(testCase)
cfg = jad.defaultConfig();
[thetaDeg, rangeM] = jad.trajectory(cfg, [0; cfg.numSubcarriers]);
verifyEqual(testCase, thetaDeg, cfg.thetaLimitsDeg.', "AbsTol", 1e-10);
verifyEqual(testCase, rangeM, cfg.rangeLimitsM.', "AbsTol", 1e-10);

thetaAll = jad.trajectory(cfg);
verifyGreaterThan(testCase, diff(thetaAll), zeros(cfg.numSubcarriers - 1, 1));
end

function testSteeringVectorHasUnitNorm(testCase)
cfg = jad.defaultConfig();
a = jad.steeringVector(cfg, 12.5, 30, cfg.fc);
verifyEqual(testCase, norm(a), 1, "AbsTol", 1e-12);
end

function testGeometryCompensatedMusicNoiseless(testCase)
cfg = jad.defaultConfig();
cfg.numAntennas = 64;
cfg.subarraySize = 32;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.elementIndex = (0:cfg.numAntennas - 1).' - (cfg.numAntennas - 1) / 2;
cfg.gridSizes = [31, 21, 21];
cfg.numFusionCarriers = 3;

truth = [15, 30];
carrierIndex = (1023:1025).';
snapshots = jad.simulateSnapshots(cfg, truth(1), truth(2), 100, carrierIndex);
estimate = jad.localMusicEstimate(cfg, snapshots, carrierIndex, 15.25, 30.25);
verifyLessThan(testCase, abs(estimate.thetaDeg - truth(1)), 0.01);
verifyLessThan(testCase, abs(estimate.rangeM - truth(2)), 0.02);
end

function testCrlbDecreasesWithSnr(testCase)
cfg = jad.defaultConfig();
[angleRmse, rangeRmse] = jad.paperCrlb(cfg, 15, 30, [-10, 0, 10]);
verifyLessThan(testCase, diff(angleRmse), zeros(1, 2));
verifyLessThan(testCase, diff(rangeRmse), zeros(1, 2));
verifyGreaterThan(testCase, angleRmse, zeros(1, 3));
verifyGreaterThan(testCase, rangeRmse, zeros(1, 3));
end

function testProjectedCrlbIsFiniteAndDecreases(testCase)
cfg = jad.defaultConfig();
[angleRmse, rangeRmse] = jad.projectedCrlb(cfg, 15, 30, [-10, 0, 10]);
verifyTrue(testCase, all(isfinite(angleRmse)));
verifyTrue(testCase, all(isfinite(rangeRmse)));
verifyLessThan(testCase, diff(angleRmse), zeros(1, 2));
verifyLessThan(testCase, diff(rangeRmse), zeros(1, 2));
end

function testTtdBeamformerDimensionsAndConstantModulus(testCase)
cfg = reducedBaselineConfig();
weights = jad.ttdBeamformer(cfg, -60, 15, 60, 50);
verifySize(testCase, weights, [cfg.numAntennas, cfg.numSubcarriers]);
verifyEqual(testCase, abs(weights), ...
    ones(size(weights)) / sqrt(cfg.numAntennas), "AbsTol", 1e-12);
end

function testCbsLowEstimateIsFiniteAndBounded(testCase)
cfg = reducedBaselineConfig();
stream = RandStream("mt19937ar", "Seed", 41);
estimate = jad.cbsLowEstimate(cfg, 15, 30, 20, stream);
verifyTrue(testCase, isfinite(estimate.thetaDeg));
verifyTrue(testCase, isfinite(estimate.rangeM));
verifyGreaterThanOrEqual(testCase, estimate.thetaDeg, cfg.thetaLimitsDeg(1));
verifyLessThanOrEqual(testCase, estimate.thetaDeg, cfg.thetaLimitsDeg(2));
verifyGreaterThanOrEqual(testCase, estimate.rangeM, cfg.rangeLimitsM(1));
verifyLessThanOrEqual(testCase, estimate.rangeM, cfg.rangeLimitsM(2));
end

function testDftCodebookEstimateIsFiniteAndBounded(testCase)
cfg = reducedBaselineConfig();
stream = RandStream("mt19937ar", "Seed", 42);
estimate = jad.dftCodebookEstimate(cfg, 15, 30, 20, stream);
verifyTrue(testCase, isfinite(estimate.thetaDeg));
verifyTrue(testCase, isfinite(estimate.rangeM));
verifyGreaterThanOrEqual(testCase, estimate.thetaDeg, cfg.thetaLimitsDeg(1));
verifyLessThanOrEqual(testCase, estimate.thetaDeg, cfg.thetaLimitsDeg(2));
verifyGreaterThanOrEqual(testCase, estimate.rangeM, cfg.rangeLimitsM(1));
verifyLessThanOrEqual(testCase, estimate.rangeM, cfg.rangeLimitsM(2));
end

function cfg = reducedBaselineConfig()
cfg = jad.defaultConfig();
cfg.numAntennas = 64;
cfg.numSubcarriers = 128;
cfg.subarraySize = 32;
cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
cfg.elementIndex = (0:cfg.numAntennas - 1).' - (cfg.numAntennas - 1) / 2;
end
