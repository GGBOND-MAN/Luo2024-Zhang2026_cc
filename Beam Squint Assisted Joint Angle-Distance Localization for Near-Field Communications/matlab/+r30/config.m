function protocol = config()
%CONFIG Frozen finite-budget lightweight development protocol.

protocol.version = "R30-lightweight-development-v1";
protocol.frontVersion = "R30-sparse-wideband-front-v1";
protocol.angleOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
protocol.profileHalfWidthM = 2;
protocol.angleHalfWidthDeg = 0.2;
protocol.angleIntervals = 80;
protocol.anglePeakCount = 4;
protocol.scoreTolerance = 1e-10;
protocol.maxSelectedCandidates = 2;
protocol.bootstrapCount = 20000;
protocol.bootstrapSeed = 20260910;

candidateId = ["L01"; "L02"; "L03"; "L04"; "L05"; "L06"];
frontCarrierCount = [65; 129; 257; 129; 257; 513];
frontRangeSpacingM = repmat(0.1, 6, 1);
frontCandidateCount = [4; 4; 4; 8; 8; 8];
frontMaxIterations = [6; 6; 6; 10; 10; 10];
musicCarrierCount = [5; 17; 33; 17; 33; 65];
musicSubarraySize = repmat(128, 6, 1);
protocol.candidates = table(candidateId, frontCarrierCount, ...
    frontRangeSpacingM, frontCandidateCount, frontMaxIterations, ...
    musicCarrierCount, musicSubarraySize);

% These are engineering development thresholds, not equivalence guarantees.
protocol.acceptance.angleRmseRatio = 1.10;
protocol.acceptance.rangeRmseRatio = 1.10;
protocol.acceptance.positionRmseRatio = 1.10;
protocol.acceptance.p95Ratio = 1.15;
protocol.acceptance.missRateIncrease = 0.01;
protocol.acceptance.maxFullEquivalentResponses = 12000;

% The IEEE accepted manuscript publishes M_s=128 and a 1 degree / 1 m
% local region. It does not publish the fusion count or grid density.
protocol.publicZhang = struct( ...
    label="Zhang-published-region-local-grid-assumption-v1", ...
    fusionCarrierCount=5, subarraySize=128, ...
    localHalfWidthDeg=1, localHalfWidthM=1, ...
    gridSizes=[41, 31, 21]);
protocol.dataRole = "development-on-existing-R26-derived-calibration-users";
end
