classdef round47MarginalProfileTest < matlab.unittest.TestCase
    %ROUND47MARGINALPROFILETEST Tests for the new PA-free range backend.

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
        function protocolExcludesAllPriorFinalRows(testCase)
            protocol = r47.config();
            testCase.verifyFalse(protocol.execution.r34FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.r41FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.r46FinalReadAllowed);
            testCase.verifyTrue(protocol.method.paFree);
        end

        function designIsNewBalancedAndUnique(testCase)
            design = r47.design();
            counts = groupcounts(design, "snrDb");
            testCase.verifyEqual(height(design), 60);
            testCase.verifyEqual(counts.GroupCount, 20*ones(3, 1));
            testCase.verifyEqual(numel(unique(design.seed)), 60);
            testCase.verifyGreaterThan(min(design.seed), 62100000);
        end

        function quadratureWeightsAreNormalized(testCase)
            protocol = r47.config();
            testCase.verifyEqual(sum(protocol.quadrature.GH3.weights), ...
                1, AbsTol=1e-15);
            testCase.verifyEqual(sum(protocol.quadrature.GH5.weights), ...
                1, AbsTol=1e-15);
            testCase.verifyTrue(all(protocol.quadrature.GH3.weights > 0));
            testCase.verifyTrue(all(protocol.quadrature.GH5.weights > 0));
        end

        function observedInformationSigmaIsFinite(testCase)
            [cfg, context, thetaDeg, rangeM] = noiseFreeFixture();
            result = r47.angleUncertainty( ...
                cfg, context, thetaDeg, rangeM, r47.config());
            testCase.verifyTrue(result.validCurvature);
            testCase.verifyGreaterThan(result.sigmaDeg, 0);
            testCase.verifyLessThanOrEqual(result.sigmaDeg, 5e-3);
        end

        function zeroSigmaMatchesHardProfile(testCase)
            [cfg, observation, scan, thetaDeg, rangeM] = profileFixture();
            protocol = r47.config();
            hard = r33.profileAtAngle(cfg, observation, scan, ...
                thetaDeg, rangeM, protocol.r45.r34.r33);
            marginal = r47.marginalProfile(cfg, observation, scan, ...
                thetaDeg, 0, rangeM, protocol.quadrature.GH3, protocol);
            testCase.verifyEqual(marginal.value, hard.value, AbsTol=1e-6);
        end

        function estimatorSourceContainsNoPaMusicOrEvd(testCase)
            files = fullfile(testCase.MatlabRoot, "+r47", ...
                ["fromFront.m", "angleUncertainty.m", "marginalProfile.m"]);
            source = lower(join(arrayfun( ...
                @(file) string(fileread(file)), files), newline));
            testCase.verifyFalse(contains(source, "r34.estimate"));
            testCase.verifyFalse(contains(source, "preparemusicstate"));
            testCase.verifyFalse(contains(source, "stagedanglemusic"));
            testCase.verifyFalse(contains(source, "stagedjointmusic"));
            testCase.verifyFalse(contains(source, "eig("));
        end
    end
end

function [cfg, context, thetaDeg, rangeM] = noiseFreeFixture()
cfg = jad.defaultConfig();
cfg.numAntennas = 24;
cfg.numSubcarriers = 65;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
thetaDeg = -9.3;
rangeM = 27.6;
carrierIndex = (0:cfg.numSubcarriers-2).';
[~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
snapshots = complex(zeros(cfg.numAntennas, numel(carrierIndex)));
for index = 1:numel(carrierIndex)
    snapshots(:, index) = sqrt(cfg.numAntennas)*jad.steeringVector( ...
        cfg, thetaDeg, rangeM, frequencyHz(index));
end
snapshots = snapshots+1e-4*(ones(size(snapshots))+1i*ones(size(snapshots)));
context = r38PrepareRawArrayVpmlContext(cfg, snapshots, carrierIndex);
end

function [cfg, observation, scan, thetaDeg, rangeM] = profileFixture()
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
thetaDeg = 12.5;
rangeM = 31.2;
observation = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(thetaDeg), rangeM, scan);
observation = observation+1e-6*(ones(size(observation)) ...
    +1i*ones(size(observation)));
end
