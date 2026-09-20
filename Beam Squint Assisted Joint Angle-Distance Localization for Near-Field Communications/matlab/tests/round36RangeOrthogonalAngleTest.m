classdef round36RangeOrthogonalAngleTest < matlab.unittest.TestCase
    %ROUND36RANGEORTHOGONALANGLETEST R36 derivative and protocol tests.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addR36Paths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r36", "common")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r36", "schemeE")));
        end
    end

    methods (Test)
        function frozenCommonIdentityPasses(testCase)
            report = r36AssertCommonProtocol( ...
                jad.defaultConfig(), r36CommonProtocol());

            testCase.verifyTrue(report.passed);
            testCase.verifyFalse(report.estimationExecuted);
            testCase.verifyEqual(report.evidenceRole, ...
                "existing-60-user-development-only");
        end

        function steeringDerivativesMatchFiniteDifference(testCase)
            cfg = jad.defaultConfig();
            state = geometryState(cfg, 31);
            theta = deg2rad(12.3);
            rangeM = 24.8;
            hTheta = 1e-6;
            hRange = 1e-7;
            analytic = r36SteeringDerivatives(cfg, state, theta, rangeM);
            thetaPlus = r36SteeringDerivatives( ...
                cfg, state, theta+hTheta, rangeM);
            thetaMinus = r36SteeringDerivatives( ...
                cfg, state, theta-hTheta, rangeM);
            rangePlus = r36SteeringDerivatives( ...
                cfg, state, theta, rangeM+hRange);
            rangeMinus = r36SteeringDerivatives( ...
                cfg, state, theta, rangeM-hRange);

            dTheta = (thetaPlus.a-thetaMinus.a)/(2*hTheta);
            dRange = (rangePlus.a-rangeMinus.a)/(2*hRange);
            ddTheta = (thetaPlus.a-2*analytic.a+thetaMinus.a)/hTheta^2;
            ddRange = (rangePlus.a-2*analytic.a+rangeMinus.a)/hRange^2;
            mixed = (r36SteeringDerivatives(cfg, state, ...
                theta+hTheta, rangeM+hRange).a ...
                -r36SteeringDerivatives(cfg, state, ...
                theta+hTheta, rangeM-hRange).a ...
                -r36SteeringDerivatives(cfg, state, ...
                theta-hTheta, rangeM+hRange).a ...
                +r36SteeringDerivatives(cfg, state, ...
                theta-hTheta, rangeM-hRange).a)/(4*hTheta*hRange);

            testCase.verifyLessThan(relativeError( ...
                analytic.aTheta, dTheta), 1e-5);
            testCase.verifyLessThan(relativeError( ...
                analytic.aRange, dRange), 1e-5);
            testCase.verifyLessThan(relativeError( ...
                analytic.aThetaTheta, ddTheta), 2e-3);
            testCase.verifyLessThan(relativeError( ...
                analytic.aRangeRange, ddRange), 2e-3);
            testCase.verifyLessThan(relativeError( ...
                analytic.aThetaRange, mixed), 2e-3);
        end

        function residualGradientMatchesFiniteDifference(testCase)
            rng(36);
            cfg = jad.defaultConfig();
            cfg.subarraySize = 24;
            state = randomState(cfg, 24, 17);
            theta = deg2rad(7.1);
            rangeM = 29.3;
            hTheta = 2e-6;
            hRange = 2e-5;
            analytic = r36SubspaceResidualGaussNewton( ...
                cfg, state, theta, rangeM);
            cost = @(t, r) r36SubspaceResidualGaussNewton( ...
                cfg, state, t, r).cost;
            numericGradient = [(cost(theta+hTheta, rangeM) ...
                -cost(theta-hTheta, rangeM))/(2*hTheta); ...
                (cost(theta, rangeM+hRange) ...
                -cost(theta, rangeM-hRange))/(2*hRange)];

            testCase.verifyLessThan(relativeError( ...
                analytic.gradient, numericGradient), 5e-5);
            testCase.verifyGreaterThan(eig(analytic.information), ...
                [-1e-10; -1e-10]);
        end

        function noiselessOneStepMovesTowardTruth(testCase)
            cfg = jad.defaultConfig();
            cfg.subarraySize = 64;
            state = geometryState(cfg, 61);
            state.subarraySize = cfg.subarraySize;
            ids = 20:83;
            state.referencePositionM = ...
                cfg.elementIndex(ids)*cfg.elementSpacing;
            truthTheta = 10.00008;
            truthRange = 27.5;
            truth = r36SteeringDerivatives( ...
                cfg, state, deg2rad(truthTheta), truthRange);
            state.signalVectors = truth.a;
            baseTheta = 10;
            grid = baseTheta+(-10:10)*0.000266666666666667;

            result = r36RangeOrthogonalOneStep( ...
                cfg, state, grid, 11, truthRange);

            testCase.verifyTrue(result.validUpdate);
            testCase.verifyLessThan(abs(result.thetaDeg-truthTheta), ...
                abs(baseTheta-truthTheta));
            testCase.verifyGreaterThanOrEqual(result.thetaDeg, grid(10));
            testCase.verifyLessThanOrEqual(result.thetaDeg, grid(12));
        end

        function schemeEContainsNoOptimizerOrR35Calls(testCase)
            folder = fullfile(testCase.MatlabRoot, "+r36", "schemeE");
            files = dir(fullfile(folder, "*.m"));
            source = "";
            for index = 1:numel(files)
                source = source+newline+string(fileread( ...
                    fullfile(files(index).folder, files(index).name)));
            end
            testCase.verifyFalse(contains(lower(source), "fminbnd"));
            testCase.verifyFalse(contains(lower(source), "schemea"));
            testCase.verifyFalse(contains(lower(source), "schemeb"));
            testCase.verifyFalse(contains(lower(source), "schemed"));
        end

        function syntheticSummaryAndFiguresComplete(testCase)
            [design, results] = syntheticSummaryFixture();
            summary = r36SummarizeSchemeE( ...
                design, results, r36CommonProtocol());
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));

            manifest = r36BuildSchemeEFigures(summary, folder);

            testCase.verifyEqual(height(summary.summary), 9);
            testCase.verifyEqual(height(summary.comparisons), 8);
            testCase.verifyEqual(height(summary.gate), 8);
            testCase.verifyEqual(height(manifest), 5);
            testCase.verifyTrue(all(isfile(manifest.file)));
        end
    end
end

function state = geometryState(cfg, carrierCount)
ids = 49:208;
state = struct(referencePositionM= ...
    cfg.elementIndex(ids)*cfg.elementSpacing, ...
    frequencyHz=linspace(58.5e9, 61.5e9, carrierCount), ...
    subarraySize=numel(ids));
end

function state = randomState(cfg, subarraySize, carrierCount)
vectors = randn(subarraySize, carrierCount) ...
    +1i*randn(subarraySize, carrierCount);
vectors = vectors./vecnorm(vectors);
ids = 1:subarraySize;
state = struct(signalVectors=vectors, ...
    referencePositionM=cfg.elementIndex(ids)*cfg.elementSpacing, ...
    frequencyHz=linspace(58.5e9, 61.5e9, carrierCount), ...
    subarraySize=subarraySize);
end

function value = relativeError(first, second)
value = norm(first-second, "fro")/max(norm(second, "fro"), eps);
end

function [design, results] = syntheticSummaryFixture()
seed = (1:6).';
trialIndex = seed;
snrDb = repelem([-10; 0; 20], 2);
truthThetaDeg = zeros(6, 1);
truthRangeM = 30*ones(6, 1);
design = table(seed, trialIndex, snrDb, truthThetaDeg, truthRangeM);
results = cell(6, 1);
for index = 1:6
    thetaPA = 0.001*index;
    thetaE = 0.98*thetaPA;
    results{index} = syntheticResult(thetaPA, thetaE);
end
end

function result = syntheticResult(thetaPA, thetaE)
record = @(theta, range, runtime, response, music) struct( ...
    thetaDeg=theta, rangeM=range, runtimeSeconds=runtime, ...
    responseEvaluationCount=response, musicEvaluationCount=music, ...
    evdCount=2047);
linearization = struct(cost=0.01, gradient=[-1; 0.01], ...
    information=[100, 0.1; 0.1, 2]);
refinement = struct(bracketDeg=[thetaPA-0.001, thetaPA+0.001], ...
    rawDisplacementDeg=thetaE-thetaPA, ...
    diagnosticRangeDisplacementM=1e-6, validUpdate=true, ...
    clippedToBracket=false, status="completed", ...
    linearization=linearization, predictedCostReduction=1e-4, ...
    actualCostReduction=9e-5, effectiveGradient=-1, ...
    effectiveInformation=100, couplingCoefficient=0.01);
result = struct(success=true, runtimeOrder="synthetic", ...
    frontThetaDeg=thetaPA+0.01, frontRangeM=30.1, ...
    P_A=record(thetaPA, 30.01, 2, 100, 93), ...
    E_one_step=record(thetaE, 30.008, 2.1, 101, 95), ...
    C_enhanced=record(thetaPA, 30.02, 4, 90, 3083), ...
    refinement=refinement);
result.E_one_step.refinementSeconds = 0.01;
result.E_one_step.profileSeconds = 0.2;
end
