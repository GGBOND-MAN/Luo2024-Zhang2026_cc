classdef round46PfaFinalProtocolTest < matlab.unittest.TestCase
    %ROUND46PFAFINALPROTOCOLTEST Tests without generating final observations.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            folders = [testCase.MatlabRoot; ...
                fullfile(testCase.MatlabRoot, "+r35", "common"); ...
                fullfile(testCase.MatlabRoot, "+r36", "common"); ...
                fullfile(testCase.MatlabRoot, "+r37", "singleProfile"); ...
                fullfile(testCase.MatlabRoot, "+r38", "common"); ...
                fullfile(testCase.MatlabRoot, "+r38", "schemeF"); ...
                fullfile(testCase.MatlabRoot, "+r40", "schemeG")];
            for index = 1:numel(folders)
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                    folders(index)));
            end
        end
    end

    methods (Test)
        function protocolIsLockedAndBonferroniControlled(testCase)
            protocol = r46.config();
            testCase.verifyFalse(protocol.execution.authorized);
            testCase.verifyEqual(protocol.execution.trialsExecuted, 0);
            testCase.verifyEqual(protocol.statistics.familyConfidence, 0.975);
            testCase.verifyEqual(protocol.statistics.angleLimit, 1.0);
            testCase.verifyEqual(protocol.statistics.rangeLimit, 1.02);
            testCase.verifyEqual(protocol.design.expectedRows, 1400);
        end

        function designIsBalancedUniqueAndDeterministic(testCase)
            protocol = r46.config();
            first = r46.design(protocol);
            second = r46.design(protocol);
            counts = groupcounts(first, "snrDb");
            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 1400);
            testCase.verifyEqual(numel(unique(first.positionId)), 200);
            testCase.verifyEqual(numel(unique(first.seed)), 1400);
            testCase.verifyEqual(counts.GroupCount, 200*ones(7, 1));
        end

        function calibrationSourceRemainsFrozen(testCase)
            protocol = r46.config();
            digest = r32.sourceDigest(r45.manifest(testCase.MatlabRoot));
            testCase.verifyEqual(digest, ...
                protocol.algorithm.calibrationSourceDigest);
        end

        function bootstrapIsDeterministicAndPassesSyntheticCase(testCase)
            [perUser, protocol] = bootstrapFixture();
            first = r46.clusterBootstrap(perUser, protocol);
            second = r46.clusterBootstrap(perUser, protocol);
            testCase.verifyEqual(first.angleFamily, second.angleFamily);
            testCase.verifyEqual(first.rangeFamily, second.rangeFamily);
            testCase.verifyEqual(first.angleFamily.observedRatio, ...
                0.25*ones(7, 1), AbsTol=1e-12);
            testCase.verifyEqual(first.rangeFamily.observedRatio, ...
                1.010025*ones(7, 1), AbsTol=1e-12);
            testCase.verifyTrue(first.primaryPass);
        end

        function summaryBuildsCoPrimaryDecision(testCase)
            [design, results, protocol] = summaryFixture();
            summary = r46.summarize(design, results, protocol);
            testCase.verifyEqual(height(summary.bootstrap.angleFamily), 7);
            testCase.verifyEqual(height(summary.bootstrap.rangeFamily), 7);
            testCase.verifyTrue(summary.decision.angleFamilyPass);
            testCase.verifyTrue(summary.decision.rangeFamilyPass);
            testCase.verifyTrue(summary.decision.identityPass);
            testCase.verifyTrue(summary.primaryPass);
        end

        function missingAuthorizationIsRejected(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            identity = struct();
            testCase.verifyError(@() r46.assertAuthorized(folder, identity), ...
                "r46:FinalTestNotAuthorized");
        end
    end
end

function [perUser, protocol] = bootstrapFixture()
protocol = r46.config();
protocol.statistics.bootstrapCount = 100;
positionId = repelem((1:10).', 7, 1);
snrDb = repmat(protocol.design.snrDb(:), 10, 1);
angleError_P_FA = 0.5*ones(70, 1);
angleError_P_A = ones(70, 1);
rangeError_P_FA = 1.005*ones(70, 1);
rangeError_P_A = ones(70, 1);
perUser = table(positionId, snrDb, angleError_P_FA, angleError_P_A, ...
    rangeError_P_FA, rangeError_P_A);
end

function [design, results, protocol] = summaryFixture()
protocol = r46.config();
protocol.statistics.bootstrapCount = 100;
protocol.design.positionCount = 10;
protocol.design.expectedRows = 70;
positionId = repelem((1:10).', 7, 1);
seed = (1:70).';
trialIndex = seed;
snrDb = repmat(protocol.design.snrDb(:), 10, 1);
truthThetaDeg = zeros(70, 1);
truthRangeM = 25*ones(70, 1);
design = table(positionId, seed, trialIndex, snrDb, ...
    truthThetaDeg, truthRangeM);
results = cell(70, 1);
for index = 1:70
    results{index} = syntheticResult(index);
end
end

function result = syntheticResult(index)
signValue = 2*mod(index, 2)-1;
result = struct(success=true, ...
    P_FA=struct(thetaDeg=0.5*signValue, rangeM=25+1.005*signValue), ...
    P_A=struct(thetaDeg=1.0*signValue, rangeM=25+1.0*signValue), ...
    G_schur=struct(thetaDeg=0.7*signValue, rangeM=25+1.002*signValue), ...
    C_enhanced=struct(thetaDeg=1.1*signValue, rangeM=25+1.2*signValue), ...
    pfaDiagnostics=struct( ...
        profile=struct(endpointHit=false, nearBoundary=false), ...
        angle=struct(retentionMargin=0), ...
        fullArrayEvaluationCount=47, profileEvaluationCount=140), ...
    sharedAudit=struct(totalDirectEvdCount=2052, ...
        totalGramCount=0, totalFallbackCount=0));
end
