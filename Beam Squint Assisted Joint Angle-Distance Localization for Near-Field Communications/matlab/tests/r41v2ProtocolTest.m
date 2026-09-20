classdef r41v2ProtocolTest < matlab.unittest.TestCase
    %R41V2PROTOCOLTEST Verify v1 archive and v2 locked package identity.

    methods (Test)
        function v1RemainsValidAndUnchanged(testCase)
            v1 = r41.validateProtocolPackage(projectRoot());
            testCase.verifyEqual(v1.identity.statisticsVersion, ...
                "R41-position-cluster-bootstrap-superiority-v1");
            testCase.verifyEqual(v1.identity.statisticsHash, ...
                "112009eca7e02688f355edde944b7cd125be38bcaaa05da4af8d180be2da423c");
            testCase.verifyEqual(v1.identity.sourceDigest, ...
                "5700bf99a29708045efb3ae5ee6c20f1422db663dba79e1229571f4fb906b162");
        end

        function v2PackageValidates(testCase)
            saved = r41statsv2.validateProtocolPackage(projectRoot());
            testCase.verifyEqual(saved.identity.statisticsVersion, ...
                "R41-position-cluster-bootstrap-superiority-v2");
            testCase.verifyEqual(saved.identity.designHash, ...
                "a50ad0b244b5f5dba36f3b6322093f30908c99e34f86e17898557d6b17dfe374");
            testCase.verifyEqual(saved.identity.algorithmDigest, ...
                "b1b823826a707591f49ada5ff6cb093683e3bcab2e2b8479334c20076aec02a4");
            testCase.verifyFalse(saved.identity.authorized);
            testCase.verifyEqual(saved.identity.trialsExecuted, 0);
        end

        function v1AndV2DesignFilesAreByteIdentical(testCase)
            project = projectRoot();
            v1 = r41.paths(project);
            v2 = r41statsv2.paths(project);
            first = fsjad.sourceHashManifest(project, replace(extractAfter( ...
                v1.designFile, strlength(project)+1), string(filesep), "/"));
            second = fsjad.sourceHashManifest(project, replace(extractAfter( ...
                v2.designFile, strlength(project)+1), string(filesep), "/"));
            testCase.verifyEqual(second.sha256, first.sha256);
            testCase.verifyEqual(second.bytes, first.bytes);
        end

        function dependenciesAndExecutionCoreRemainV1(testCase)
            project = projectRoot();
            v1 = r41.validateProtocolPackage(project);
            v2 = r41statsv2.validateProtocolPackage(project);
            testCase.verifyEqual(v2.identity.r33Digest, v1.identity.r33Digest);
            testCase.verifyEqual(v2.identity.r34Digest, v1.identity.r34Digest);
            testCase.verifyEqual(v2.identity.frozenDependencyDigest, ...
                v1.identity.frozenDependencyDigest);
            testCase.verifyEqual(v2.identity.inheritedV1SourceDigest, ...
                v1.identity.sourceDigest);
            source = fileread(which("run_r41v2_schemeG_final_shard"));
            testCase.verifyTrue(contains(source, "r41.finalTrial"));
            testCase.verifyTrue(contains(source, "r41.partitionDesign"));
            testCase.verifyTrue(contains(source, "r41.saveCheckpoint"));
        end

        function authorizationStateIsValidAndFinalOutputsRemainAbsent(testCase)
            project = projectRoot();
            v1 = r41.paths(project);
            v2 = r41statsv2.paths(project);
            testCase.verifyFalse(isfile(v1.authorizationFile));
            testCase.verifyFalse(isfolder(v1.executionFolder));
            testCase.verifyFalse(isfolder(v2.executionFolder));
            if isfile(v2.authorizationFile)
                saved = r41statsv2.validateProtocolPackage(project);
                authorization = r41.assertAuthorized( ...
                    v2.protocolFolder, saved.identity);
                testCase.verifyTrue(authorization.approved);
            end
        end
    end
end

function project = projectRoot()
project = string(fileparts(fileparts(mfilename("fullpath"))));
r41.addPaths(project);
addpath(fullfile(project, "experiments"));
end
