classdef round41ProtocolUnitTest < matlab.unittest.TestCase
    %ROUND41PROTOCOLUNITTEST Unit tests for frozen design and statistics.

    methods (Test)
        function designIsDeterministicAndBalanced(testCase)
            protocol = r41.config();
            first = r41.finalDesign(protocol);
            second = r41.finalDesign(protocol);
            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 1400);
            testCase.verifyEqual(numel(unique(first.positionId)), 200);
            testCase.verifyEqual(numel(unique(first.seed)), 1400);
            testCase.verifyEqual(numel(unique(first.positionSeed)), 200);
            for positionId = 1:200
                rows = first(first.positionId == positionId, :);
                testCase.verifyEqual(rows.snrDb.', protocol.design.snrDb);
                testCase.verifyEqual(numel(unique(rows.truthThetaDeg)), 1);
                testCase.verifyEqual(numel(unique(rows.truthRangeM)), 1);
            end
        end

        function shardsKeepCompleteClusters(testCase)
            design = r41.finalDesign();
            [first, firstRows] = r41.partitionDesign(design, 1);
            [second, secondRows] = r41.partitionDesign(design, 2);
            testCase.verifyEqual(height(first), 700);
            testCase.verifyEqual(height(second), 700);
            testCase.verifyEmpty(intersect(first.positionId, second.positionId));
            testCase.verifyEqual(firstRows, (1:700).');
            testCase.verifyEqual(secondRows, (701:1400).');
        end

        function sharedClusterBootstrapMatchesLoop(testCase)
            values = reshape(1:15, 5, 3);
            indices = [1, 5, 2; 2, 4, 2; 3, 3, 5; 4, 2, 4; 5, 1, 1];
            actual = r41.clusterBootstrapMeans(values, indices);
            expected = zeros(size(indices, 2), size(values, 2));
            for bootstrap = 1:size(indices, 2)
                expected(bootstrap, :) = mean( ...
                    values(indices(:, bootstrap), :), 1);
            end
            testCase.verifyEqual(actual, expected, AbsTol=0);
        end

        function zeroVarianceSimultaneousFamilyIsExact(testCase)
            observed = [-0.2, -0.1];
            bootstrap = repmat(observed, 50, 1);
            testCase.verifyEqual(r41.simultaneousUpper( ...
                observed, bootstrap, 0.95), observed, AbsTol=0);
        end

        function deliberateSuperiorityPassesBothFamilies(testCase)
            [design, results, protocol] = syntheticCase(0.1, 0.2, 0.1, 0.2);
            output = r41.summarizeFinal(design, results, protocol);
            testCase.verifyTrue(all(output.primaryFamilies.statisticallySuperior));
            testCase.verifyEqual(output.globalSecondary.observedRatio, ...
                [0.25; 0.25], AbsTol=1e-14);
            testCase.verifyTrue(all( ...
                output.globalSecondary.statisticallySuperior));
        end

        function failedTrialStopsPrimaryInference(testCase)
            [design, results, protocol] = syntheticCase(0.1, 0.2, 0.1, 0.2);
            results{3}.success = false;
            testCase.verifyError(@() r41.summarizeFinal( ...
                design, results, protocol), ...
                "r41:FinalFailuresStopPrimaryInference");
        end

        function unauthorizedRunIsRejected(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            identity = syntheticIdentity();
            testCase.verifyError(@() r41.assertAuthorized( ...
                folder, identity), "r41:FinalTestNotAuthorized");
            testCase.verifyClass(cleanup, "onCleanup");
        end

        function checkpointResumePreservesIdentity(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            file = fullfile(folder, "checkpoint.mat");
            design = table((1:4).', 'VariableNames', {'rowId'});
            identity = struct(version="a", sourceDigest="x", ...
                authorizationDigest="z");
            results = cell(4, 1);
            results{1} = struct(success=true);
            environment = struct(role="synthetic");
            r41.saveCheckpoint(file, identity, design, results, environment);
            [resumed, actualEnvironment] = r41.loadCheckpoint( ...
                file, identity, design);
            testCase.verifyFalse(isempty(resumed{1}));
            testCase.verifyTrue(all(cellfun(@isempty, resumed(2:4))));
            testCase.verifyEqual(actualEnvironment, environment);
            changed = identity;
            changed.sourceDigest = "changed";
            testCase.verifyError(@() r41.loadCheckpoint( ...
                file, changed, design), "r41:StaleOrInvalidCheckpoint");
            testCase.verifyClass(cleanup, "onCleanup");
        end

        function existingResultDirectoryIsRejected(testCase)
            project = string(tempname);
            mkdir(project);
            locations = r41.paths(project);
            mkdir(locations.executionFolder);
            cleanup = onCleanup(@() rmdir(project, "s"));
            testCase.verifyError(@() r41.assertExecutionTarget( ...
                project, 1, false), "r41:ExistingFinalResultDirectory");
            testCase.verifyClass(cleanup, "onCleanup");
        end
    end
end

function identity = syntheticIdentity()
identity = struct(protocolVersion="p", designHash="d", ...
    statisticsHash="s", sourceDigest="x", algorithmDigest="a", ...
    r33Digest="3", r34Digest="4", frozenDependencyDigest="f");
end

function [design, results, protocol] = syntheticCase( ...
    gAngle, cAngle, gRange, cRange)
protocol = r41.config();
protocol.design.positionCount = 4;
protocol.design.snrDb = [-10, 0];
protocol.design.expectedRows = 8;
protocol.design.expectedRowsPerShard = 4;
protocol.design.expectedPositionsPerShard = 2;
protocol.statistics.bootstrapCount = 200;
design = r41.finalDesign(protocol);
methods = ["G_schur", "C_enhanced", "P_A"];
results = cell(height(design), 1);
for index = 1:height(design)
    angleSign = (-1)^index;
    rangeSign = (-1)^(index+1);
    item = struct(success=true, positionId=design.positionId(index), ...
        seed=design.seed(index), snrDb=design.snrDb(index), ...
        methodNames=methods, ...
        thetaDeg=design.truthThetaDeg(index) ...
        +angleSign*[gAngle, cAngle, 0.15], ...
        rangeM=design.truthRangeM(index) ...
        +rangeSign*[gRange, cRange, 0.15], ...
        runtimeSeconds=[1, 2, 1], ...
        responseEquivalentCount=[10, 20, 8], ...
        musicEvaluationCount=[5, 6, 5], evdCount=[3, 3, 3], ...
        fullArrayEvaluationCount=[2, 0, 0], ...
        profilePassCount=[1, 0, 1], ...
        profileEvaluationCount=[4, 0, 4]);
    results{index} = item;
end
end
