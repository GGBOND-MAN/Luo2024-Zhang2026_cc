classdef round27ConvergenceTest < matlab.unittest.TestCase
    %ROUND27CONVERGENCETEST Solver stationarity and window diagnostics.
    methods (TestClassSetup)
        function addPath(testCase)
            project=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(project));
        end
    end
    methods (Test)
        function noiselessRecovery(testCase)
            [cfg,scan,z]=fixture();
            result=fsjad.refineProfileMonotone(cfg,z,15.002,30.002,scan);
            testCase.verifyTrue(result.converged);
            testCase.verifyEqual(result.thetaDeg,15,AbsTol=1e-4);
            testCase.verifyEqual(result.rangeM,30,AbsTol=1e-4);
            testCase.verifyGreaterThanOrEqual(min(diff(result.scoreHistory)),-1e-14);
            testCase.verifyEqual(result.linearSolver,"augmented-QR");
            testCase.verifySize(result.parameterHistory,[numel(result.scoreHistory),2]);
            testCase.verifySize(result.stationarityHistory,size(result.scoreHistory));
            testCase.verifyTrue(all(isfinite(result.stationarityHistory)));
        end
        function iterationLimitIsNotConvergence(testCase)
            [cfg,scan,z]=fixture();
            result=fsjad.refineProfileMonotone(cfg,z,15.3,30.2,scan,MaxIterations=1);
            testCase.verifyFalse(result.converged);
            testCase.verifyEqual(result.status,"iteration_limit");
        end
        function complexScalePreservesEstimate(testCase)
            [cfg,scan,z]=fixture();
            a=fsjad.refineProfileMonotone(cfg,z,15.002,30.002,scan);
            b=fsjad.refineProfileMonotone(cfg,3*exp(1i*0.5)*z,15.002,30.002,scan);
            testCase.verifyEqual(a.thetaDeg,b.thetaDeg,AbsTol=1e-7);
            testCase.verifyEqual(a.rangeM,b.rangeM,AbsTol=1e-7);
        end
        function continuationDoesNotDecreaseScore(testCase)
            [cfg,scan,z]=fixture();
            legacy=fsjad.angleMultistartProfileEstimate(cfg,z,scan,0);
            result=fsjad.convergedFrontEstimate(cfg,z,scan,legacy);
            testCase.verifyGreaterThanOrEqual(result.score,legacy.score-1e-12);
            testCase.verifyEqual(numel(result.startConverged),1);
        end
        function iterationContinuationIsStable(testCase)
            [cfg,scan,z]=fixture();
            short=fsjad.refineProfileMonotone(cfg,z,15.002,30.002,scan, ...
                MaxIterations=200);
            long=fsjad.refineProfileMonotone(cfg,z,15.002,30.002,scan, ...
                MaxIterations=400);
            testCase.verifyTrue(short.converged);
            testCase.verifyTrue(long.converged);
            testCase.verifyEqual(short.score,long.score,AbsTol=1e-12);
            testCase.verifyEqual(short.thetaDeg,long.thetaDeg,AbsTol=1e-8);
            testCase.verifyEqual(short.rangeM,long.rangeM,AbsTol=1e-8);
        end
        function zeroSignalRejected(testCase)
            [cfg,scan,z]=fixture();
            testCase.verifyError(@() fsjad.refineProfileMonotone( ...
                cfg,0*z,15,30,scan),"fsjad:MonotoneZeroEnergy");
        end
        function musicFixedWindowAndFlags(testCase)
            [cfg,~,~]=fixture();
            cfg.localHalfWidthDeg=0.02;
            cfg.localHalfWidthM=0.01;
            cfg.gridSizes=[9,7,5];
            k=[10;20;30];
            y=jad.simulateSnapshots(cfg,15,30.1,Inf,k,RandStream('mt19937ar',Seed=1));
            result=jad.localMusicEstimate(cfg,y,k,15,30,ConstrainToInitialWindow=true);
            testCase.verifyGreaterThanOrEqual(result.rangeM,29.99);
            testCase.verifyLessThanOrEqual(result.rangeM,30.01);
            testCase.verifyLessThanOrEqual(max([result.stages.rangeUpper]),30.01);
            testCase.verifyEqual(result.initialRangeBoundary,result.stages(1).rangeBoundary);
        end
    end
end

function [cfg,scan,z]=fixture()
cfg=jad.defaultConfig();
cfg.numAntennas=32;
cfg.numSubcarriers=65;
cfg.elementIndex=(0:31).'-15.5;
cfg.subarraySize=16;
cfg.numSubarrays=17;
scan=fsjad.prepareScan(cfg);
z=exp(1i*0.7)*fsjad.exactSpectralResponse(cfg,deg2rad(15),30,scan);
end
