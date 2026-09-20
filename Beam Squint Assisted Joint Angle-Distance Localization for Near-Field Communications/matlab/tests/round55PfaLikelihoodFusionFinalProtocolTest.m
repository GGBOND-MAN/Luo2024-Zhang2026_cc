classdef round55PfaLikelihoodFusionFinalProtocolTest < matlab.unittest.TestCase
    %ROUND55PFALIKELIHOODFUSIONFINALPROTOCOLTEST R55 protocol tests.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDesignIsDeterministicAndBalanced(testCase)
            protocol = r55.config();
            first = r55.design(protocol);
            second = r55.design(protocol);
            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 1400);
            counts = groupcounts(first, "snrDb");
            testCase.verifyEqual(counts.GroupCount, 200*ones(7, 1));
        end

        function testFrozenDigestsMatch(testCase)
            protocol = r55.config();
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.verifyEqual(r32.sourceDigest(r53.manifest(project)), ...
                protocol.algorithm.r53SourceDigest);
            testCase.verifyEqual(r32.sourceDigest(r54.manifest(project)), ...
                protocol.algorithm.r54SourceDigest);
            testCase.verifyEqual(r32.sourceDigest(r45.manifest(project)), ...
                protocol.algorithm.pfaSourceDigest);
        end

        function testFinalGovernance(testCase)
            protocol = r55.config();
            testCase.verifyTrue(protocol.execution.oneFinalRunOnly);
            testCase.verifyTrue(protocol.execution.noAdditionalUsers);
            testCase.verifyTrue(protocol.execution.noMethodModification);
            testCase.verifyEqual(protocol.statistics.rangeNoninferiorityLimit, 1.02);
            testCase.verifyEqual(protocol.statistics.aggregateSuperiorityLimit, 1.0);
            testCase.verifyGreaterThan( ...
                protocol.complexity.rawLinearProjectionHours, 4.0);
        end

        function testLeanTrialPreservesPfaAngle(testCase)
            protocol = r55.config();
            design = r54.design(protocol.r54);
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            result = r55.finalTrial(cfg, scan, design(1, :), 1, protocol);
            testCase.verifyTrue(result.success, result.errorMessage);
            testCase.verifyEqual(result.P_FALF.thetaDeg, result.P_FA.thetaDeg);
            testCase.verifyEqual(result.angleIdentityDifferenceDeg, 0);
        end
    end
end
