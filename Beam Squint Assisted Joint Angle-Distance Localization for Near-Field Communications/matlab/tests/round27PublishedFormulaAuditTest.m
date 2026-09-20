classdef round27PublishedFormulaAuditTest < matlab.unittest.TestCase
    %ROUND27PUBLISHEDFORMULAAUDITTEST Published trajectory consistency checks.

    methods (TestClassSetup)
        function addPath(testCase)
            project=fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(project));
        end
    end

    methods (Test)
        function publishedExampleMapsOutsideRange(testCase)
            cfg=jad.defaultConfig();
            carrierIndex=carrierIndexForTheta(cfg,14.8);

            [thetaDeg,rangeM]=jad.trajectory(cfg,carrierIndex);

            testCase.verifyEqual(thetaDeg,14.8,AbsTol=1e-10);
            testCase.verifyEqual(rangeM,102.5761906546,AbsTol=1e-9);
            testCase.verifyGreaterThan(rangeM,cfg.rangeLimitsM(2));
        end

        function sampledTrajectoryLeavesRectangle(testCase)
            cfg=jad.defaultConfig();

            [thetaDeg,rangeM]=jad.trajectory(cfg);
            inside=rangeM>=cfg.rangeLimitsM(1) & rangeM<=cfg.rangeLimitsM(2);
            [maximumRangeM,maximumIndex]=max(rangeM);

            testCase.verifyEqual(sum(inside),383);
            testCase.verifyEqual(maximumRangeM,103.53,AbsTol=1e-3);
            testCase.verifyEqual(thetaDeg(maximumIndex),20.426,AbsTol=1e-3);
        end

        function inclusiveIndexReachesPublishedEndpoint(testCase)
            cfg=jad.defaultConfig();

            [thetaDeg,rangeM]=jad.trajectory(cfg,[0;cfg.numSubcarriers]);

            testCase.verifyEqual(thetaDeg,cfg.thetaLimitsDeg.',AbsTol=1e-12);
            testCase.verifyEqual(rangeM,cfg.rangeLimitsM.',AbsTol=1e-12);
        end
    end
end

function carrierIndex=carrierIndexForTheta(cfg,thetaDeg)
thetaStart=deg2rad(cfg.thetaLimitsDeg(1));
thetaEnd=deg2rad(cfg.thetaLimitsDeg(2));
endWeight=(sind(thetaDeg)-sin(thetaStart))/(sin(thetaEnd)-sin(thetaStart));
fLow=cfg.fc-cfg.bandwidth/2;
frequencyOffset=endWeight*cfg.bandwidth*fLow/ ...
    (cfg.bandwidth+fLow-endWeight*cfg.bandwidth);
carrierIndex=frequencyOffset*cfg.numSubcarriers/cfg.bandwidth;
end
