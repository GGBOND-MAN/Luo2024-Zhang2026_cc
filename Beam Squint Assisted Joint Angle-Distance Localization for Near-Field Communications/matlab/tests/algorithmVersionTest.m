classdef algorithmVersionTest < matlab.unittest.TestCase
    %ALGORITHMVERSIONTEST Tests isolated full and compressed versions.

    methods (TestClassSetup)
        function addAlgorithmPaths(testCase)
            matlabFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                matlabFolder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabFolder, "algorithms", "full")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabFolder, "algorithms", "compressed")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabFolder, "algorithms", ...
                "zhang_reproduction")));
        end
    end

    methods (Test)
        function testFullVersionIsFrozen(testCase)
            algorithm = fsjadFullConfig();

            testCase.verifyEqual(algorithm.version, ...
                "FSJAD-Full-513-v1");
            testCase.verifyEqual(algorithm.fusionCarrierCount, 513);
            testCase.verifyEqual(algorithm.gridSizes, [61, 41, 31]);
            testCase.verifyEqual(algorithm.profileHalfWidthM, 1, ...
                AbsTol=1e-12);
            testCase.verifyEqual(algorithm.profileSpacingM, 0.1, ...
                AbsTol=1e-12);
            testCase.verifyEqual(algorithm.profileLambda, 0.9, ...
                AbsTol=1e-12);
        end

        function testCompressedVersionIsIndependent(testCase)
            fullAlgorithm = fsjadFullConfig();
            compressedAlgorithm = fsjadCompressedConfig();

            testCase.verifyNotEqual(compressedAlgorithm.version, ...
                fullAlgorithm.version);
            testCase.verifyEqual(compressedAlgorithm.gridSizes, ...
                [37, 27, 19]);
            testCase.verifyEqual(compressedAlgorithm.fusionCarrierCount, ...
                513);
            testCase.verifyEqual(compressedAlgorithm.profileSpacingM, ...
                0.15, AbsTol=1e-12);
        end

        function testZhangVersionsAreExplicit(testCase)
            frozen = zhangEf513Config();
            tuned = zhangEfR22TunedConfig();

            testCase.verifyEqual(frozen.version, "Zhang-EF-513-v1");
            testCase.verifyEqual(frozen.fusionCarrierCount, 513);
            testCase.verifyEqual(frozen.gridSizes, [61, 41, 31]);
            testCase.verifyEqual(tuned.version, "Zhang-EF-R22-tuned");
            testCase.verifyEqual(tuned.fusionCarrierCount, 385);
            testCase.verifyEqual(tuned.gridSizes, [49, 35, 25]);
        end

        function testZhangJointSpaceIsDeterministic(testCase)
            [first, firstLevels] = zhangJointSearchSpace();
            [second, secondLevels] = zhangJointSearchSpace();

            testCase.verifyEqual(first, second);
            testCase.verifyEqual(firstLevels, secondLevels);
            testCase.verifyGreaterThanOrEqual(height(first), 128);
        end

        function testZhangJointSpaceCoversEveryLevel(testCase)
            [candidates, levels] = zhangJointSearchSpace();

            testCase.verifyEqual(unique(candidates.fusionCarrierCount).', ...
                levels.fusionCarrierCount);
            testCase.verifyEqual(unique(candidates.subarraySize).', ...
                levels.subarraySize);
            testCase.verifyEqual(unique(candidates.angleHalfWidthDeg).', ...
                levels.angleHalfWidthDeg, AbsTol=1e-12);
            testCase.verifyEqual(unique(candidates.rangeHalfWidthM).', ...
                levels.rangeHalfWidthM, AbsTol=1e-12);
            testCase.verifyEqual(unique(candidates.gridIndex).', ...
                1:numel(levels.gridSizes));
        end

        function testZhangJointSpaceContainsFrozenBaseline(testCase)
            candidates = zhangJointSearchSpace();
            frozen = zhangEf513Config();
            expectedGrid = strjoin(string(frozen.gridSizes), "/");

            matched = candidates.fusionCarrierCount ...
                == frozen.fusionCarrierCount ...
                & candidates.subarraySize == frozen.subarraySize ...
                & abs(candidates.angleHalfWidthDeg ...
                - frozen.localHalfWidthDeg) < 1e-12 ...
                & abs(candidates.rangeHalfWidthM ...
                - frozen.localHalfWidthM) < 1e-12 ...
                & candidates.gridLevels == expectedGrid;

            testCase.verifyEqual(sum(matched), 1);
        end

        function testZhangJointMcVersionIsLocked(testCase)
            algorithm = zhangEfJointMcR23Config();

            testCase.verifyEqual(algorithm.version, ...
                "Zhang-EF-JointMC-R23-locked");
            testCase.verifyEqual(algorithm.fusionCarrierCount, 1025);
            testCase.verifyEqual(algorithm.subarraySize, 224);
            testCase.verifyEqual(algorithm.localHalfWidthDeg, 0.1, ...
                AbsTol=1e-12);
            testCase.verifyEqual(algorithm.localHalfWidthM, 0.0025, ...
                AbsTol=1e-12);
            testCase.verifyEqual(algorithm.gridSizes, [37, 27, 19]);
        end
    end
end
