classdef round53PfaLikelihoodFusionTest < matlab.unittest.TestCase
    %ROUND53PFALIKELIHOODFUSIONTEST Tests for the frozen R53 interfaces.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDesignIsIndependentAndDeterministic(testCase)
            protocol = r53.config();
            first = r53.design(protocol);
            second = r53.design(protocol);
            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 90);
            testCase.verifyEqual(unique(first.snrDb, "stable"), [-10; 0; 20]);
        end

        function testStrictMlUsesOriginalObservationCounts(testCase)
            protocol = r53.config();
            design = r53.design(protocol);
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            replay = fsjad.replayRound27Data(cfg, scan, design(1, :));
            carrierIndex = r30.selectLocalCarriers(cfg.numSubcarriers, ...
                protocol.base.pfa.carrierCount, replay.peakCarrierIndex);
            context = r42.prepareContext(cfg, scan, replay.observation, ...
                replay.snapshots(:, carrierIndex+1), carrierIndex);
            state = r53.likelihoodState(cfg, context, ...
                design.truthThetaDeg(1), design.truthRangeM(1), protocol);
            testCase.verifyEqual(state.scalarCount, cfg.numSubcarriers);
            testCase.verifyEqual(state.arrayCount, ...
                cfg.numAntennas*numel(carrierIndex));
            testCase.verifyEqual(state.scoreJoint, ...
                state.scoreZ+state.scoreY, "AbsTol", 1e-10);
        end

        function testPfaAngleIsExactlyPreserved(testCase)
            protocol = r53.config();
            design = r53.design(protocol);
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            result = r53.trial(cfg, scan, design(1, :), 1, protocol);
            testCase.verifyTrue(result.success, result.errorMessage);
            testCase.verifyEqual(result.P_FALF.thetaDeg, result.P_FA.thetaDeg);
            testCase.verifyEqual(result.angleIdentityDifferenceDeg, 0);
        end

        function testProtocolCannotAccessFrozenEvidence(testCase)
            protocol = r53.config();
            testCase.verifyTrue(protocol.audit.statisticalModelGate);
            testCase.verifyFalse(protocol.execution.finalRowsAccessible);
            testCase.verifyFalse(protocol.execution.calibrationAllowed);
            testCase.verifyFalse(protocol.execution.priorR51R52RowsAccessible);
            testCase.verifyFalse(protocol.execution.parameterTuningAllowed);
            testCase.verifyFalse(protocol.execution.modifyFrozenPFA);
            testCase.verifyEqual(protocol.likelihood.scalarObservationCountRule, "M");
            testCase.verifyEqual(protocol.likelihood.arrayObservationCountRule, ...
                "N-times-K");
        end
    end
end
