classdef localMusicLogScoreTest < matlab.unittest.TestCase
    %LOCALMUSICLOGSCORETEST Raw MUSIC scores are batch independent.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            sourceFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(sourceFolder));
        end
    end

    methods (Test)
        function frozenSubspaceMatchesLegacyBuilder(testCase)
            [cfg, snapshots, carrierIndex] = reducedObservation();
            legacy = jad.localMusicEstimate( ...
                cfg, snapshots, carrierIndex, 15.2, 30.3);
            frozen = jad.freezeLocalMusicSubspace( ...
                cfg, snapshots, carrierIndex, 15.2, 30.3);

            overlap = abs(sum(conj(legacy.signalVectors) ...
                .*frozen.signalVectors, 1));
            testCase.verifyEqual(overlap, ones(size(overlap)), ...
                AbsTol=2e-12);
        end

        function scalarBatchAndChunkScoresAgree(testCase)
            [cfg, snapshots, carrierIndex] = reducedObservation();
            frozen = jad.freezeLocalMusicSubspace( ...
                cfg, snapshots, carrierIndex, 15.2, 30.3);
            rangesM = linspace(29.8, 30.5, 17).';

            batch = jad.localMusicLogScore( ...
                cfg, frozen, 15.1, rangesM, MaxPointsPerChunk=100);
            chunked = jad.localMusicLogScore( ...
                cfg, frozen, 15.1, rangesM, MaxPointsPerChunk=3);
            scalar = arrayfun(@(rangeM) jad.localMusicLogScore( ...
                cfg, frozen, 15.1, rangeM), rangesM);

            testCase.verifyEqual(chunked, batch, AbsTol=1e-12);
            testCase.verifyEqual(scalar, batch, AbsTol=1e-12);
        end

        function rawArgmaxMatchesLegacyNormalizedGrid(testCase)
            [cfg, snapshots, carrierIndex] = reducedObservation();
            frozen = jad.freezeLocalMusicSubspace( ...
                cfg, snapshots, carrierIndex, 15.2, 30.3);
            thetaGridDeg = linspace(14.8, 15.4, 13);
            rangeGridM = linspace(29.7, 30.6, 19);
            legacy = jad.localMusicSpectrum(cfg, frozen.signalVectors, ...
                carrierIndex, thetaGridDeg, rangeGridM);
            [thetaMesh, rangeMesh] = meshgrid(thetaGridDeg, rangeGridM);
            raw = jad.localMusicLogScore( ...
                cfg, frozen, thetaMesh, rangeMesh, MaxPointsPerChunk=11);

            [~, legacyMaximum] = max(legacy, [], "all", "linear");
            [~, rawMaximum] = max(raw, [], "all", "linear");
            testCase.verifyEqual(rawMaximum, legacyMaximum);
            reconstructed = exp(raw-max(raw, [], "all"));
            testCase.verifyEqual(reconstructed, legacy, AbsTol=5e-13);
        end

        function oldSinglePointNormalizationDoesNotDefineObjective(testCase)
            [cfg, snapshots, carrierIndex] = reducedObservation();
            frozen = jad.freezeLocalMusicSubspace( ...
                cfg, snapshots, carrierIndex, 15.2, 30.3);
            first = jad.localMusicSpectrum( ...
                cfg, frozen.signalVectors, carrierIndex, 15.1, 29.9);
            second = jad.localMusicSpectrum( ...
                cfg, frozen.signalVectors, carrierIndex, 15.1, 30.4);
            raw = jad.localMusicLogScore( ...
                cfg, frozen, 15.1, [29.9, 30.4]);

            testCase.verifyEqual([first, second], [1, 1]);
            testCase.verifyGreaterThan(abs(diff(raw)), 1e-12);
        end
    end
end

function [cfg, snapshots, carrierIndex] = reducedObservation()
cfg = jad.defaultConfig();
cfg.numAntennas = 32;
cfg.subarraySize = 16;
cfg.numSubarrays = cfg.numAntennas-cfg.subarraySize+1;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
cfg.gridSizes = [11, 9, 7];
carrierIndex = [900; 1024; 1150];
stream = RandStream("mt19937ar", Seed=20260907);
snapshots = jad.simulateSnapshots( ...
    cfg, 15, 30, 25, carrierIndex, stream);
end
