classdef maximizeRangeScoreTest < matlab.unittest.TestCase
    %MAXIMIZERANGESCORETEST Common deterministic one-dimensional solver.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            sourceFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(sourceFolder));
        end
    end

    methods (Test)
        function selectsGlobalPeakAcrossMultipleBrackets(testCase)
            score = @(rangeM) max( ...
                1-(rangeM-1.2).^2, 1.5-4*(rangeM-3.7).^2);
            result = fsjad.maximizeRangeScore( ...
                score, [0, 5], [1.2; 3.7], InitialSpacingM=0.2, ...
                MinimumIntervals=20, RefinementLevels=3, PeakCount=4, ...
                KeepTrace=true);

            testCase.verifyEqual(result.rangeM, 3.7, AbsTol=2e-5);
            testCase.verifyEqual(result.score, 1.5, AbsTol=1e-9);
            testCase.verifyFalse(result.boundary);
            testCase.verifyEqual(result.levels(2).gridStepM, ...
                result.levels(1).gridStepM/2, AbsTol=1e-12);
            testCase.verifyEqual(result.levels(3).gridStepM, ...
                result.levels(2).gridStepM/2, AbsTol=1e-12);
        end

        function preservesFeasibleOldCandidate(testCase)
            score = @(rangeM) -(rangeM-2.34567).^2;
            result = fsjad.maximizeRangeScore( ...
                score, [1, 4], 2.34567, InitialSpacingM=1, ...
                MinimumIntervals=3, RefinementLevels=1, PeakCount=1);

            testCase.verifyEqual(result.rangeM, 2.34567, AbsTol=1e-12);
            testCase.verifyTrue(any(result.candidateRanking.rangeM ...
                == 2.34567));
        end

        function boundaryTrendTriggersPredeterminedExpansion(testCase)
            score = @(rangeM) rangeM;
            options = struct(InitialSpacingM=0.1, MinimumIntervals=20, ...
                RefinementLevels=2, PeakCount=2, TolX=1e-7, ...
                ScoreTolerance=1e-12, KeepTrace=false);
            result = fsjad.expandRangeSearch( ...
                score, 5, [0, 10], [1, 2, 4], zeros(0, 1), options);

            testCase.verifyEqual(result.usedStages, 3);
            testCase.verifyEqual(result.finalIntervalM, [1, 9]);
            testCase.verifyEqual(result.termination, "maximum_expansion");
            testCase.verifyTrue(result.stages{1}.outwardTrend);
        end

        function interiorPeakStopsExpansion(testCase)
            score = @(rangeM) -(rangeM-5.25).^2;
            options = struct(InitialSpacingM=0.1, MinimumIntervals=20, ...
                RefinementLevels=2, PeakCount=2, TolX=1e-7, ...
                ScoreTolerance=1e-12, KeepTrace=false);
            result = fsjad.expandRangeSearch( ...
                score, 5, [0, 10], [1, 2, 4], zeros(0, 1), options);

            testCase.verifyEqual(result.usedStages, 1);
            testCase.verifyEqual(result.rangeM, 5.25, AbsTol=2e-5);
            testCase.verifyEqual(result.termination, "interior");
        end

        function reachableIntervalMatchesR26Zhang(testCase)
            cfg = jad.defaultConfig();
            cfg.localHalfWidthM = 0.0025;
            cfg.gridSizes = [41, 31, 21];
            interval = jad.localMusicReachableInterval(cfg, 30);

            testCase.verifyEqual(interval.levelHalfWidthM, ...
                [0.0025, 0.00025, 1/30000], AbsTol=1e-15);
            testCase.verifyEqual(interval.totalHalfWidthM, ...
                0.002783333333333333, AbsTol=1e-15);
            testCase.verifyEqual(interval.boundsM, ...
                30+[-1, 1]*interval.totalHalfWidthM, AbsTol=1e-14);
        end


        function deterministicPeakBankUsesNestedLocalGrids(testCase)
            score = @(rangeM) max( ...
                1-(rangeM-1.2).^2, 1.5-4*(rangeM-3.7).^2);
            result = fsjad.findRangePeakCandidates( ...
                score, [0, 5], 2.34567, InitialSpacingM=0.2, ...
                MinimumIntervals=20, RefinementLevels=3, PeakCount=4, ...
                KeepTrace=true);

            testCase.verifyEqual(result.rangeM(1), 3.7, AbsTol=2e-5);
            testCase.verifyTrue(any(result.source == "lower_endpoint"));
            testCase.verifyTrue(any(result.source == "upper_endpoint"));
            testCase.verifyTrue(any(result.source == "feasible"));
            steps = result.peakTrace{1}.levelStepM;
            testCase.verifyLessThanOrEqual(steps(2), steps(1)/2+1e-12);
            testCase.verifyLessThanOrEqual(steps(3), steps(2)/2+1e-12);
        end
    end
end
