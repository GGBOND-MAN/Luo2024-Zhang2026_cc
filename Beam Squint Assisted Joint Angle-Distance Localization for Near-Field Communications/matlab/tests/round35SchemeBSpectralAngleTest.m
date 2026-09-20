classdef round35SchemeBSpectralAngleTest < matlab.unittest.TestCase
    %ROUND35SCHEMEB_SPECTRALANGLETEST Scheme B protocol tests.

    methods (TestClassSetup)
        function addSchemeBPaths(testCase)
            matlabRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabRoot, "+r35", "schemeB")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabRoot, "+r35", "common")));
        end
    end

    methods (Test)
        function interiorSpectralMaximumIsRefined(testCase)
            score = @(thetaDeg) -(thetaDeg-0.2).^2;

            result = r35BracketedSpectralRefinement( ...
                score, [-1, 0, 1], 2);

            testCase.verifyEqual(result.bracketDeg, [-1, 1], AbsTol=0);
            testCase.verifyEqual(result.thetaSpectralDeg, 0.2, AbsTol=1e-7);
            testCase.verifyGreaterThanOrEqual( ...
                result.scoreAfter, result.scoreBefore-1e-12);
            testCase.verifyGreaterThan(result.functionEvaluations, 1);
            testCase.verifyTrue(result.converged);
            testCase.verifyFalse(result.boundaryFlag);
        end

        function feasibleBoundaryUsesOnlyOneSidedGridInterval(testCase)
            score = @(thetaDeg) -(thetaDeg+0.8).^2;

            result = r35BracketedSpectralRefinement( ...
                score, [-1, 0, 1], 1);

            testCase.verifyEqual(result.bracketDeg, [-1, 0], AbsTol=0);
            testCase.verifyGreaterThanOrEqual(result.thetaSpectralDeg, -1);
            testCase.verifyLessThanOrEqual(result.thetaSpectralDeg, 0);
            testCase.verifyTrue(result.boundaryFlag);
        end

        function thetaABaselineIsRetainedWhenOptimizerCannotImprove(testCase)
            score = @(thetaDeg) -thetaDeg.^2;

            result = r35BracketedSpectralRefinement( ...
                score, [-1, 0, 1], 2);

            testCase.verifyGreaterThanOrEqual( ...
                result.scoreAfter, result.scoreBefore-1e-12);
            testCase.verifyLessThanOrEqual( ...
                abs(result.thetaSpectralDeg), 1e-7);
        end

        function primaryTrialContainsNoRangeRefresh(testCase)
            source = fileread(which("r35SchemeBPrimaryTrial"));

            testCase.verifyTrue(contains( ...
                source, "r33.fixedAngleProfileLogScore"));
            testCase.verifyFalse(contains(source, "profileAtAngle"));
        end

        function aggregatePairingAndAngleGateAreFrozen(testCase)
            [design, results, schemeA] = syntheticSummaryFixture();

            output = r35SummarizeSchemeB( ...
                design, results, schemeA, r35CommonProtocol());
            row = output.comparisons(output.comparisons.candidate ...
                == "B_primary" & output.comparisons.reference == "P_A" ...
                & output.comparisons.scope == "equal-SNR", :);

            testCase.verifyEqual(row.n, 6);
            testCase.verifyEqual( ...
                row.winCount+row.tieCount+row.lossCount, 6);
            testCase.verifyFalse(output.primaryAngleGatePassed);
        end
    end
end

function [design, results, schemeA] = syntheticSummaryFixture()
seed = (1:6).';
trialIndex = seed;
snrDb = repelem([-10; 0; 20], 2);
truthThetaDeg = zeros(6, 1);
truthRangeM = 20*ones(6, 1);
design = table(seed, trialIndex, snrDb, truthThetaDeg, truthRangeM);
results = cell(6, 1);
thetaPA = 0.001*(1:6).';
thetaACont = 0.9*thetaPA;
for index = 1:6
    results{index} = syntheticResult(thetaPA(index));
end
schemeA = table(seed, snrDb, thetaPA, 20.01*ones(6, 1), ...
    thetaACont, thetaACont-thetaPA, 'VariableNames', ...
    {'seed', 'snrDb', 'theta_P_A', 'range_P_A', ...
    'theta_A_cont', 'aDisplacementDeg'});
end

function result = syntheticResult(thetaPA)
record = @(thetaDeg, rangeM, runtime, responses, music) struct( ...
    thetaDeg=thetaDeg, rangeM=rangeM, runtimeSeconds=runtime, ...
    responseEvaluationCount=responses, musicEvaluationCount=music);
refinement = @(base, value) struct( ...
    bracketDeg=[base-0.001, base+0.001], ...
    scoreBefore=1, scoreAfter=2, displacementDeg=value-base, ...
    functionEvaluations=7, converged=true, boundaryFlag=false, ...
    selectedSource="spectral-continuous", runtimeSeconds=0.1);
thetaB = 1.1*thetaPA;
result = struct(success=true, runtimeOrder="synthetic", ...
    P_A=record(thetaPA, 20.01, 2, 100, 93), ...
    C_enhanced=record(thetaPA, 20.02, 4, 90, 3083), ...
    B_primary=record(thetaB, 20.01, 2.2, 107, 93), ...
    C_FS_angle_control=record(thetaB, 20.02, 4.2, 97, 3083), ...
    bRefinement=refinement(thetaPA, thetaB), ...
    cRefinement=refinement(thetaPA, thetaB), ...
    responseContextSeconds=0.02, responseContextBytes=1000);
end
