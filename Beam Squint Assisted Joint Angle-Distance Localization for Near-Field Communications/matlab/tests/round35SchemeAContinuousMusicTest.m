classdef round35SchemeAContinuousMusicTest < matlab.unittest.TestCase
    %ROUND35SCHEMEACONTINUOUSMUSICTEST Bounded refinement unit tests.

    methods (TestClassSetup)
        function addSchemeAPaths(testCase)
            matlabRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabRoot, "+r35", "schemeA")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabRoot, "+r35", "common")));
        end
    end

    methods (Test)
        function interiorMaximumIsRefinedInsideNeighborBracket(testCase)
            score = @(thetaDeg) -(thetaDeg-0.25).^2;
            grid = [-1, 0, 1];

            result = r35BracketedMusicRefinement( ...
                score, grid, 2, score(0));

            testCase.verifyEqual(result.bracketDeg, [-1, 1], AbsTol=0);
            testCase.verifyEqual(result.thetaContDeg, 0.25, AbsTol=1e-7);
            testCase.verifyGreaterThanOrEqual( ...
                result.scoreAfter, result.scoreBefore-1e-12);
            testCase.verifyGreaterThan(result.functionEvaluations, 0);
            testCase.verifyTrue(result.converged);
        end

        function finalGridEndpointIsRetainedWithoutExpansion(testCase)
            score = @(thetaDeg) -thetaDeg.^2;
            grid = [-1, 0, 1];

            result = r35BracketedMusicRefinement( ...
                score, grid, 1, score(-1));

            testCase.verifyEqual(result.thetaContDeg, -1, AbsTol=0);
            testCase.verifyTrue(all(isnan(result.bracketDeg)));
            testCase.verifyEqual(result.functionEvaluations, 0);
            testCase.verifyFalse(result.converged);
            testCase.verifyEqual(result.status, ...
                "grid-endpoint-no-two-sided-bracket");
        end

        function gridBestIsAlwaysASelectableCandidate(testCase)
            score = @(thetaDeg) -thetaDeg.^2;
            grid = [-1, 0, 1];

            result = r35BracketedMusicRefinement( ...
                score, grid, 2, score(0));

            testCase.verifyGreaterThanOrEqual( ...
                result.scoreAfter, result.scoreBefore-1e-12);
            testCase.verifyLessThanOrEqual( ...
                abs(result.thetaContDeg), 1e-7);
        end

        function aggregatePairingKeepsOneDifferencePerUser(testCase)
            [design, results] = syntheticSummaryFixture();

            output = r35SummarizeSchemeA( ...
                design, results, r35CommonProtocol());
            row = output.comparisons(output.comparisons.candidate ...
                == "A_cont" & output.comparisons.reference == "P_A" ...
                & output.comparisons.scope == "equal-SNR", :);

            testCase.verifyEqual(row.n, 6);
            testCase.verifyEqual( ...
                row.winCount+row.tieCount+row.lossCount, 6);
        end
    end
end

function [design, results] = syntheticSummaryFixture()
seed = (1:6).';
trialIndex = seed;
snrDb = repelem([-10; 0; 20], 2);
truthThetaDeg = zeros(6, 1);
truthRangeM = 20*ones(6, 1);
design = table(seed, trialIndex, snrDb, truthThetaDeg, truthRangeM);
results = cell(6, 1);
for index = 1:6
    paTheta = 0.001*index;
    aTheta = 0.9*paTheta;
    cTheta = paTheta;
    ccTheta = 0.9*cTheta;
    results{index} = syntheticResult( ...
        paTheta, aTheta, cTheta, ccTheta);
end
end

function result = syntheticResult(paTheta, aTheta, cTheta, ccTheta)
record = @(thetaDeg, rangeM, runtime, responses, music) struct( ...
    thetaDeg=thetaDeg, rangeM=rangeM, runtimeSeconds=runtime, ...
    responseEvaluationCount=responses, musicEvaluationCount=music);
refinement = @(grid, continuous) struct( ...
    bracketDeg=[grid-0.001, grid+0.001], scoreBefore=1, ...
    scoreAfter=2, displacementDeg=continuous-grid, ...
    functionEvaluations=6, converged=true, selectedSource="continuous");
result = struct( ...
    success=true, runtimeOrder="synthetic", ...
    P_A=record(paTheta, 20.01, 2, 100, 93), ...
    A_cont=record(aTheta, 20.005, 2.1, 100, 99), ...
    C_enhanced=record(cTheta, 20.02, 4, 90, 3083), ...
    C_cont=record(ccTheta, 20.02, 4.1, 90, 3089), ...
    aRefinement=refinement(paTheta, aTheta), ...
    cRefinement=refinement(cTheta, ccTheta));
end
