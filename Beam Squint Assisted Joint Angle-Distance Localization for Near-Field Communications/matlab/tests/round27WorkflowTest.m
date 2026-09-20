classdef round27WorkflowTest < matlab.unittest.TestCase
    %ROUND27WORKFLOWTEST Protocol data separation and paired estimator wiring.
    properties
        Project
    end
    methods (TestClassSetup)
        function sourcePath(testCase)
            testCase.Project=string(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.Project));
        end
    end
    methods (Test)
        function calibrationOnly(testCase)
            setup=fsjad.round27Setup(testCase.Project,1000,"formal");
            testCase.verifyEqual(height(setup.design),3000);
            testCase.verifyTrue(all(setup.design.seed>36200000 & setup.design.seed<=36401000));
            testCase.verifyEqual(setup.protocol.version, ...
                "Round27-convergence-ablation-v3");
            testCase.verifyFalse(any(setup.protocol.methodNames== ...
                "zhang_declared_protocol"));
            testCase.verifyFalse(any(setup.protocol.comparisonNames== ...
                "Declared-minus-A"));
        end
        function shardsPartitionDesign(testCase)
            setup=fsjad.round27Setup(testCase.Project,10,"formal");
            first=setup.design(mod(setup.design.trialIndex-1,2)==0,:);
            second=setup.design(mod(setup.design.trialIndex-1,2)==1,:);
            testCase.verifyEmpty(intersect(first.seed,second.seed));
            testCase.verifyEqual(sort([first.seed;second.seed]),sort(setup.design.seed));
        end
        function sameAngleAblation(testCase)
            setup=fsjad.round27Setup(testCase.Project,1,"smoke");
            result=fsjad.round27Trial(setup,fsjad.prepareScan(setup.cfg),setup.design(3,:));
            testCase.verifyTrue(result.success,result.errorMessage);
            index=setup.protocol.methodIndex;
            testCase.verifyEqual(numel(result.thetaDeg),11);
            testCase.verifyEqual(result.thetaDeg(index.A), ...
                result.thetaDeg(index.B),AbsTol=1e-12);
            testCase.verifyEqual(result.thetaDeg(index.C), ...
                result.thetaDeg(index.D),AbsTol=1e-12);
            testCase.verifyEqual(result.thetaDeg(index.FsjadStable), ...
                result.thetaDeg(index.FsjadMusic),AbsTol=1e-12);
            testCase.verifyGreaterThanOrEqual(result.frontScoreGain,-1e-12);
        end
        function primaryComparisonsAreDeclared(testCase)
            setup=fsjad.round27Setup(testCase.Project,10,"formal");
            testCase.verifyTrue(any(setup.protocol.comparisonNames== ...
                "D-minus-C-primary"));
            testCase.verifyTrue(any(setup.protocol.comparisonNames=="D-minus-E"));
            primary=find(setup.protocol.comparisonNames=="D-minus-C-primary");
            index=setup.protocol.methodIndex;
            testCase.verifyEqual(setup.protocol.comparisonPairs(primary,:), ...
                [index.D,index.C]);
        end
        function excessiveCountRejected(testCase)
            testCase.verifyError(@() fsjad.round27Setup(testCase.Project,1001,"formal"), ...
                "fsjad:Round27CalibrationLimit");
        end
    end
end
