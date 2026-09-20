classdef round29IntegrationTest < matlab.unittest.TestCase
    %ROUND29INTEGRATIONTEST Observation-only front, common backends, strict reuse.
    methods(TestClassSetup)
        function paths(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fileparts(fileparts(mfilename("fullpath")))));
        end
    end
    methods(Test)
        function checkpointRejectsSourceChange(testCase)
            a = struct(version="v1",cfg=1,design=[1,2],source="a");
            b = a; b.source = "b";
            testCase.verifyError(@()r29.assertIdentity(a,b),"r29:IdentityMismatch");
        end
        function checkpointRejectsConfigChange(testCase)
            a = struct(version="v1",cfg=1,design=[1,2],source="a");
            b = a; b.cfg = 2;
            testCase.verifyError(@()r29.assertIdentity(a,b),"r29:IdentityMismatch");
        end
        function checkpointRejectsDesignChange(testCase)
            a = struct(version="v1",cfg=1,design=[1,2],source="a");
            b = a; b.design = [2,1];
            testCase.verifyError(@()r29.assertIdentity(a,b),"r29:IdentityMismatch");
        end
        function generalFrontAndFreshMusicAreWired(testCase)
            [cfg,algorithm,protocol,scan,row] = fixture();
            result = r29.trial(cfg,algorithm,protocol,scan,row);
            testCase.assertTrue(result.success,result.errorMessage);
            testCase.verifyTrue(result.checks.sameSubspace);
            testCase.verifyTrue(result.checks.sameAngle);
            testCase.verifyTrue(result.checks.sameNarrowNodes);
            testCase.verifyTrue(result.checks.sameWideNodes);
            testCase.verifyFalse(any(startsWith(result.front.candidateBank.source,"v1_")));
            testCase.verifyEqual(result.frozen.coarseRangeM, ...
                result.front.selected.rangeM,AbsTol=1e-12);
            testCase.verifyEqual(result.thetaDeg(2),result.music.thetaDeg,AbsTol=1e-12);
            testCase.verifyEqual(result.solvers.Mw.intervalM, ...
                result.solvers.Pw.intervalM,AbsTol=1e-12);
            testCase.verifyGreaterThan(result.front.totalEvaluations,0);
        end
        function pilotSelectionIsNotErrorBased(testCase)
            project = string(fileparts(fileparts(mfilename("fullpath"))));
            setup = r29.setup(project,"pilot");
            testCase.verifyEqual(height(setup.design),60);
            testCase.verifyEqual(nnz(setup.design.snrDb==-10),20);
            testCase.verifyEqual(nnz(setup.design.snrDb==0),20);
            testCase.verifyEqual(nnz(setup.design.snrDb==20),20);
            testCase.verifyFalse(any(ismember(setup.design.seed, ...
                [36200034,36200114,36200073,36200127])));
        end
    end
end
function [cfg,algorithm,protocol,scan,row] = fixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 24; cfg.numSubcarriers = 33;
cfg.elementIndex = (0:23).'-11.5;
cfg.subarraySize = 12; cfg.numSubarrays = 13;
algorithm = struct(subarraySize=12,localHalfWidthDeg=0.2, ...
    localHalfWidthM=0.0025,gridSizes=[9,7,5],fusionCarrierCount=5);
protocol = r29.config();
protocol.peakCount = 2; protocol.initialSpacingM = 0.5;
protocol.refinementLevels = 1; protocol.maxIterations = 5;
protocol.angleOffsetsDeg = 0;
protocol.solver.InitialSpacingM = 0.5;
protocol.solver.MinimumIntervals = 4;
protocol.solver.RefinementLevels = 1;
protocol.solver.PeakCount = 2;
scan = fsjad.prepareScan(cfg);
row = table(99101,20,12.3,25.2, ...
    'VariableNames',{'seed','snrDb','truthThetaDeg','truthRangeM'});
end
