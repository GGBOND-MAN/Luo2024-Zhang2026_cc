classdef round32FrozenPaTest < matlab.unittest.TestCase
    %ROUND32FROZENPATEST Software invariants for the finite P_A closeout.

    methods (Test)
        function frozenConfigurationIsExact(testCase)
            protocol = r32.config();
            testCase.verifyEqual(protocol.front.candidateId, "L06");
            testCase.verifyEqual(protocol.front.carrierCount, 513);
            testCase.verifyEqual(protocol.music.carrierCount, 2047);
            testCase.verifyEqual(protocol.music.subarraySize, 160);
            testCase.verifyEqual(protocol.music.numSubarrays, 97);
            testCase.verifyEqual(protocol.music.gridSizes, [41, 31, 21]);
            testCase.verifyEqual(protocol.music.angleHalfWidthDeg, 0.2);
            testCase.verifyEqual(protocol.profile.halfWidthM, 2);
            testCase.verifyEqual(protocol.profile.lambda, 1);
        end

        function independentEntryDoesNotCallControlC(testCase)
            file = which("r32.estimatePA");
            source = fileread(file);
            forbidden = ["r32.estimateC", "r30.runBaseline", ...
                "r31.stateFromBaseline", "controlC", "seed"];
            for token = forbidden
                testCase.verifyFalse(contains(source, token), ...
                    "Independent entry contains forbidden dependency: " + token);
            end
        end

        function haSourceDoesNotEvaluateProfile(testCase)
            source = fileread(which("r32.estimateHA"));
            testCase.verifyFalse(contains(source, "profileAtAngle"));
            testCase.verifyFalse(contains(source, "fixedAngleProfile"));
            testCase.verifyTrue(contains(source, "profileSeconds=0"));
        end

        function systemDriftIsRejected(testCase)
            cfg = jad.defaultConfig();
            cfg.numAntennas = 128;
            testCase.verifyError(@() r32.assertFrozenConfig(cfg), ...
                "r32:FrozenConfigurationMismatch");
        end

        function residualDelayPreservesPowerAndColumnProjectors(testCase)
            cfg = jad.defaultConfig();
            stream = RandStream("mt19937ar", Seed=321);
            z = randn(stream, cfg.numSubcarriers, 1) ...
                + 1i*randn(stream, cfg.numSubcarriers, 1);
            y = randn(stream, 3, cfg.numSubcarriers) ...
                + 1i*randn(stream, 3, cfg.numSubcarriers);
            [zd, yd] = r32.applyResidualDelay(cfg, z, y, 0.1e-9);
            testCase.verifyEqual(abs(zd).^2, abs(z).^2, AbsTol=1e-12);
            inner = sum(conj(y).*yd, 1)./(vecnorm(y).*vecnorm(yd));
            testCase.verifyLessThanOrEqual(max(abs(1-abs(inner).^2)), 1e-12);
        end

        function finalDesignIsPairedAndUnique(testCase)
            design = r32.finalTestDesign();
            testCase.verifyEqual(height(design), 1400);
            testCase.verifyEqual(numel(unique(design.seed)), 1400);
            testCase.verifyEqual(numel(unique(design.positionId)), 200);
            for id = [1, 100, 200]
                rows = design.positionId == id;
                testCase.verifyEqual(numel(unique(design.truthThetaDeg(rows))), 1);
                testCase.verifyEqual(numel(unique(design.truthRangeM(rows))), 1);
                testCase.verifyEqual(sort(design.snrDb(rows)).', -10:5:20);
            end
        end

        function designHashChangesWhenDesignChanges(testCase)
            design = r32.finalTestDesign();
            original = r32.designHash(design);
            design.truthRangeM(1) = design.truthRangeM(1)+1e-9;
            testCase.verifyNotEqual(r32.designHash(design), original);
        end

        function finalGateRejectsMissingAuthorization(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            identity = struct(designHash="x", sourceDigest="y", ...
                protocol=r32.config());
            testCase.verifyError( ...
                @() r32.assertFinalTestAuthorized(folder, identity), ...
                "r32:FinalTestNotAuthorized");
            testCase.verifyClass(cleanup, "onCleanup");
        end

        function sourceDigestDoesNotDependOnRowOrder(testCase)
            source = table(["b"; "a"], [2; 1], ["bb"; "aa"], ...
                'VariableNames', {'path', 'bytes', 'sha256'});
            testCase.verifyEqual(r32.sourceDigest(source), ...
                r32.sourceDigest(flipud(source)));
        end

        function frozenFinalInferenceUsesPositionClusters(testCase)
            protocol = r32.config();
            design = r32.finalTestDesign(protocol);
            results = cell(height(design), 1);
            for index = 1:height(design)
                angleError = 0.001*cos(design.positionId(index));
                rangeSign = sign(sin(design.positionId(index)));
                if rangeSign == 0
                    rangeSign = 1;
                end
                item.success = true;
                item.methodNames = ["P_A", "C_enhanced", "H_A", ...
                    "C_public", "F_L06"];
                item.thetaDeg = design.truthThetaDeg(index) ...
                    + angleError*ones(1, 5);
                item.rangeM = design.truthRangeM(index) ...
                    + rangeSign*[0.01, 0.02, 0.03, 0.04, 0.03];
                results{index} = item;
            end
            output = r32.summarizeFinal(design, results, protocol);
            testCase.verifySize(output.primary, [7, 7]);
            testCase.verifyTrue(all(output.primary.rangeSuperiorityPass));
            testCase.verifyTrue(all(output.primary.angleNoninferiorityPass));
            testCase.verifyEqual(output.primary.angleMseRatioPaOverC, ...
                ones(7, 1), AbsTol=1e-12);
        end
    end
end
