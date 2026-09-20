classdef round34FinalEngineeringTest < matlab.unittest.TestCase
    %ROUND34FINALENGINEERINGTEST Frozen A-only and corrected-statistic tests.

    methods (Test)
        function finalEntryHasNoGramOption(testCase)
            protocol = r34.config();
            testCase.verifyTrue(protocol.implementation.useFastResponse);
            testCase.verifyFalse(protocol.implementation.useGram);
            testCase.verifyEqual(protocol.estimatorVersion, ...
                "R33-A-q-only-invariants-direct-EVD-v1");
            source = fileread(which("r34.estimate"));
            testCase.verifyTrue(contains(source, "UseGram=false"));
            testCase.verifyFalse(contains(source, "options.UseGram"));
        end

        function gramCostIsRejected(testCase)
            cost = directCost(3);
            cost.gramSuccessCount = 1;
            cost.directCount = 2;
            cost.method(1) = "smaller-gram-eig-recovery";
            testCase.verifyError( ...
                @() r34.assertAOnlyCost(cost, "fixture"), ...
                "r34:GramOrNonDirectSolverRejected");
        end

        function oldBootstrapExpressionCollapsesColumns(testCase)
            values = [1, 10; 2, 20; 4, 40];
            indices = [1, 1, 2, 3; 2, 3, 3, 1; 3, 2, 1, 2];
            old = squeeze(mean(values(indices, 2), 1));
            fixed = r34.clusterBootstrapMeans(values(:, 2), indices);
            explicit = zeros(size(indices, 2), 1);
            for bootstrap = 1:size(indices, 2)
                explicit(bootstrap) = mean( ...
                    values(indices(:, bootstrap), 2));
            end
            testCase.verifySize(old, [1, 1]);
            testCase.verifyEqual(fixed, explicit, AbsTol=0);
            testCase.verifyNotEqual(old, explicit);
        end

        function clusterBootstrapMatchesExplicitLoop(testCase)
            values = reshape(1:15, 5, 3);
            indices = [1, 5, 2, 3; 2, 4, 2, 1; 3, 3, 5, 5; ...
                4, 2, 4, 2; 5, 1, 1, 4];
            actual = r34.clusterBootstrapMeans(values, indices);
            expected = zeros(size(indices, 2), size(values, 2));
            for bootstrap = 1:size(indices, 2)
                expected(bootstrap, :) = mean( ...
                    values(indices(:, bootstrap), :), 1);
            end
            testCase.verifyEqual(actual, expected, AbsTol=0);
        end

        function identicalErrorsAndZeroVarianceAreHandled(testCase)
            [design, protocol] = syntheticDesign();
            results = syntheticResults(design, 0.1, 0.1, 0.2, 0.2);
            output = r34.summarizePaired(design, results, protocol);
            testCase.verifyEqual( ...
                output.primary.rangeMseDifferencePaMinusC, zeros(2, 1), ...
                AbsTol=1e-15);
            testCase.verifyEqual(output.primary.rangeSimultaneousUpper95, ...
                zeros(2, 1), AbsTol=1e-15);
            testCase.verifyFalse(any(output.primary.rangeSuperiorityPass));
            testCase.verifyEqual(output.primary.angleMseRatioPaOverC, ...
                ones(2, 1), AbsTol=1e-15);
            testCase.verifyTrue(all(output.primary.angleNoninferiorityPass));
        end

        function deliberateRangeBetterAndWorseAreSeparated(testCase)
            [design, protocol] = syntheticDesign();
            better = syntheticResults(design, 0.1, 0.1, 0.1, 0.2);
            worse = syntheticResults(design, 0.1, 0.1, 0.3, 0.2);
            betterOutput = r34.summarizePaired(design, better, protocol);
            worseOutput = r34.summarizePaired(design, worse, protocol);
            testCase.verifyTrue(all( ...
                betterOutput.primary.rangeSuperiorityPass));
            testCase.verifyFalse(any( ...
                worseOutput.primary.rangeSuperiorityPass));
        end

        function deliberateAngleBetterAndWorseAreSeparated(testCase)
            [design, protocol] = syntheticDesign();
            better = syntheticResults(design, 0.1, 0.2, 0.1, 0.2);
            worse = syntheticResults(design, 0.3, 0.2, 0.1, 0.2);
            betterOutput = r34.summarizePaired(design, better, protocol);
            worseOutput = r34.summarizePaired(design, worse, protocol);
            testCase.verifyEqual( ...
                betterOutput.primary.angleMseRatioPaOverC, ...
                0.25*ones(2, 1), AbsTol=1e-14);
            testCase.verifyTrue(all( ...
                betterOutput.primary.angleNoninferiorityPass));
            testCase.verifyEqual( ...
                worseOutput.primary.angleMseRatioPaOverC, ...
                2.25*ones(2, 1), RelTol=1e-14);
            testCase.verifyFalse(any( ...
                worseOutput.primary.angleNoninferiorityPass));
        end

        function oneClusterDrawIsSharedAcrossSnr(testCase)
            values = [(1:5).', (1:5).'];
            indices = [1, 5, 2; 2, 4, 2; 3, 3, 5; 4, 2, 4; 5, 1, 1];
            bootstrap = r34.clusterBootstrapMeans(values, indices);
            testCase.verifyEqual(bootstrap(:, 1), bootstrap(:, 2));
        end

        function zeroBaselineMseDoesNotCreateAClaim(testCase)
            [design, protocol] = syntheticDesign();
            results = syntheticResults(design, 0.1, 0, 0.1, 0.2);
            output = r34.summarizePaired(design, results, protocol);
            testCase.verifyFalse(any(output.primary.angleFamilyDefined));
            testCase.verifyFalse(any(output.primary.angleNoninferiorityPass));
            testCase.verifyTrue(all(isinf( ...
                output.primary.angleMseRatioPaOverC)));
        end

        function inputOrderDoesNotChangeInference(testCase)
            [design, protocol] = syntheticDesign();
            results = syntheticResults(design, 0.1, 0.12, 0.1, 0.2);
            reference = r34.summarizePaired(design, results, protocol);
            order = [8, 1, 6, 3, 5, 2, 7, 4];
            shuffled = r34.summarizePaired( ...
                design(order, :), results(order), protocol);
            testCase.verifyEqual(shuffled.primary, reference.primary);
            testCase.verifyEqual(sortrows(shuffled.summary, ...
                ["method", "snrDb"]), sortrows(reference.summary, ...
                ["method", "snrDb"]));
        end

        function missingDuplicateAndFailedRowsAreRejected(testCase)
            [design, protocol] = syntheticDesign();
            results = syntheticResults(design, 0.1, 0.1, 0.1, 0.2);
            missing = results;
            missing{end} = [];
            testCase.verifyError(@() r34.summarizePaired( ...
                design, missing, protocol), "r34:IncompleteFinalResults");

            duplicate = design;
            duplicate.positionId(2) = duplicate.positionId(1);
            duplicate.snrDb(2) = duplicate.snrDb(1);
            testCase.verifyError(@() r34.summarizePaired( ...
                duplicate, results, protocol), "r34:DuplicateFinalRows");

            failed = results;
            failed{3}.success = false;
            testCase.verifyError(@() r34.summarizePaired( ...
                design, failed, protocol), ...
                "r34:FinalFailuresRequireAudit");
        end

        function positionClustersStayOnOneFinalShard(testCase)
            protocol = r34.config();
            design = r32.finalTestDesign(protocol.r32);
            [first, firstRows] = r34.partitionDesign(design, 1, 2);
            [second, secondRows] = r34.partitionDesign(design, 2, 2);
            testCase.verifyEqual(height(first), 700);
            testCase.verifyEqual(height(second), 700);
            testCase.verifyEmpty(intersect(first.positionId, second.positionId));
            testCase.verifyEqual(sort([firstRows; secondRows]), ...
                (1:1400).');
            for snrDb = protocol.finalTest.snrDb
                testCase.verifyEqual(nnz(first.snrDb == snrDb), 100);
                testCase.verifyEqual(nnz(second.snrDb == snrDb), 100);
            end
        end

        function missingAuthorizationIsRejected(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            protocol = r34.config();
            identity = struct(designHash=protocol.finalTest.designHash, ...
                sourceDigest="source", protocol=protocol);
            testCase.verifyError(@() r34.assertFinalTestAuthorized( ...
                folder, identity), "r34:FinalTestNotAuthorized");
            testCase.verifyClass(cleanup, "onCleanup");
        end

        function checkpointRejectsIdentityDrift(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            [design, ~] = syntheticDesign();
            file = fullfile(folder, "checkpoint.mat");
            identity = struct(version="a", sourceDigest="x");
            results = cell(height(design), 1);
            hashes = cell(height(design), 1);
            environment = struct(role="test");
            r34.saveCheckpoint(file, identity, design, ...
                results, hashes, environment);
            changed = identity;
            changed.sourceDigest = "y";
            testCase.verifyError(@() r34.loadCheckpoint( ...
                file, changed, design), "r34:StaleOrInvalidCheckpoint");
            testCase.verifyClass(cleanup, "onCleanup");
        end
    end
end

function cost = directCost(carrierCount)
cost = struct(carrierCount=carrierCount, directCount=carrierCount, ...
    gramSuccessCount=0, fallbackCount=0, ...
    method=repmat("direct-smaller-side", carrierCount, 1));
end

function [design, protocol] = syntheticDesign()
protocol = r34.config();
protocol.finalTest.snrDb = [-10, 0];
protocol.statistics.bootstrapCount = 200;
positionId = repmat((1:4).', 2, 1);
snrDb = repelem([-10; 0], 4, 1);
truthThetaDeg = repmat([-20; -5; 10; 25], 2, 1);
truthRangeM = repmat([20; 25; 30; 35], 2, 1);
seed = (9001:9008).';
trialIndex = positionId;
design = table(positionId, truthThetaDeg, truthRangeM, ...
    snrDb, seed, trialIndex);
end

function results = syntheticResults( ...
    design, paAngleError, cAngleError, paRangeError, cRangeError)
methodNames = ["P_A", "C_enhanced", "H_A", "C_public", "F_L06"];
results = cell(height(design), 1);
for index = 1:height(design)
    angleSign = (-1)^index;
    rangeSign = (-1)^(index+1);
    item = struct(success=true, seed=design.seed(index), ...
        positionId=design.positionId(index), snrDb=design.snrDb(index), ...
        methodNames=methodNames, ...
        thetaDeg=design.truthThetaDeg(index) ...
        + angleSign*[paAngleError, cAngleError, 0.15, 0.2, 0.25], ...
        rangeM=design.truthRangeM(index) ...
        + rangeSign*[paRangeError, cRangeError, 0.25, 0.3, 0.35]);
    results{index} = item;
end
end
