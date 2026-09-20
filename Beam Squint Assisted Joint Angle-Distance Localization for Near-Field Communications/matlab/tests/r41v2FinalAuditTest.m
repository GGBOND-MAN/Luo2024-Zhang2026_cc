classdef r41v2FinalAuditTest < matlab.unittest.TestCase
    %R41V2FINALAUDITTEST Static and synthetic checks for final audit tooling.

    methods (Test)
        function auditCoversRequiredIdentities(testCase)
            source = string(fileread(which("audit_r41v2_schemeG_final")));
            required = ["exactly 1400 design rows", ...
                "exactly 200 positions", "exactly 200 rows per SNR", ...
                "zero duplicate position-SNR keys", ...
                "zero failed formal trials", "algorithmDigest", ...
                "designHash", "statisticsHash", "authorizationDigest", ...
                "frozenDependencyDigest", "observation_input_hashes.csv", ...
                "no Gram or subspace fallback path", ...
                "exact profile pass vector", ...
                "raw-to-aggregate metric recomputation", ...
                "bootstrap deterministic replay", ...
                "matched timing provenance identity"];
            for text = required
                testCase.verifyTrue(contains(source, text), text);
            end
        end

        function reportGeneratorUsesFrozenInterpretation(testCase)
            source = string(fileread(which("generate_r41v2_final_reports")));
            testCase.verifyTrue(contains(source, ...
                "analysis.interpretation.allowedClaim"));
            testCase.verifyTrue(contains(source, ...
                "analysis.interpretation.level"));
            testCase.verifyFalse(contains(source, "modify paper"));
        end

        function authorizationStillPrecedesTrial(testCase)
            source = string(fileread(which("run_r41v2_schemeG_final_shard")));
            authorizationPosition = strfind(source, "r41.assertAuthorized");
            scanPosition = strfind(source, "fsjad.prepareScan");
            trialPosition = strfind(source, "r41.finalTrial");
            testCase.verifyLessThan(authorizationPosition(1), scanPosition(1));
            testCase.verifyLessThan(authorizationPosition(1), trialPosition(1));
        end

        function auditAndReportsDoNotAlterTrialCore(testCase)
            project = projectRoot();
            v1 = r41.validateProtocolPackage(project);
            testCase.verifyEqual(v1.identity.sourceDigest, ...
                "5700bf99a29708045efb3ae5ee6c20f1422db663dba79e1229571f4fb906b162");
            testCase.verifyEqual(v1.identity.trialsExecuted, 0);
        end
    end
end

function project = projectRoot()
project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
addpath(fullfile(project, "experiments"));
end
