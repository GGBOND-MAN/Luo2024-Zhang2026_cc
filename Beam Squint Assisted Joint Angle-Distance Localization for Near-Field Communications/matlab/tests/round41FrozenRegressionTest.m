classdef round41FrozenRegressionTest < matlab.unittest.TestCase
    %ROUND41FROZENREGRESSIONTEST Regression locks for source and protocol.

    methods (Test)
        function schemeGDigestMatchesFrozenCandidate(testCase)
            project = projectRoot();
            actual = r32.sourceDigest(r41.schemeGManifest(project));
            testCase.verifyEqual(actual, ...
                "b1b823826a707591f49ada5ff6cb093683e3bcab2e2b8479334c20076aec02a4");
        end

        function packageIdentityAndCsvRemainExact(testCase)
            saved = r41.validateProtocolPackage(projectRoot());
            testCase.verifyFalse(saved.identity.authorized);
            testCase.verifyEqual(saved.identity.trialsExecuted, 0);
            testCase.verifyEqual(saved.identity.algorithmDigest, ...
                saved.protocol.algorithm.schemeGDigest);
        end

        function designHasNoHistoricalCollision(testCase)
            project = projectRoot();
            design = r41.finalDesign();
            audit = r41.historicalExclusionAudit(project, design);
            testCase.verifyTrue(all(audit.pass));
            testCase.verifyEqual(audit.overlapCount, zeros(height(audit), 1));
        end

        function frozenSystemRemainsCompatible(testCase)
            protocol = r41.config();
            testCase.verifyWarningFree(@() r41.validateFrozenSystem( ...
                jad.defaultConfig(), protocol));
            testCase.verifyFalse(protocol.r34.implementation.useGram);
            testCase.verifyEqual(protocol.schemeG.range.completeProfilePasses, 1);
            testCase.verifyEqual(protocol.schemeG.range.newCompleteProfilePasses, 0);
        end

        function finalWrapperUsesOnlyDeclaredMethods(testCase)
            source = fileread(which("r41.finalTrial"));
            testCase.verifyTrue(contains(source, ...
                '["G_schur", "C_enhanced", "P_A"]'));
            testCase.verifyTrue(contains(source, "r41.gFromPA"));
            testCase.verifyFalse(contains(source, "G_fixed"));
            testCase.verifyFalse(contains(source, "C_public"));
            testCase.verifyFalse(contains(source, "E_single"));
        end

        function authorizationPrecedesObservationGeneration(testCase)
            source = fileread(which("run_round41_schemeG_final_shard"));
            authorizationPosition = strfind(source, "r41.assertAuthorized");
            scanPosition = strfind(source, "fsjad.prepareScan");
            trialPosition = strfind(source, "r41.finalTrial");
            testCase.verifyLessThan(authorizationPosition(1), scanPosition(1));
            testCase.verifyLessThan(authorizationPosition(1), trialPosition(1));
        end

        function lockedStateHasNoAuthorizationOrResults(testCase)
            locations = r41.paths(projectRoot());
            testCase.verifyFalse(isfile(locations.authorizationFile));
            testCase.verifyFalse(isfolder(locations.executionFolder));
        end
    end
end

function project = projectRoot()
project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
end
