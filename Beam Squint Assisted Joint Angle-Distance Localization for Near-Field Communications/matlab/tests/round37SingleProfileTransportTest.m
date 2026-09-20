classdef round37SingleProfileTransportTest < matlab.unittest.TestCase
    %ROUND37SINGLEPROFILETRANSPORTTEST Identity and numerical derivatives.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addR37Paths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r37", ...
                "singleProfile")));
        end
    end

    methods (Test)
        function protocolFreezesSingleProfileAndNoNewUsers(testCase)
            protocol = r37SingleProfileProtocol();

            testCase.verifyEqual( ...
                protocol.profile.totalCompleteProfilePasses, 1);
            testCase.verifyEqual(protocol.profile.newCompleteProfilePasses, 0);
            testCase.verifyFalse(protocol.execution.newUsersAllowed);
            testCase.verifyFalse(protocol.execution.r34FinalAuthorized);
            testCase.verifyFalse(protocol.angle.allowModification);
            testCase.verifyEqual(protocol.input.allUsers, 600);
            testCase.verifyEqual(protocol.input.holdoutUsers, 540);
        end

        function exactProfileDerivativesMatchFiniteDifferences(testCase)
            [cfg, scan, observation, thetaRad, rangeM] = fixture();
            context = r33.prepareResponseContext(cfg, scan, observation);
            actual = r37ExactProfileLogDerivatives( ...
                cfg, thetaRad, rangeM, context);
            [gradient, hessian] = finiteDifferences( ...
                cfg, context, thetaRad, rangeM);

            testCase.verifyTrue(actual.valid);
            testCase.verifyEqual(actual.gradient, gradient, ...
                AbsTol=2e-5, RelTol=2e-5);
            testCase.verifyEqual(actual.hessian, hessian, ...
                AbsTol=5e-3, RelTol=5e-4);
        end

        function transportRetainsCandidateAndFrozenBounds(testCase)
            [cfg, scan, observation, thetaRad, rangeM] = fixture();
            centerRangeM = rangeM+0.15;
            result = r37ImplicitProfileTransport(cfg, scan, observation, ...
                rad2deg(thetaRad), rangeM, rad2deg(thetaRad)+1e-4, ...
                centerRangeM);

            testCase.verifyGreaterThanOrEqual(result.rangeM, ...
                result.boundsM(1));
            testCase.verifyLessThanOrEqual(result.rangeM, ...
                result.boundsM(2));
            testCase.verifyGreaterThanOrEqual(result.selectedScore, ...
                result.scoreRetained-1e-12);
            testCase.verifyEqual(result.completeProfilePassCount, 1);
            testCase.verifyEqual(result.newCompleteProfilePassCount, 0);
            testCase.verifyEqual(result.addedResponseEvaluationCount, 3);
        end

        function observationOnlyReplayMatchesFrozenReplay(testCase)
            [cfg, scan, ~, ~, ~] = fixture();
            row = table(710001, 1, 0, 12.3, 29.7, ...
                'VariableNames', {'seed', 'trialIndex', 'snrDb', ...
                'truthThetaDeg', 'truthRangeM'});
            expected = fsjad.replayRound27Data(cfg, scan, row);
            actual = r37ReplayCalibrationObservation(cfg, scan, row);

            testCase.verifyEqual(actual.response, expected.response);
            testCase.verifyEqual(actual.variance, expected.variance);
            testCase.verifyEqual(actual.beta, expected.beta);
            testCase.verifyEqual(actual.noise, expected.noise);
            testCase.verifyEqual(actual.observation, expected.observation);
        end

        function implementationContainsNoOptimizerOrFullProfile(testCase)
            folder = fullfile(testCase.MatlabRoot, "+r37", ...
                "singleProfile");
            files = dir(fullfile(folder, "*.m"));
            source = "";
            for index = 1:numel(files)
                source = source+newline+string(fileread( ...
                    fullfile(files(index).folder, files(index).name)));
            end

            testCase.verifyFalse(contains(lower(source), "fminbnd("));
            testCase.verifyFalse(contains(lower(source), "profileatangle("));
            testCase.verifyFalse(contains(lower(source), ...
                "i_explicitly_authorize_r34_final_1400"));
        end
    end
end

function [cfg, scan, observation, thetaRad, rangeM] = fixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 32;
cfg.numSubcarriers = 63;
cfg.rangeLimitsM = [5, 80];
cfg.elementIndex = (0:cfg.numAntennas-1).' ...
    -(cfg.numAntennas-1)/2;
scan = fsjad.prepareScan(cfg);
thetaRad = deg2rad(17.25);
rangeM = 31.4;
observation = fsjad.exactSpectralResponse( ...
    cfg, thetaRad+deg2rad(0.003), rangeM+0.02, scan);
end

function [gradient, hessian] = finiteDifferences( ...
    cfg, context, thetaRad, rangeM)
hTheta = 5e-6;
hRange = 1e-4;
score = @(theta, range) r33.fixedAngleProfileLogScore( ...
    cfg, rad2deg(theta), range, context);
f00 = score(thetaRad, rangeM);
fThetaPlus = score(thetaRad+hTheta, rangeM);
fThetaMinus = score(thetaRad-hTheta, rangeM);
fRangePlus = score(thetaRad, rangeM+hRange);
fRangeMinus = score(thetaRad, rangeM-hRange);
gradient = [(fThetaPlus-fThetaMinus)/(2*hTheta); ...
    (fRangePlus-fRangeMinus)/(2*hRange)];
hessianTheta = (fThetaPlus-2*f00+fThetaMinus)/hTheta^2;
hessianRange = (fRangePlus-2*f00+fRangeMinus)/hRange^2;
mixed = (score(thetaRad+hTheta, rangeM+hRange) ...
    -score(thetaRad+hTheta, rangeM-hRange) ...
    -score(thetaRad-hTheta, rangeM+hRange) ...
    +score(thetaRad-hTheta, rangeM-hRange))/(4*hTheta*hRange);
hessian = [hessianTheta, mixed; mixed, hessianRange];
end
