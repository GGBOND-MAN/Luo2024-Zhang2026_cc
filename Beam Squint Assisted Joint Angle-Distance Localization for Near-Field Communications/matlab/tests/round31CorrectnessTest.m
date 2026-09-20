classdef round31CorrectnessTest < matlab.unittest.TestCase
    %ROUND31CORRECTNESSTEST Regression tests for the isolated repair path.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=false));
        end
    end

    methods (Test)
        function testKnownGridMaximumIsRetained(testCase)
            score = @(x) max(exp(-((x-0.5)/1e-5).^2), ...
                0.8*exp(-((x-0.56)/0.02).^2));

            result = r31.maximizeScore1D( ...
                score, [0, 1], Intervals=10, PeakCount=1);

            testCase.verifyGreaterThanOrEqual(result.score, ...
                max(result.gridScore)-1e-10);
            testCase.verifyEqual(result.value, 0.5, AbsTol=1e-12);
        end

        function testNearDuplicateRetainsHighestScorePair(testCase)
            feasible = [0.5; 0.5005];

            result = r31.maximizeScore1D(@duplicateScore, ...
                [0.49, 0.51], feasible, Intervals=4, ...
                PeakCount=1, TolX=1e-3);

            testCase.verifyEqual(result.value, 0.5005, AbsTol=1e-12);
            testCase.verifyEqual(result.score, 10, AbsTol=1e-12);
        end

        function testEndpointOptimumIsExplicit(testCase)
            result = r31.maximizeScore1D(@(x) -x, ...
                [0, 1], Intervals=10, PeakCount=1);

            testCase.verifyEqual(result.value, 0, AbsTol=1e-12);
            testCase.verifyTrue(result.endpointHit);
            testCase.verifyTrue(result.nearBoundary);
            testCase.verifyTrue(result.endpointOutwardTrend);
        end

        function testNonfiniteRefinementFallsBack(testCase)
            result = r31.maximizeScore1D(@nonfiniteInteriorScore, ...
                [0, 1], Intervals=10, PeakCount=1);

            testCase.verifyEqual(result.value, 0.5, AbsTol=1e-12);
            testCase.verifyGreaterThanOrEqual(result.score, ...
                max(result.gridScore)-1e-10);
            testCase.verifyFalse(any(result.refinement.accepted));
            testCase.verifyTrue(any(contains( ...
                result.refinement.status, "rejected")));
        end

        function testSelectedScoreDominatesEveryRetainedCandidate(testCase)
            feasible = [0.13; 0.51; 0.91];

            result = r31.maximizeScore1D( ...
                @(x) cos(13*x)+0.1*x, [0, 1], feasible, ...
                Intervals=30, PeakCount=4);

            testCase.verifyGreaterThanOrEqual(result.score, ...
                max([result.gridScore; result.candidateScore])-1e-10);
            testCase.verifyGreaterThanOrEqual(result.retentionMargin, -1e-10);
        end

        function testNearBoundaryIsNotEndpoint(testCase)
            result = r31.maximizeScore1D( ...
                @(x) -(x-0.02).^2, [0, 1], ...
                Intervals=10, PeakCount=1, TolX=1e-7);

            testCase.verifyFalse(result.endpointHit);
            testCase.verifyTrue(result.nearBoundary);
            testCase.verifyFalse(result.endpointOutwardTrend);
        end

        function testOutputSpecificSelectionKeepsFeasibleP(testCase)
            [summary, baseline] = selectionCounterexample();
            protocol = r31.config();

            [selection, selected] = r31.selectDeployments( ...
                summary, baseline, protocol);

            hRow = selection(selection.output == "H_L", :);
            pRow = selection(selection.output == "P_L", :);
            testCase.verifyFalse(hRow.passAccuracy);
            testCase.verifyTrue(pRow.passAccuracy);
            testCase.verifyEqual(selected.output, "P_L");
        end

        function testDiagnosticExpansionIsRejected(testCase)
            selected = struct(reason= ...
                "no-deployment-met-all-thresholds-pareto-diagnostic-only", ...
                formalExpansionAllowed=false);

            testCase.verifyError( ...
                @() r31.assertFormalExpansionAllowed(selected), ...
                "r31:DiagnosticExpansionRejected");
        end

        function testRevisedSummarySeparatesDeploymentCosts(testCase)
            [design, rowResults, candidates] = syntheticLegacyResults();

            summary = r31.reviseRound30Summary( ...
                design, rowResults, candidates, r31.config());

            f = summary(summary.method == "F_L", :);
            h = summary(summary.method == "H_L", :);
            p = summary(summary.method == "P_L", :);
            testCase.verifyEqual(unique(f.meanEquivalentResponses), 100);
            testCase.verifyEqual(unique(h.meanEquivalentResponses), 100);
            testCase.verifyEqual(unique(p.meanEquivalentResponses), 150);
            testCase.verifyEqual(unique(f.meanDeploymentSeconds), 1);
            testCase.verifyEqual(unique(h.meanDeploymentSeconds), 6);
            testCase.verifyEqual(unique(p.meanDeploymentSeconds), 10);
            testCase.verifyTrue(all(isnan(f.angleNearBoundaryRate)));
            testCase.verifyTrue(all(isnan(h.profileNearBoundaryRate)));
        end

        function testStagedJointMatchesLegacyGrid(testCase)
            [cfg, snapshots, carrierIndex, thetaDeg, rangeM] = musicCase();
            state = jad.freezeLocalMusicSubspace( ...
                cfg, snapshots, carrierIndex, thetaDeg, rangeM);

            legacy = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
                thetaDeg, rangeM, ConstrainToInitialWindow=true);
            revised = r31.stagedJointMusic(cfg, state, thetaDeg, rangeM, ...
                cfg.localHalfWidthDeg, cfg.localHalfWidthM, cfg.gridSizes);

            testCase.verifyEqual(revised.thetaDeg, legacy.thetaDeg, AbsTol=1e-12);
            testCase.verifyEqual(revised.rangeM, legacy.rangeM, AbsTol=1e-12);
        end

        function testSubsetStatePreservesExactColumns(testCase)
            [cfg, snapshots, carrierIndex, thetaDeg, rangeM] = musicCase();
            state = jad.freezeLocalMusicSubspace( ...
                cfg, snapshots, carrierIndex, thetaDeg, rangeM);
            requested = carrierIndex([1, 3, 5]);

            [subset, columns] = r31.subsetState(state, requested);

            testCase.verifyEqual(subset.carrierIndex, requested);
            testCase.verifyEqual(subset.signalVectors, ...
                state.signalVectors(:, columns), AbsTol=0);
        end

        function testMusicScoreScalarBatchConsistency(testCase)
            [cfg, snapshots, carrierIndex, thetaDeg, rangeM] = musicCase();
            state = jad.freezeLocalMusicSubspace( ...
                cfg, snapshots, carrierIndex, thetaDeg, rangeM);
            theta = thetaDeg+[-0.01, 0, 0.01];

            batch = jad.localMusicLogScore(cfg, state, theta, rangeM);
            scalar = [jad.localMusicLogScore(cfg, state, theta(1), rangeM), ...
                jad.localMusicLogScore(cfg, state, theta(2), rangeM), ...
                jad.localMusicLogScore(cfg, state, theta(3), rangeM)];

            testCase.verifyEqual(batch, scalar, AbsTol=1e-10);
        end

        function testArrayHashTracksContent(testCase)
            first = r31.arrayHash([1, 2, 3]);
            repeated = r31.arrayHash([1, 2, 3]);
            changed = r31.arrayHash([1, 2, 4]);

            testCase.verifyEqual(first, repeated);
            testCase.verifyNotEqual(first, changed);
        end
    end
end

function [summary, baseline] = selectionCounterexample()
summary = table();
baseline = table();
for snrDb = [-10, 0, 20]
    for method = ["C_star", "H_star"]
        row = table(method, snrDb, 1, 1, 1, 1, 0, ...
            'VariableNames', {'method', 'snrDb', 'angleRmseDeg', ...
            'rmseM', 'jointRmseM', 'p95M', 'missOver1m'});
        baseline = [baseline; row]; %#ok<AGROW>
    end
    h = table("L00", snrDb, "H_L", 1, 1.11, 1, 1, 0, 100, 1, ...
        'VariableNames', {'candidateId', 'snrDb', 'method', ...
        'angleRmseDeg', 'rangeRmseM', 'positionRmseM', 'p95RangeM', ...
        'missOver1m', 'meanEquivalentResponses', 'meanDeploymentSeconds'});
    p = table("L00", snrDb, "P_L", 1, 1, 1, 1.14, 0, 150, 2, ...
        'VariableNames', h.Properties.VariableNames);
    summary = [summary; h; p]; %#ok<AGROW>
end
end

function [design, rowResults, candidates] = syntheticLegacyResults()
design = table([1; 2; 3], [-10; 0; 20], zeros(3, 1), 30*ones(3, 1), ...
    'VariableNames', {'seed', 'snrDb', 'truthThetaDeg', 'truthRangeM'});
candidates = table("L00", 'VariableNames', {'candidateId'});
rowResults = cell(3, 1);
for index = 1:3
    solver = struct(value=0, interval=[-0.1, 0.1], ...
        grid=linspace(-0.1, 0.1, 11), boundary=false, evaluationCount=50);
    item = struct(thetaDeg=[0, 0, 0], rangeM=[30, 30, 30], ...
        front=struct(fullEquivalentResponses=100, runtimeSeconds=1), ...
        musicStateCost=struct(seconds=2), angleSeconds=3, ...
        profileSeconds=4, totalSeconds=10, angleSolver=solver, ...
        profileSolver=solver, complexity=struct( ...
        musicPhaseAlignmentTerms=10, musicCovarianceMacs=20, ...
        musicEvdCubicUnits=30, angleScoreProjectionMacs=40));
    rowResults{index} = struct(candidateResults={{item}});
end
end

function [cfg, snapshots, carrierIndex, thetaDeg, rangeM] = musicCase()
cfg = jad.defaultConfig();
cfg.numAntennas = 16;
cfg.numSubcarriers = 64;
cfg.subarraySize = 8;
cfg.numSubarrays = 9;
cfg.elementIndex = (0:15).'-7.5;
cfg.localHalfWidthDeg = 0.1;
cfg.localHalfWidthM = 0.1;
cfg.gridSizes = [11, 9, 7];
thetaDeg = 5;
rangeM = 30;
carrierIndex = [10; 20; 30; 40; 50];
stream = RandStream("mt19937ar", Seed=20260910);
snapshots = jad.simulateSnapshots( ...
    cfg, thetaDeg, rangeM, 20, carrierIndex, stream);
end

function score = duplicateScore(value)
score = -abs(value-0.5005);
score(abs(value-0.5005) <= 1e-12) = 10;
end

function score = nonfiniteInteriorScore(value)
score = 1-(value-0.5).^2;
isGridNode = abs(value*10-round(value*10)) <= 1e-12;
score(~isGridNode) = nan;
end
