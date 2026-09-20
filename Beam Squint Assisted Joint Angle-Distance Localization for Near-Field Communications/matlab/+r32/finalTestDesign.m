function design = finalTestDesign(protocol)
%FINALTESTDESIGN Freeze 200 new positions and seven paired SNR conditions.

arguments
    protocol (1, 1) struct = r32.config()
end

spec = protocol.finalTest;
stream = RandStream("mt19937ar", Seed=spec.positionSeed);
positionId = (1:spec.positionCount).';
truthThetaDeg = spec.angleLimitsDeg(1) ...
    + diff(spec.angleLimitsDeg)*rand(stream, spec.positionCount, 1);
truthRangeM = spec.rangeLimitsM(1) ...
    + diff(spec.rangeLimitsM)*rand(stream, spec.positionCount, 1);
positions = table(positionId, truthThetaDeg, truthRangeM);
design = table();
for snrIndex = 1:numel(spec.snrDb)
    snrDb = repmat(spec.snrDb(snrIndex), spec.positionCount, 1);
    seed = spec.trialSeedRoot + (snrIndex-1)*1000 + positionId;
    trialIndex = positionId;
    rows = [positions, table(snrDb, seed, trialIndex)];
    design = [design; rows]; %#ok<AGROW>
end
if height(design) ~= spec.positionCount*numel(spec.snrDb) ...
        || numel(unique(design.seed)) ~= height(design)
    error("r32:FinalDesignInvariant", ...
        "The frozen final design must contain 1400 unique trial seeds.");
end
end
