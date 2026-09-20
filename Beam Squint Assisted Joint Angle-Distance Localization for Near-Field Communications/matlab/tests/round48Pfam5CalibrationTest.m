classdef round48Pfam5CalibrationTest < matlab.unittest.TestCase
    %ROUND48PFAM5CALIBRATIONTEST Tests for the frozen R48 calibration.

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
        function methodAndEvidenceBoundariesAreFrozen(testCase)
            protocol = r48.config();
            testCase.verifyEqual(protocol.method.primary, "P_FAM5");
            testCase.verifyFalse(protocol.execution.r46FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.parameterTuningAllowed);
            testCase.verifyEqual(protocol.bootstrap.hardUpperLimit, 1.0);
        end

        function designIsNewBalancedAndClustered(testCase)
            design = r48.design();
            counts = groupcounts(design, "snrDb");
            testCase.verifyEqual(height(design), 600);
            testCase.verifyEqual(counts.GroupCount, 200*ones(3, 1));
            testCase.verifyEqual(nnz(design.subset == "diagnostic60"), 60);
            testCase.verifyEqual(nnz(design.subset == "holdout540"), 540);
            testCase.verifyEqual(numel(unique(design.seed)), 600);
        end

        function bootstrapIsDeterministic(testCase)
            [perUser, protocol] = bootstrapFixture();
            first = r48.clusterBootstrap(perUser, protocol, 0);
            second = r48.clusterBootstrap(perUser, protocol, 0);
            testCase.verifyEqual(first.summary, second.summary);
            testCase.verifyEqual(first.summary.observedRatio, ...
                [0.99^2; (0.99/1.01)^2], AbsTol=1e-12);
            testCase.verifyTrue(all(first.summary.pass));
        end

        function backendSourceIsPaMusicAndEvdFree(testCase)
            source = lower(string(fileread(fullfile( ...
                testCase.MatlabRoot, "+r48", "backend.m"))));
            testCase.verifyFalse(contains(source, "r34.estimate"));
            testCase.verifyFalse(contains(source, "preparemusicstate"));
            testCase.verifyFalse(contains(source, "eig("));
        end
    end
end

function [perUser, protocol] = bootstrapFixture()
protocol = r48.config();
protocol.bootstrap.count = 100;
positionId = repelem((1:8).', 3, 1);
snrDb = repmat(protocol.design.snrDb(:), 8, 1);
rangeError_P_FAM5 = .99*ones(24, 1);
rangeError_P_A = ones(24, 1);
rangeError_P_FA = (1.01)*ones(24, 1);
perUser = table(positionId, snrDb, rangeError_P_FAM5, ...
    rangeError_P_A, rangeError_P_FA);
end
