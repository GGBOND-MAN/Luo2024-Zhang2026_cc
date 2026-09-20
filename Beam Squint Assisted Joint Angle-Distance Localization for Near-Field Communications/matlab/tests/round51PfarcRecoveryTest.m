classdef round51PfarcRecoveryTest < matlab.unittest.TestCase
    %ROUND51PFARCRECOVERYTEST Tests for the frozen R51 interfaces.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDesignsAreDeterministic(testCase)
            protocol = r51.config();
            testCase.verifyEqual(r51.design(protocol), r51.design(protocol));
            testCase.verifyEqual(height(r51.design(protocol)), 60);
            testCase.verifyEqual( ...
                r51.stressDesign(protocol), r51.stressDesign(protocol));
            testCase.verifyEqual(height(r51.stressDesign(protocol)), 54);
        end

        function testStressOffsetsAreFrozenAndBalanced(testCase)
            protocol = r51.config();
            design = r51.stressDesign(protocol);
            testCase.verifyEqual(unique(design.stressSign), [-1; 1]);
            testCase.verifyEqual(unique(design.stressType), ...
                ["angle"; "joint"; "range"]);
            testCase.verifyEqual(protocol.stressDesign.angleOffsetDeg, 0.45);
            testCase.verifyEqual(protocol.stressDesign.rangeOffsetM, 3.0);
        end

        function testSpectrumSplitIsCompleteAndDisjoint(testCase)
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            observation = ones(cfg.numSubcarriers, 1);
            split = r51.splitContexts(cfg, observation, scan);
            allIndex = sort([split.oddCarrierIndex; split.evenCarrierIndex]);
            testCase.verifyEqual(allIndex, (0:cfg.numSubcarriers-1).');
            testCase.verifyEmpty(intersect( ...
                split.oddCarrierIndex, split.evenCarrierIndex));
        end

        function testProtocolForbidsFinalAndTuning(testCase)
            protocol = r51.config();
            testCase.verifyFalse(protocol.execution.finalRowsAccessible);
            testCase.verifyFalse(protocol.execution.calibrationAllowed);
            testCase.verifyFalse(protocol.execution.parameterTuningAllowed);
            testCase.verifyFalse(protocol.execution.modifyFrozenMethods);
            testCase.verifyTrue(protocol.method.paFree);
        end
    end
end
