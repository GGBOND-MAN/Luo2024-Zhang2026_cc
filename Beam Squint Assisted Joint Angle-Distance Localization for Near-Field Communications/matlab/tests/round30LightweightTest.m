classdef round30LightweightTest < matlab.unittest.TestCase
    %ROUND30LIGHTWEIGHTTEST Unit and wiring tests for the finite-budget path.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=false));
        end
    end

    methods (Test)
        function testUniformCarrierSelection(testCase)
            carrierIndex = r30.selectUniformCarriers(64, 17, 23);

            testCase.verifySize(carrierIndex, [17, 1]);
            testCase.verifyEqual(numel(unique(carrierIndex)), 17);
            testCase.verifyTrue(ismember(23, carrierIndex));
            testCase.verifyEqual(carrierIndex([1, end]), [0; 63]);
        end

        function testSubsetScanFullLimit(testCase)
            [cfg, scan, ~, ~, thetaDeg, rangeM] = smallCase();
            carrierIndex = (0:cfg.numSubcarriers-1).';
            reduced = r30.subsetScan(scan, carrierIndex);

            fullResponse = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(thetaDeg), rangeM, scan);
            reducedResponse = fsjad.exactSpectralResponse( ...
                cfg, deg2rad(thetaDeg), rangeM, reduced);

            testCase.verifyEqual(reducedResponse, fullResponse, AbsTol=1e-12);
        end

        function testFrontHasFiniteBudget(testCase)
            [cfg, scan, replay, protocol, ~, ~, candidate] = smallCase();

            output = r30.front( ...
                cfg, replay.observation, scan, protocol, candidate);

            testCase.verifyEqual(output.version, protocol.frontVersion);
            testCase.verifyLessThanOrEqual( ...
                output.fullEvaluations, output.fullResponseUpperBound);
            testCase.verifyGreaterThan(output.subsetEvaluations, 0);
            testCase.verifyTrue(isfinite(output.selected.score));
        end

        function testMusicScoreBatchConsistency(testCase)
            [cfg, ~, replay, ~, thetaDeg, rangeM, candidate] = smallCase();
            carrierIndex = r30.selectLocalCarriers( ...
                cfg.numSubcarriers, candidate.musicCarrierCount, ...
                replay.peakCarrierIndex);
            [state, musicCfg] = r30.prepareMusicState(cfg, ...
                replay.snapshots(:, carrierIndex+1), carrierIndex, ...
                thetaDeg, rangeM, candidate.musicSubarraySize);
            theta = thetaDeg + [-0.01, 0, 0.01];

            batch = jad.localMusicLogScore(musicCfg, state, theta, rangeM);
            scalar = [jad.localMusicLogScore(musicCfg, state, theta(1), rangeM), ...
                jad.localMusicLogScore(musicCfg, state, theta(2), rangeM), ...
                jad.localMusicLogScore(musicCfg, state, theta(3), rangeM)];

            testCase.verifyEqual(batch, scalar, AbsTol=1e-10);
        end

        function testTrialWiringAndAccounting(testCase)
            [cfg, scan, replay, protocol, ~, ~, candidate] = smallCase();

            result = r30.trialFromReplay( ...
                cfg, replay, scan, protocol, candidate);

            testCase.verifyTrue(result.success, result.errorMessage);
            testCase.verifyEqual(result.methodNames(1:3), ["F_L", "H_L", "P_L"]);
            testCase.verifyEqual(result.rangeM(1), result.rangeM(2), AbsTol=0);
            testCase.verifyGreaterThan( ...
                result.complexity.totalEquivalentFullResponses, 0);
            testCase.verifyEqual(result.complexity.onlineSeconds, ...
                result.front.runtimeSeconds+result.musicStateCost.seconds ...
                +result.angleSeconds+result.profileSeconds, RelTol=1e-12);
            testCase.verifyLessThanOrEqual( ...
                result.front.fullEvaluations, result.front.fullResponseUpperBound);
        end

        function testCandidateSelectionIsFinite(testCase)
            protocol = r30.config();
            summary = syntheticCandidateSummary(protocol.candidates.candidateId);
            baseline = syntheticBaseline();

            [selection, selected] = r30.selectCandidates( ...
                summary, baseline, protocol);

            testCase.verifyLessThanOrEqual(numel(selected.candidateId), 2);
            testCase.verifyEqual(nnz(selection.selected), ...
                numel(selected.candidateId));
            testCase.verifyTrue(selected.developmentOnly);
            testCase.verifyFalse(selected.independentValidation);
        end

        function testFailedThresholdsUseParetoPool(testCase)
            protocol = r30.config();
            summary = syntheticCandidateSummary(protocol.candidates.candidateId);
            baseline = syntheticBaseline();
            accuracy = [0.12, 0.115, 0.13, 0.14, 0.14, 0.14];
            equivalent = [1000, 2000, 500, 3000, 3000, 3000];
            for index = 1:numel(accuracy)
                rows = summary.candidateId == protocol.candidates.candidateId(index);
                summary.angleRmseDeg(rows) = accuracy(index);
                summary.rangeRmseM(rows) = accuracy(index);
                summary.positionRmseM(rows) = accuracy(index);
                summary.meanEquivalentResponses(rows) = equivalent(index);
            end

            [selection, selected] = r30.selectCandidates( ...
                summary, baseline, protocol);

            testCase.verifyEqual(selected.reason, ...
                "no-candidate-met-all-thresholds-pareto-diagnostic-only");
            selectedRows = ismember(selection.candidateId, selected.candidateId);
            testCase.verifyTrue(all(selection.pareto(selectedRows)));
            testCase.verifyLessThanOrEqual(nnz(selectedRows), 2);
        end

        function testIdentityMismatchRejected(testCase)
            actual = struct(version="a", count=1);
            expected = struct(version="b", count=1);

            testCase.verifyError(@() r30.assertIdentity(actual, expected), ...
                "r30:IdentityMismatch");
        end
    end
end

function summary = syntheticCandidateSummary(candidateIds)
summary = table();
for candidateId = candidateIds.'
    for snrDb = [-10, 0, 20]
        for method = ["H_L", "P_L"]
            entry = table(candidateId, snrDb, method, 20, ...
                0.1, 0.1, 0.1, 0.15, 0, 1000, 1000, 3000, ...
                0.1, 0, 0, 'VariableNames', {'candidateId', 'snrDb', ...
                'method', 'n', 'angleRmseDeg', 'rangeRmseM', ...
                'positionRmseM', 'p95RangeM', 'missOver1m', ...
                'meanEquivalentResponses', 'medianEquivalentResponses', ...
                'fullResponseUpperBound', 'meanSeconds', ...
                'angleBoundaryRate', 'profileBoundaryRate'});
            summary = [summary; entry]; %#ok<AGROW>
        end
    end
end
end

function baseline = syntheticBaseline()
baseline = table();
for snrDb = [-10, 0, 20]
    for method = ["C_star", "H_star"]
        entry = table(method, snrDb, 0.1, 0.1, 0.1, 0.15, 0, ...
            'VariableNames', {'method', 'snrDb', 'angleRmseDeg', ...
            'rmseM', 'jointRmseM', 'p95M', 'missOver1m'});
        baseline = [baseline; entry]; %#ok<AGROW>
    end
end
end

function [cfg, scan, replay, protocol, thetaDeg, rangeM, candidate] = smallCase()
cfg = jad.defaultConfig();
cfg.numAntennas = 16;
cfg.numSubcarriers = 64;
cfg.subarraySize = 8;
cfg.numSubarrays = cfg.numAntennas-cfg.subarraySize+1;
cfg.elementIndex = (0:cfg.numAntennas-1).'-(cfg.numAntennas-1)/2;
thetaDeg = 5;
rangeM = 30;
scan = fsjad.prepareScan(cfg);
observation = fsjad.exactSpectralResponse(cfg, deg2rad(thetaDeg), rangeM, scan);
[~, peak] = max(abs(observation).^2);
carrierIndex = (0:cfg.numSubcarriers-1).';
stream = RandStream("mt19937ar", Seed=20260910);
snapshots = jad.simulateSnapshots( ...
    cfg, thetaDeg, rangeM, 30, carrierIndex, stream);
replay = struct(observation=observation, snapshots=snapshots, ...
    peakCarrierIndex=peak-1);
protocol = r30.config();
protocol.angleOffsetsDeg = [-0.1; 0; 0.1];
protocol.angleHalfWidthDeg = 0.1;
protocol.angleIntervals = 20;
protocol.anglePeakCount = 2;
protocol.profileHalfWidthM = 0.5;
candidate = protocol.candidates(1, :);
candidate.frontCarrierCount = 17;
candidate.frontRangeSpacingM = 2.5;
candidate.frontCandidateCount = 2;
candidate.frontMaxIterations = 2;
candidate.musicCarrierCount = 5;
candidate.musicSubarraySize = 8;
end
