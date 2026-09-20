classdef round56QAnchoredSplitConsensusTest < matlab.unittest.TestCase
    %ROUND56QANCHOREDSPLITCONSENSUSTEST R56 protocol and interface tests.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDesignIsDeterministicAndBalanced(testCase)
            protocol = r56.config();
            first = r56.design(protocol);
            second = r56.design(protocol);
            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 210);
            for snr = protocol.design.snrDb
                testCase.verifyEqual(sum(first.snrDb == snr), 30);
            end
        end

        function testFrozenDigestsMatch(testCase)
            protocol = r56.config();
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.verifyEqual(r32.sourceDigest(r53.manifest(project)), ...
                protocol.freeze.expectedR53Digest);
            testCase.verifyEqual(r32.sourceDigest(r45.manifest(project)), ...
                protocol.freeze.expectedPfaDigest);
        end

        function testOneRowPreservesAngleAndCandidateSupport(testCase)
            protocol = r56.config();
            design = r56.design(protocol);
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            result = r56.trial(cfg, scan, design(1, :), 1, protocol);
            testCase.verifyTrue(result.success, result.errorMessage);
            testCase.verifyEqual(result.P_FALF_SC.thetaDeg, ...
                result.P_FA.thetaDeg);
            testCase.verifyEqual(result.P_FALF_QB.thetaDeg, ...
                result.P_FA.thetaDeg);
            testCase.verifyGreaterThanOrEqual(result.selectedCandidateIndex, 1);
            testCase.verifyLessThanOrEqual(result.selectedCandidateIndex, ...
                protocol.base.profile.peakCount);
        end

        function testDevelopmentGovernance(testCase)
            protocol = r56.config();
            testCase.verifyFalse(protocol.execution.finalRowsAccessible);
            testCase.verifyFalse(protocol.execution.R53R54R55RowsAccessible);
            testCase.verifyFalse(protocol.execution.parameterTuningAllowed);
            testCase.verifyFalse(protocol.execution.calibrationAllowed);
            testCase.verifyTrue(protocol.execution.stopAfterDevelopment);
            testCase.verifyFalse(protocol.anchor.scoreThresholdAllowed);
            testCase.verifyFalse(protocol.anchor.learnedSelectorAllowed);
            testCase.verifyFalse(protocol.anchor.truthAllowed);
            testCase.verifyTrue(protocol.method.paFree);
        end
    end
end
