classdef round35SchemeDWeightedMusicTest < matlab.unittest.TestCase
    %ROUND35SCHEMEDWEIGHTEDMUSICTEST Scheme D identity and derivative tests.

    methods (TestClassSetup)
        function addSchemeDPaths(testCase)
            matlabRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                matlabRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabRoot, "+r35", "schemeD")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabRoot, "+r35", "common")));
        end
    end

    methods (Test)
        function analyticDerivativeMatchesFiniteDifference(testCase)
            cfg = jad.defaultConfig();
            state = derivativeState(cfg);
            thetaRad = deg2rad(13.2);
            rangeM = 27.4;
            step = 1e-7;

            [~, analytic] = r35AngleSteeringDerivative( ...
                cfg, state, thetaRad, rangeM);
            plus = r35AngleSteeringDerivative( ...
                cfg, state, thetaRad+step, rangeM);
            minus = r35AngleSteeringDerivative( ...
                cfg, state, thetaRad-step, rangeM);
            finiteDifference = (plus-minus)/(2*step);

            relativeError = norm(analytic-finiteDifference, "fro") ...
                /norm(finiteDifference, "fro");
            testCase.verifyLessThan(relativeError, 1e-6);
        end

        function uniformFusionReproducesFrozenGridSearch(testCase)
            rng(35);
            cfg = jad.defaultConfig();
            cfg.subarraySize = 4;
            state = syntheticState(cfg, 4, 7);
            halfWidth = 0.2;
            gridSizes = [41, 31, 21];
            paEstimate = r31.stagedAngleMusic(cfg, state, ...
                state.coarseThetaDeg, state.coarseRangeM, ...
                halfWidth, gridSizes);
            pa = struct(thetaDeg=paEstimate.thetaDeg, estimate=paEstimate);
            weight = r35BuildCarrierWeights(cfg, state, struct(), ...
                "D0_uniform", r35SchemeDConfig());
            d0 = r35StagedWeightedAngleMusic(cfg, state, ...
                state.coarseThetaDeg, state.coarseRangeM, ...
                halfWidth, gridSizes, weight.weights);

            audit = r35AssertD0Identity(pa, d0, r35SchemeDConfig());
            testCase.verifyTrue(audit.passed);
            testCase.verifyEqual(audit.finalThetaDifferenceDeg, 0);
        end

        function parameterFreeWeightsAreNormalized(testCase)
            cfg = jad.defaultConfig();
            cfg.subarraySize = 5;
            state = syntheticState(cfg, 5, 11);
            stateCost = struct(relativeEigengap=linspace(0.1, 0.9, 11).');
            for method = ["D1_gap", "D2_information", "D3_mix"]
                result = r35BuildCarrierWeights( ...
                    cfg, state, stateCost, method, r35SchemeDConfig());
                testCase.verifyEqual(sum(result.weights), 1, AbsTol=1e-12);
                testCase.verifyGreaterThanOrEqual(min(result.weights), 0);
                testCase.verifyGreaterThan( ...
                    result.diagnostics.effectiveCarrierCount, 0);
            end
        end

        function schemeDSourceContainsNoContinuousRefinement(testCase)
            files = dir(fullfile(fileparts(which("r35SchemeDConfig")), "*.m"));
            source = "";
            for index = 1:numel(files)
                source = source+newline+string(fileread( ...
                    fullfile(files(index).folder, files(index).name)));
            end
            testCase.verifyFalse(contains(lower(source), "fminbnd"));
            testCase.verifyFalse(contains(lower(source), "continuous"));
            testCase.verifyFalse(contains(source, "schemeA"));
            testCase.verifyFalse(contains(source, "schemeB"));
        end

        function syntheticSummaryAndFiguresComplete(testCase)
            [design, baselines, results, weights, frequencyHz] = ...
                syntheticSummaryFixture();
            summary = r35SummarizeSchemeD( ...
                design, baselines, results, r35CommonProtocol());
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));

            manifest = r35BuildSchemeDFigures( ...
                summary, weights, frequencyHz, folder);

            testCase.verifyEqual(height(summary.methodSummary), 15);
            testCase.verifyEqual(height(summary.pairedComparisons), 12);
            testCase.verifyEqual(height(summary.gateDecision), 3);
            testCase.verifyEqual(height(manifest), 5);
            testCase.verifyTrue(all(isfile(manifest.file)));
        end
    end
end

function state = derivativeState(cfg)
ids = 49:208;
state = struct(referencePositionM=cfg.elementIndex(ids)*cfg.elementSpacing, ...
    frequencyHz=[95e9, 100e9, 105e9], subarraySize=numel(ids));
end

function state = syntheticState(cfg, subarraySize, carrierCount)
vectors = randn(subarraySize, carrierCount) ...
    +1i*randn(subarraySize, carrierCount);
vectors = vectors./vecnorm(vectors);
ids = 1:subarraySize;
state = struct(signalVectors=vectors, ...
    carrierIndex=(0:carrierCount-1).', ...
    frequencyHz=linspace(95e9, 105e9, carrierCount).', ...
    referencePositionM=cfg.elementIndex(ids)*cfg.elementSpacing, ...
    subarraySize=subarraySize, coarseThetaDeg=8.4, coarseRangeM=31.2);
end

function [design, baselines, results, allWeights, frequencyHz] = ...
    syntheticSummaryFixture()
seed = (1:6).';
trialIndex = seed;
snrDb = repelem([-10; 0; 20], 2);
truthThetaDeg = zeros(6, 1);
truthRangeM = 30*ones(6, 1);
design = table(seed, trialIndex, snrDb, truthThetaDeg, truthRangeM);
frequencyHz = linspace(95e9, 105e9, 11).';
uniform = ones(11, 1)/11;
gap = (1:11).'; gap = gap/sum(gap);
information = flipud(gap);
mix = sqrt(gap.*information); mix = mix/sum(mix);
allWeights = struct(D0_uniform=repmat(uniform, 1, 6), ...
    D1_gap=repmat(gap, 1, 6), ...
    D2_information=repmat(information, 1, 6), ...
    D3_mix=repmat(mix, 1, 6));
baselines = cell(6, 1);
results = cell(6, 1);
for index = 1:6
    theta0 = 0.01*index;
    d0 = location(theta0, 30.01, 2, 100, 93, 93*2047, 2047);
    c = location(0.9*theta0, 30.005, 4, 90, 3083, 3083*2047, 2047);
    audit = struct(passed=true, gridPass=true, ...
        selectedIndexPass=true, selectedThetaPass=true, ...
        maximumStageScoreDifference=0, finalThetaDifferenceDeg=0);
    baselines{index} = struct(success=true, runtimeOrder="synthetic", ...
        D0_uniform=d0, P_A=d0, C_enhanced=c, d0Identity=audit, ...
        d0WeightDiagnostics=weightDiagnostic(uniform, frequencyHz), ...
        d0IdentitySearchSeconds=0.01);
    results{index} = struct(success=true, executionOrder="synthetic", ...
        D1_gap=weightedLocation(0.99*theta0, gap, frequencyHz), ...
        D2_information=weightedLocation(0.98*theta0, ...
        information, frequencyHz), ...
        D3_mix=weightedLocation(0.97*theta0, mix, frequencyHz));
end
end

function output = location(theta, range, runtime, response, music, ...
    carrierMusic, evd)
output = struct(thetaDeg=theta, rangeM=range, runtimeSeconds=runtime, ...
    responseEvaluationCount=response, musicEvaluationCount=music, ...
    carrierScoreEvaluationCount=carrierMusic, evdCount=evd);
end

function output = weightedLocation(theta, weights, frequencyHz)
output = location(theta, 30.008, 2.2, 100, 93, 93*2047, 2047);
output.weightConstructionSeconds = 0.01;
output.weightedFusionSeconds = 0.1;
output.profileSeconds = 0.2;
output.weightDiagnostics = weightDiagnostic(weights, frequencyHz);
end

function output = weightDiagnostic(weights, frequencyHz)
ordered = sort(weights, "descend");
positive = weights(weights > 0);
output = struct(maxWeight=max(weights), ...
    minNonzeroWeight=min(positive), ...
    effectiveCarrierCount=1/sum(weights.^2), ...
    normalizedEntropy=-sum(positive.*log(positive))/log(numel(weights)), ...
    top1Cumulative=ordered(1), ...
    top10Cumulative=sum(ordered(1:min(10, numel(weights)))), ...
    top100Cumulative=sum(ordered), ...
    weightedMeanFrequencyHz=sum(weights.*frequencyHz), ...
    edgeCumulative=sum(weights([1, end])), ...
    centerCumulative=weights(ceil(end/2)));
end
