classdef round24ConfirmatoryTest < matlab.unittest.TestCase
    %ROUND24CONFIRMATORYTEST Tests the locked distributed protocol.

    methods (TestClassSetup)
        function addPaths(testCase)
            matlabFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                matlabFolder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabFolder, "algorithms", "compressed")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(matlabFolder, "algorithms", ...
                "zhang_reproduction")));
        end
    end

    methods (Test)
        function testTwoShardsAreDisjointAndComplete(testCase)
            first = fsjad.round24ConfirmatoryDesign(1, 2, 10);
            second = fsjad.round24ConfirmatoryDesign(2, 2, 10);
            combined = sortrows([first; second], ...
                ["snrDb", "trialIndex"]);

            testCase.verifyEqual(height(first), 15);
            testCase.verifyEqual(height(second), 15);
            testCase.verifyEqual(height(unique(combined(:, ...
                ["snrDb", "trialIndex"]), "rows")), 30);
            for snrDb = [-10, 0, 20]
                chosen = combined.snrDb == snrDb;
                testCase.verifyEqual(combined.trialIndex(chosen), ...
                    (1:10).');
            end
            testCase.verifyEqual(numel(unique(combined.seed)), 30);
        end

        function testDesignIsDeterministic(testCase)
            first = fsjad.round24ConfirmatoryDesign(1, 2, 20);
            second = fsjad.round24ConfirmatoryDesign(1, 2, 20);

            testCase.verifyEqual(first, second);
        end

        function testEffectiveRound23MethodIsExplicit(testCase)
            algorithm = fsjadRound23ComparisonConfig();

            testCase.verifyEqual(algorithm.version, ...
                "FSJAD-Compressed-R23-comparison-locked");
            testCase.verifyEqual(algorithm.fusionCarrierCount, 513);
            testCase.verifyEqual(algorithm.subarraySize, 96);
            testCase.verifyEqual(algorithm.localHalfWidthDeg, 0.02, ...
                AbsTol=1e-12);
            testCase.verifyEqual(algorithm.localHalfWidthM, 0.02, ...
                AbsTol=1e-12);
            testCase.verifyEqual(algorithm.gridSizes, [37, 27, 19]);
            testCase.verifyEqual(algorithm.profileSpacingM, 0.15, ...
                AbsTol=1e-12);
            testCase.verifyEqual(algorithm.profileLambda, 0.9, ...
                AbsTol=1e-12);
        end

        function testFsjadJointSpaceIsDeterministic(testCase)
            [first, firstLevels] = fsjadJointSearchSpace();
            [second, secondLevels] = fsjadJointSearchSpace();

            testCase.verifyEqual(first, second);
            testCase.verifyEqual(firstLevels, secondLevels);
            testCase.verifyEqual(height(first), 136);
            testCase.verifyEqual(firstLevels.fullDiscreteSpaceCount, ...
                7112448);
        end

        function testFsjadJointSpaceCoversEveryLevel(testCase)
            [candidates, levels] = fsjadJointSearchSpace();

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
            testCase.verifyEqual(unique(candidates.profileHalfWidthM).', ...
                levels.profileHalfWidthM, AbsTol=1e-12);
            testCase.verifyEqual(unique(candidates.profileSpacingM).', ...
                levels.profileSpacingM, AbsTol=1e-12);
            testCase.verifyEqual(unique(candidates.profileLambda).', ...
                levels.profileLambda, AbsTol=1e-12);
            testCase.verifyTrue(all(candidates.profileSpacingM ...
                <= candidates.profileHalfWidthM));
        end

        function testFsjadJointSpaceContainsCurrentBaseline(testCase)
            candidates = fsjadJointSearchSpace();
            baseline = fsjadRound23ComparisonConfig();
            expectedGrid = strjoin(string(baseline.gridSizes), "/");

            matched = candidates.fusionCarrierCount ...
                == baseline.fusionCarrierCount ...
                & candidates.subarraySize == baseline.subarraySize ...
                & abs(candidates.angleHalfWidthDeg ...
                - baseline.localHalfWidthDeg) < 1e-12 ...
                & abs(candidates.rangeHalfWidthM ...
                - baseline.localHalfWidthM) < 1e-12 ...
                & candidates.gridLevels == expectedGrid ...
                & abs(candidates.profileHalfWidthM ...
                - baseline.profileHalfWidthM) < 1e-12 ...
                & abs(candidates.profileSpacingM ...
                - baseline.profileSpacingM) < 1e-12 ...
                & abs(candidates.profileLambda ...
                - baseline.profileLambda) < 1e-12;

            testCase.verifyEqual(sum(matched), 1);
        end
    end
end
