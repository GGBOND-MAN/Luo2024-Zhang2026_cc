classdef round43CoherentSequentialTest < matlab.unittest.TestCase
    %ROUND43COHERENTSEQUENTIALTEST Tests for the PA-free R43 estimator.

    properties (SetAccess = private)
        MatlabRoot string
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            testCase.MatlabRoot = string(fileparts(fileparts( ...
                mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.MatlabRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.MatlabRoot, "+r38", "schemeF")));
        end
    end

    methods (Test)
        function protocolFreezesEvidenceBoundary(testCase)
            protocol = r43.config();
            testCase.verifyFalse(protocol.execution.r34FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.r41FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.r42ResultReadAllowed);
            testCase.verifyFalse( ...
                protocol.execution.parameterTuningFromPilotAllowed);
            testCase.verifyEqual(protocol.method.primary, "H_seqY");
        end

        function designIsNewAndBalanced(testCase)
            design = r43.design(10);
            counts = groupcounts(design, "snrDb");
            testCase.verifyEqual(height(design), 30);
            testCase.verifyEqual(counts.GroupCount, 10*ones(3, 1));
            testCase.verifyEqual(numel(unique(design.seed)), 30);
            testCase.verifyGreaterThan(min(design.seed), 57100000);
        end

        function coherentScorePeaksAtTruth(testCase)
            [cfg, context, thetaDeg, rangeM] = noiseFreeFixture();
            truthScore = r43.coherentArrayScore( ...
                cfg, context, thetaDeg, rangeM);
            displacedScore = r43.coherentArrayScore( ...
                cfg, context, thetaDeg, rangeM+0.12);
            testCase.verifyGreaterThan(truthScore, displacedScore);
            testCase.verifyEqual(truthScore, 1, AbsTol=1e-12);
        end

        function coherentScoreIsCommonGainInvariant(testCase)
            [cfg, context, thetaDeg, rangeM] = noiseFreeFixture();
            reference = r43.coherentArrayScore( ...
                cfg, context, thetaDeg, rangeM);
            context.snapshots = (1.7-0.8i)*context.snapshots;
            context.snapshotEnergy = real(sum(abs(context.snapshots).^2, 1));
            context.totalEnergy = sum(context.snapshotEnergy);
            transformed = r43.coherentArrayScore( ...
                cfg, context, thetaDeg, rangeM);
            testCase.verifyEqual(transformed, reference, AbsTol=1e-12);
        end

        function estimatorContainsNoPaMusicOrEvd(testCase)
            file = fullfile(testCase.MatlabRoot, "+r43", "estimate.m");
            source = lower(string(fileread(file)));
            testCase.verifyFalse(contains(source, "estimatepa("));
            testCase.verifyFalse(contains(source, "r34.estimate"));
            testCase.verifyFalse(contains(source, "music"));
            testCase.verifyFalse(contains(source, "eig("));
        end
    end
end

function [cfg, context, thetaDeg, rangeM] = noiseFreeFixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 20;
cfg.numSubcarriers = 65;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
scan = fsjad.prepareScan(cfg);
thetaDeg = 11.2;
rangeM = 31.4;
carrierIndex = (0:cfg.numSubcarriers-2).';
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
snapshots = complex(zeros(cfg.numAntennas, numel(carrierIndex)));
for index = 1:numel(carrierIndex)
    snapshots(:, index) = sqrt(cfg.numAntennas)*jad.steeringVector( ...
        cfg, thetaDeg, rangeM, frequencyHz(index));
end
observation = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(thetaDeg), rangeM, scan);
context = r42.prepareContext( ...
    cfg, scan, observation, snapshots, carrierIndex);
end
