classdef round57CoherentRangeTest < matlab.unittest.TestCase
    %ROUND57COHERENTRANGETEST R57 protocol, identifiability and interface tests.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
            % IncludingSubfolders uses genpath, which skips +package
            % folders, so the frozen non-package implementation folders
            % are added explicitly exactly as r41.addPaths does.
            extra = [fullfile(project, "+r35", "common"); ...
                fullfile(project, "+r36", "common"); ...
                fullfile(project, "+r37", "singleProfile"); ...
                fullfile(project, "+r38", "common"); ...
                fullfile(project, "+r38", "schemeF"); ...
                fullfile(project, "+r40", "schemeG")];
            for index = 1:numel(extra)
                if isfolder(extra(index))
                    testCase.applyFixture( ...
                        matlab.unittest.fixtures.PathFixture(extra(index)));
                end
            end
        end
    end

    methods (Test)
        function testDesignIsDeterministicAndBalanced(testCase)
            protocol = r57.config();
            first = r57.design(protocol, "development");
            second = r57.design(protocol, "development");
            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 210);
            for snr = protocol.design.snrDb
                testCase.verifyEqual(sum(first.snrDb == snr), 30);
            end
            smoke = r57.design(protocol, "smoke");
            testCase.verifyEqual(height(smoke), 21);
            testCase.verifyEmpty(intersect(smoke.seed, first.seed));
        end

        function testFrozenDigestsMatch(testCase)
            protocol = r57.config();
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.verifyEqual(r32.sourceDigest(r53.manifest(project)), ...
                protocol.freeze.expectedR53Digest);
            testCase.verifyEqual(r32.sourceDigest(r45.manifest(project)), ...
                protocol.freeze.expectedPfaDigest);
        end

        function testCoarseSpacingIsSamplingTheoremDerived(testCase)
            protocol = r57.config();
            cfg = jad.defaultConfig();
            mainlobe = cfg.c/cfg.bandwidth;
            testCase.verifyEqual(protocol.profile.mainlobeM, mainlobe, ...
                "RelTol", 1e-12);
            testCase.verifyEqual(protocol.profile.coarseSpacingM, ...
                mainlobe/protocol.profile.samplesPerMainlobe, "RelTol", 1e-12);
            testCase.verifyLessThan(protocol.profile.coarseSpacingM, ...
                protocol.base.profile.coarseSpacingM);
        end

        function testPhaseBasisExcludesTheDelayDirection(testCase)
            % Theorem 3: the degree-1 direction is exactly collinear with the
            % range score, so no dispersion degree may equal 1, and the
            % retained basis must stay orthogonal to it.
            protocol = r57.config();
            testCase.verifyFalse(any(protocol.gain.dispersionDegrees == 1));
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            design = r57.design(protocol, "smoke");
            replay = fsjad.replayRound27Data(cfg, scan, design(1, :));
            carrierIndex = (0:protocol.base.base.pfa.carrierCount-1).';
            context = r42.prepareContext(cfg, scan, replay.observation, ...
                replay.snapshots(:, carrierIndex+1), carrierIndex);
            phaseBasis = r57.basis(context, protocol);
            testCase.verifyEqual(size(phaseBasis.dispersion, 2), ...
                numel(protocol.gain.dispersionDegrees));
            inner = phaseBasis.dispersion.'*phaseBasis.delayDirection;
            testCase.verifyLessThan(max(abs(inner)), 1e-10);
        end

        function testCoherentBoundBeatsFreeAlphaBound(testCase)
            % Theorem 2: the closed-form gain factor must exceed two orders of
            % magnitude over the physical support.
            protocol = r57.config();
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            design = r57.design(protocol, "smoke");
            replay = fsjad.replayRound27Data(cfg, scan, design(1, :));
            carrierIndex = (0:protocol.base.base.pfa.carrierCount-1).';
            context = r42.prepareContext(cfg, scan, replay.observation, ...
                replay.snapshots(:, carrierIndex+1), carrierIndex);
            bound = r57.crlb(cfg, context, 20, 25, -10);
            testCase.verifyGreaterThan(bound.gainFactor, 100);
            testCase.verifyLessThan(bound.coherentStdM, bound.freeAlphaStdM);
        end

        function testOneRowPreservesAngleAndBeatsPFALF(testCase)
            protocol = r57.config();
            design = r57.design(protocol, "smoke");
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            result = r57.trial(cfg, scan, design(1, :), 1, protocol);
            testCase.verifyTrue(result.success, result.errorMessage);
            for method = ["P_FALF", "P_FACR", "P_FACR_A", "P_FACR_D", ...
                    "P_FACR_T", "P_FACR_Yonly"]
                testCase.verifyEqual(result.(method).thetaDeg, ...
                    result.P_FA.thetaDeg);
            end
            testCase.verifyEqual(result.angleIdentityDifferenceDeg, 0);
            testCase.verifyLessThan( ...
                abs(result.P_FACR.rangeM-result.truthRangeM), ...
                abs(result.P_FALF.rangeM-result.truthRangeM));
        end

        function testFreeDelayBranchCollapsesToFreeAlpha(testCase)
            % Theorem 1: profiling a free delay removes exactly what a free
            % per-carrier gain removes, so P_FACR_T must land near P_FALF and
            % far from P_FACR.
            protocol = r57.config();
            design = r57.design(protocol, "smoke");
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            result = r57.trial(cfg, scan, design(1, :), 1, protocol);
            testCase.verifyTrue(result.success, result.errorMessage);
            tauToFalf = abs(result.P_FACR_T.rangeM-result.P_FALF.rangeM);
            tauToCoherent = abs(result.P_FACR_T.rangeM-result.P_FACR.rangeM);
            testCase.verifyLessThan(tauToFalf, tauToCoherent);
        end

        function testGateLimitsAreNotWeakenedRelativeToR56(testCase)
            protocol = r57.config();
            testCase.verifyEqual( ...
                protocol.gate.maxAngleIdentityDifferenceDeg, 0);
            testCase.verifyLessThan( ...
                protocol.gate.maxAggregateRangeMseRatioToPA, 1);
            testCase.verifyLessThan( ...
                protocol.gate.maxP95AbsRangeRatioToPFALF, 1);
            testCase.verifyFalse(protocol.gain.fusionWeightAllowed);
            testCase.verifyFalse(protocol.gain.thresholdAllowed);
            testCase.verifyFalse(protocol.gain.selectorAllowed);
            testCase.verifyFalse(protocol.gain.snrRuleAllowed);
            testCase.verifyFalse(protocol.gain.truthAllowed);
        end
    end
end
