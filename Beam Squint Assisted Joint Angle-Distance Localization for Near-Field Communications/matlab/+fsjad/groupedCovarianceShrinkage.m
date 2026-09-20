function result = groupedCovarianceShrinkage(cfg, observation, snapshots, ...
    carrierIndex, front, scan, numGroups)
%GROUPEDCOVARIANCESHRINKAGE Estimate alpha from complementary carrier groups.

arguments
    cfg (1, 1) struct
    observation (:, 1) double
    snapshots (:, :) double
    carrierIndex (:, 1) double
    front (1, 1) struct
    scan (1, 1) struct = fsjad.prepareScan(cfg)
    numGroups (1, 1) double {mustBeInteger, mustBeGreaterThanOrEqual(numGroups, 3)} = 8
end

if size(snapshots, 2) ~= numel(carrierIndex)
    error("fsjad:groupedCovarianceShrinkage:CarrierCount", ...
        "Snapshot columns and carrierIndex must have equal length.");
end
if numGroups > numel(carrierIndex)
    error("fsjad:groupedCovarianceShrinkage:GroupCount", ...
        "numGroups cannot exceed the number of fusion carriers.");
end

frontRangeReplicateM = zeros(numGroups, 1);
musicRangeReplicateM = zeros(numGroups, 1);
frontThetaReplicateDeg = zeros(numGroups, 1);
musicThetaReplicateDeg = zeros(numGroups, 1);
for groupIndex = 1:numGroups
    spectralSampleIndex = (groupIndex:numGroups:cfg.numSubcarriers).';
    fusionPosition = (groupIndex:numGroups:numel(carrierIndex)).';
    frontReplicate = fsjad.subsetProfileEstimate(cfg, observation, ...
        spectralSampleIndex, front.thetaDeg, front.rangeM, scan);
    musicReplicate = jad.localMusicEstimate(cfg, ...
        snapshots(:, fusionPosition), carrierIndex(fusionPosition), ...
        frontReplicate.thetaDeg, frontReplicate.rangeM);
    frontRangeReplicateM(groupIndex) = frontReplicate.rangeM;
    musicRangeReplicateM(groupIndex) = musicReplicate.rangeM;
    frontThetaReplicateDeg(groupIndex) = frontReplicate.thetaDeg;
    musicThetaReplicateDeg(groupIndex) = musicReplicate.thetaDeg;
end

result = fsjad.covarianceRangeShrinkage( ...
    frontRangeReplicateM, musicRangeReplicateM);
result.frontThetaReplicateDeg = frontThetaReplicateDeg;
result.musicThetaReplicateDeg = musicThetaReplicateDeg;
result.numGroups = numGroups;
end
