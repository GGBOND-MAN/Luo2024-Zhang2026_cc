classdef round44ClockInvariantTest < matlab.unittest.TestCase
    %ROUND44CLOCKINVARIANTTEST Tests for the R44 sequential estimator.

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
        function protocolFreezesPriorEvidenceBoundary(testCase)
            protocol = r44.config();
            testCase.verifyFalse(protocol.execution.r34FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.r41FinalReadAllowed);
            testCase.verifyFalse( ...
                protocol.execution.priorDevelopmentResultReadAllowed);
            testCase.verifyEqual(protocol.method.primary, "H_seqVP");
        end

        function designIsNewAndBalanced(testCase)
            design = r44.design(10);
            counts = groupcounts(design, "snrDb");
            testCase.verifyEqual(height(design), 30);
            testCase.verifyEqual(counts.GroupCount, 10*ones(3, 1));
            testCase.verifyEqual(numel(unique(design.seed)), 30);
            testCase.verifyGreaterThan(min(design.seed), 58100000);
        end

        function rangeScorePeaksAtTruth(testCase)
            [cfg, context, thetaDeg, rangeM] = noiseFreeFixture();
            truthScore = r38RawArrayVpmlScore( ...
                cfg, context, thetaDeg, rangeM);
            displacedScore = r38RawArrayVpmlScore( ...
                cfg, context, thetaDeg, rangeM+0.25);
            testCase.verifyEqual(truthScore, 1, AbsTol=1e-12);
            testCase.verifyGreaterThan(truthScore, displacedScore);
        end

        function scoreIsInvariantToPerCarrierPhase(testCase)
            [cfg, context, thetaDeg, rangeM] = noiseFreeFixture();
            reference = r38RawArrayVpmlScore( ...
                cfg, context, thetaDeg, rangeM);
            phase = exp(1i*linspace(-1.2, 0.9, context.carrierCount));
            context.snapshots = context.snapshots.*phase;
            context.snapshotEnergy = real(sum(abs(context.snapshots).^2, 1));
            context.totalEnergy = sum(context.snapshotEnergy);
            transformed = r38RawArrayVpmlScore( ...
                cfg, context, thetaDeg, rangeM);
            testCase.verifyEqual(transformed, reference, AbsTol=1e-12);
        end

        function estimatorContainsNoPaMusicOrEvd(testCase)
            file = fullfile(testCase.MatlabRoot, "+r44", "estimate.m");
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
cfg.numAntennas = 24;
cfg.numSubcarriers = 65;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
scan = fsjad.prepareScan(cfg);
thetaDeg = -9.3;
rangeM = 27.6;
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
