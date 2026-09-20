classdef round52BasinConsistencyTest < matlab.unittest.TestCase
    %ROUND52BASINCONSISTENCYTEST Tests for frozen R52 interfaces.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDesignsAreDeterministic(testCase)
            protocol = r52.config();
            testCase.verifyEqual( ...
                r52.normalDesign(protocol), r52.normalDesign(protocol));
            testCase.verifyEqual(height(r52.normalDesign(protocol)), 90);
            testCase.verifyEqual(r52.stressPoolDesign(protocol), ...
                r52.stressPoolDesign(protocol));
            testCase.verifyEqual(height(r52.stressPoolDesign(protocol)), 600);
        end

        function testC3bRequiresBothSplitsOutsideFront(testCase)
            protocol = r52.config();
            front = struct(selected=struct(thetaDeg=0, rangeM=30));
            audit = table((1:3).', [0; 1; 2], [30; 35; 40], ...
                [0; 3; 1], [0; 2; 1], 'VariableNames', ...
                {'candidateIndex', 'thetaDeg', 'rangeM', ...
                'oddLogScore', 'evenLogScore'});
            certificate = struct(C1=false, C2=false, C3=false, C4=false, ...
                candidateAudit=audit, trigger=false);
            frozen = struct(certificate=certificate);
            result = r52.basinCertificate(front, frozen, protocol);
            testCase.verifyTrue(result.C3b);
            testCase.verifyTrue(result.trigger);
        end

        function testNaturalStressSelectionUsesFixedOrder(testCase)
            protocol = r52.config();
            pool = r52.stressPoolDesign(protocol);
            screening = cell(height(pool), 1);
            labels = repmat("none", height(pool), 1);
            labels(1:3) = "angle";
            labels(4:6) = "range";
            labels(7:9) = "joint";
            for index = 1:height(pool)
                screening{index} = struct(success=true, ...
                    supportClass=labels(index), ...
                    angleSupportMiss=labels(index) ~= "none" ...
                        && labels(index) ~= "range", ...
                    rangeSupportMiss=labels(index) ~= "none" ...
                        && labels(index) ~= "angle", ...
                    frontThetaDeg=0, frontRangeM=30);
            end
            selected = r52.selectStress(pool, screening, protocol);
            testCase.verifyTrue(selected.constructionPass);
            testCase.verifyEqual(selected.design.positionId, (1:9).');
        end

        function testProtocolPreservesFrozenEvidence(testCase)
            protocol = r52.config();
            testCase.verifyFalse(protocol.execution.finalRowsAccessible);
            testCase.verifyFalse(protocol.execution.calibrationAllowed);
            testCase.verifyFalse(protocol.execution.parameterTuningAllowed);
            testCase.verifyFalse(protocol.execution.modifyFrozenR51);
            testCase.verifyTrue(protocol.stressPool.fixedBudgetNoExtension);
        end
    end
end
