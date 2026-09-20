classdef round45PfaCalibrationTest < matlab.unittest.TestCase
    %ROUND45PFACALIBRATIONTEST Tests for the frozen R45 P_FA protocol.

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
        function protocolFreezesEvidenceBoundary(testCase)
            protocol = r45.config();
            testCase.verifyFalse(protocol.execution.r34FinalReadAllowed);
            testCase.verifyFalse(protocol.execution.r41FinalReadAllowed);
            testCase.verifyFalse( ...
                protocol.execution.priorDevelopmentRowsReadAllowed);
            testCase.verifyFalse(protocol.execution.parameterTuningAllowed);
            testCase.verifyEqual(protocol.method.primary, "P_FA");
            testCase.verifyEqual(protocol.design.expectedRows, 600);
        end

        function designIsNewBalancedAndPositionClustered(testCase)
            protocol = r45.config();
            design = r45.design(protocol);
            counts = groupcounts(design, "snrDb");
            testCase.verifyEqual(height(design), 600);
            testCase.verifyEqual(counts.GroupCount, 200*ones(3, 1));
            testCase.verifyEqual(numel(unique(design.seed)), 600);
            testCase.verifyEqual(nnz(design.subset == "diagnostic60"), 60);
            testCase.verifyEqual(nnz(design.subset == "holdout540"), 540);
            testCase.verifyGreaterThan(min(design.seed), 59000000);
        end

        function scoreIsInvariantToPerCarrierPhase(testCase)
            [cfg, context, thetaDeg, rangeM] = noiseFreeFixture();
            reference = r38RawArrayVpmlScore( ...
                cfg, context, thetaDeg, rangeM);
            phase = exp(1i*linspace(-1.2, 0.9, context.carrierCount));
            transformed = context;
            transformed.snapshots = transformed.snapshots.*phase;
            transformed.snapshotEnergy = real(sum( ...
                abs(transformed.snapshots).^2, 1));
            transformed.totalEnergy = sum(transformed.snapshotEnergy);
            score = r38RawArrayVpmlScore( ...
                cfg, transformed, thetaDeg, rangeM);
            testCase.verifyEqual(score, reference, AbsTol=1e-12);
        end

        function estimatorSourceContainsNoPaMusicOrEvd(testCase)
            files = fullfile(testCase.MatlabRoot, "+r45", ...
                ["estimatePFA.m", "fromFront.m", "fullArrayAngle.m"]);
            source = lower(join(arrayfun( ...
                @(file) string(fileread(file)), files), newline));
            testCase.verifyFalse(contains(source, "r34.estimate"));
            testCase.verifyFalse(contains(source, "stagedanglemusic"));
            testCase.verifyFalse(contains(source, "preparemusicstate"));
            testCase.verifyFalse(contains(source, "eig("));
        end

        function standaloneAndSharedFrontAreEquivalent(testCase)
            protocol = r45.config();
            cfg = jad.defaultConfig();
            scan = fsjad.prepareScan(cfg);
            row = r45.design(protocol);
            replay = fsjad.replayRound27Data(cfg, scan, row(1, :));
            standalone = r45.estimatePFA(cfg, replay.observation, ...
                replay.snapshots, scan, protocol);
            shared = r34.sharedPerformanceSet(cfg, replay.observation, ...
                replay.snapshots, scan, protocol.r34);
            backend = r45.fromFront(cfg, replay.observation, ...
                replay.snapshots, scan, shared.front, protocol);
            testCase.verifyEqual(standalone.thetaDeg, ...
                backend.thetaDeg, AbsTol=1e-10);
            testCase.verifyEqual(standalone.rangeM, ...
                backend.rangeM, AbsTol=1e-8);
            testCase.verifyEqual(standalone.musicEvaluationCount, 0);
            testCase.verifyEqual(standalone.evdCount, 0);
        end

        function clusteredBootstrapIsDeterministic(testCase)
            [perUser, protocol] = bootstrapFixture();
            first = r45.clusterBootstrap(perUser, protocol, 0);
            second = r45.clusterBootstrap(perUser, protocol, 0);
            testCase.verifyEqual(first.angleRatio, second.angleRatio, ...
                AbsTol=0);
            testCase.verifyEqual(first.rangeRatio, second.rangeRatio, ...
                AbsTol=0);
            testCase.verifyEqual(first.summary.observedRatio, ...
                [0.25; 0.998001], AbsTol=1e-12);
            testCase.verifyTrue(all(first.summary.pass));
        end

        function syntheticSummaryBuildsEveryFrozenGate(testCase)
            [design, results, protocol] = summaryFixture();
            summary = r45.summarize(design, results, protocol);
            testCase.verifyEqual(height(summary.all600.gate), 6);
            testCase.verifyEqual(height(summary.holdout540.gate), 6);
            testCase.verifyEqual(height(summary.diagnostic60.gate), 6);
            testCase.verifyEqual(height(summary.decision), 1);
            testCase.verifyTrue(summary.decision.identityPass);
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
context = r38PrepareRawArrayVpmlContext(cfg, snapshots, carrierIndex);
end

function [perUser, protocol] = bootstrapFixture()
protocol = r45.config();
protocol.bootstrap.count = 100;
positionId = repelem((1:6).', 3, 1);
snrDb = repmat(protocol.design.snrDb(:), 6, 1);
angleError_P_FA = 0.5*ones(18, 1);
angleError_P_A = ones(18, 1);
rangeError_P_FA = 0.999*ones(18, 1);
rangeError_P_A = ones(18, 1);
perUser = table(positionId, snrDb, angleError_P_FA, angleError_P_A, ...
    rangeError_P_FA, rangeError_P_A);
end

function [design, results, protocol] = summaryFixture()
protocol = r45.config();
protocol.bootstrap.count = 100;
protocol.design.diagnosticPositionIds = 1:2;
protocol.design.holdoutPositionIds = 3:4;
positionId = repelem((1:4).', 3, 1);
seed = (1:12).';
trialIndex = seed;
snrDb = repmat(protocol.design.snrDb(:), 4, 1);
truthThetaDeg = zeros(12, 1);
truthRangeM = 25*ones(12, 1);
subset = repmat("holdout540", 12, 1);
subset(positionId <= 2) = "diagnostic60";
design = table(positionId, seed, trialIndex, snrDb, ...
    truthThetaDeg, truthRangeM, subset);
results = cell(12, 1);
for index = 1:12
    results{index} = syntheticResult(index);
end
end

function result = syntheticResult(index)
signValue = 2*mod(index, 2)-1;
result = struct(success=true, ...
    P_FA=struct(thetaDeg=0.4*signValue, rangeM=25+0.9*signValue), ...
    P_A=struct(thetaDeg=0.5*signValue, rangeM=25+1.0*signValue), ...
    G_schur=struct(thetaDeg=0.45*signValue, rangeM=25+0.95*signValue), ...
    C_enhanced=struct(thetaDeg=0.6*signValue, rangeM=25+1.1*signValue), ...
    pfaDiagnostics=struct( ...
        profile=struct(endpointHit=false, nearBoundary=false), ...
        angle=struct(retentionMargin=0), ...
        fullArrayEvaluationCount=50, profileEvaluationCount=20), ...
    sharedAudit=struct(totalDirectEvdCount=2, ...
        totalGramCount=0, totalFallbackCount=0));
end
