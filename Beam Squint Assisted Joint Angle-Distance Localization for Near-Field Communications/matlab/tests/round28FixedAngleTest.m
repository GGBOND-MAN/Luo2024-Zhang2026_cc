classdef round28FixedAngleTest < matlab.unittest.TestCase
    %ROUND28FIXEDANGLETEST Incremental replay and frozen-subspace wiring.

    properties
        Project
        AggregateFile
    end

    methods (TestClassSetup)
        function addSourcePath(testCase)
            testCase.Project = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.Project));
            testCase.AggregateFile = fullfile(testCase.Project, "results", ...
                "full_spectrum", "round27_v3_0010_per_snr", ...
                "aggregate", "round27_aggregate.mat");
        end
    end

    methods (Test)
        function setupRejectsObsoleteV2(testCase)
            temporary = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            old = load(testCase.AggregateFile, "setup", "design", "results");
            old.setup.protocol.version = "Round27-convergence-ablation-v2";
            file = fullfile(temporary.Folder, "obsolete.mat");
            setup = old.setup;
            design = old.design;
            results = old.results;
            save(file, "setup", "design", "results");

            testCase.verifyError(@() fsjad.round28Setup( ...
                testCase.Project, file, 1, "development"), ...
                "fsjad:Round28RequiresRound27V3");
        end

        function setupUsesSavedRowsWithoutNewSeeds(testCase)
            setup = fsjad.round28Setup( ...
                testCase.Project, testCase.AggregateFile, 2, "development");

            testCase.verifyEqual(height(setup.design), 6);
            testCase.verifyEqual(setup.protocol.version, ...
                "Round28-fixed-angle-range-v1");
            testCase.verifyFalse(setup.protocol.oldAlphaActive);
            testCase.verifyEqual(setup.protocol.profileLambda, 1);
            testCase.verifyEqual(setup.protocol.primaryComparison, ...
                "P_w-minus-M_w");
            saved = load(testCase.AggregateFile, "design");
            expected = saved.design(saved.design.trialIndex <= 2, :);
            testCase.verifyEqual(setup.design.seed, expected.seed);
        end

        function replayMatchesSavedPeak(testCase)
            setup = fsjad.round28Setup( ...
                testCase.Project, testCase.AggregateFile, 1, "development");
            scan = fsjad.prepareScan(setup.cfg);
            replay = fsjad.replayRound27Data( ...
                setup.cfg, scan, setup.design(1, :));

            testCase.verifyEqual(replay.peakCarrierIndex, ...
                setup.oldResults{1}.peakCarrierIndex);
            testCase.verifyEqual(replay.rngType, "mt19937ar");
            testCase.verifySize(replay.snapshots, ...
                [setup.cfg.numAntennas, setup.cfg.numSubcarriers]);
        end

        function reducedEndToEndTrial(testCase)
            oldSetup = fsjad.round27Setup(testCase.Project, 1, "smoke");
            scan = fsjad.prepareScan(oldSetup.cfg);
            row = oldSetup.design(1, :);
            oldResult = fsjad.round27Trial(oldSetup, scan, row);
            testCase.assertTrue(oldResult.success, oldResult.errorMessage);
            setup = fsjad.round28Setup( ...
                testCase.Project, testCase.AggregateFile, 1, "development");
            setup.cfg = oldSetup.cfg;
            setup.zhang = oldSetup.zhang;
            setup.ours = oldSetup.ours;
            setup.round27Protocol = oldSetup.protocol;
            setup.protocol.initialSpacingM = 0.2;
            setup.protocol.minimumIntervals = 10;
            setup.protocol.refinementLevels = 2;
            setup.protocol.peakCount = 3;
            setup.protocol.maxMusicPointsPerChunk = 16;
            result = fsjad.round28IncrementalTrial( ...
                setup, scan, row, oldResult, RunExpansion=false);

            testCase.verifyTrue(result.success, result.errorMessage);
            method = setup.protocol.methodIndex;
            testCase.verifyEqual(result.thetaDeg(method.Mw), ...
                oldResult.thetaDeg(oldSetup.protocol.methodIndex.C));
            testCase.verifyEqual(result.thetaDeg(method.Pw), ...
                result.thetaDeg(method.Mw));
            testCase.verifyEqual(result.wideIntervalM, ...
                [max(setup.cfg.rangeLimitsM(1), ...
                result.frozenCoarseRangeM-2), ...
                min(setup.cfg.rangeLimitsM(2), ...
                result.frozenCoarseRangeM+2)]);
            testCase.verifyLessThanOrEqual( ...
                result.subspaceValidation.maximumEigenvectorNormMismatch, ...
                1e-10);
        end
    end
end
