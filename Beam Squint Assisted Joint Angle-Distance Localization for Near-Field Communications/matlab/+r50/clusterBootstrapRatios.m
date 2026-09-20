function output = clusterBootstrapRatios(perUser, protocol)
%CLUSTERBOOTSTRAPRATIOS Paired position-cluster intervals for R50 ratios.

arguments
    perUser table
    protocol (1, 1) struct = r50.config()
end

comparisons = ["oracleLocal", "P_A"; "oracleLocal", "P_FA"; ...
    "oracleGlobal", "P_A"; "oracleGlobal", "P_FA"; ...
    "grid", "P_FA"];
snrValues = unique(perUser.snrDb, "stable").';
scopes = [string(snrValues), "equal-SNR"];
output = table();
seedOffset = 0;
for comparisonIndex = 1:size(comparisons, 1)
    candidate = comparisons(comparisonIndex, 1);
    reference = comparisons(comparisonIndex, 2);
    for scope = scopes
        seedOffset = seedOffset+1;
        [candidateMatrix, referenceMatrix, positionCount] = ...
            matrices(perUser, candidate, reference, scope, snrValues);
        observed = mean(candidateMatrix, "all") ...
            /mean(referenceMatrix, "all");
        stream = RandStream("mt19937ar", ...
            Seed=protocol.bootstrap.seed+seedOffset);
        ratios = zeros(protocol.bootstrap.count, 1);
        for bootstrapIndex = 1:protocol.bootstrap.count
            sampled = randi(stream, positionCount, positionCount, 1);
            ratios(bootstrapIndex) = mean(candidateMatrix(sampled, :), "all") ...
                /mean(referenceMatrix(sampled, :), "all");
        end
        lower95 = quantile(ratios, (1-protocol.bootstrap.confidence)/2);
        upper95 = quantile(ratios, 1-(1-protocol.bootstrap.confidence)/2);
        equivalent = lower95 >= protocol.bootstrap.practicalEquivalence(1) ...
            && upper95 <= protocol.bootstrap.practicalEquivalence(2);
        strongBenefit = upper95 < protocol.bootstrap.strongBenefitUpper;
        classification = "inconclusive";
        if equivalent
            classification = "practical-equivalence";
        elseif strongBenefit
            classification = "strong-oracle-benefit";
        end
        output = [output; table(candidate, reference, scope, ...
            positionCount, observed, lower95, upper95, equivalent, ...
            strongBenefit, classification, 'VariableNames', ...
            {'candidate', 'reference', 'scope', 'positionCount', ...
            'mseRatio', 'lower95', 'upper95', 'practicalEquivalent', ...
            'strongBenefit', 'classification'})]; %#ok<AGROW>
    end
end
end

function [candidate, reference, count] = matrices( ...
    perUser, candidateName, referenceName, scope, snrValues)
if scope == "equal-SNR"
    positions = unique(perUser.positionId, "stable");
    count = numel(positions);
    candidate = zeros(count, numel(snrValues));
    reference = zeros(count, numel(snrValues));
    for i = 1:count
        for j = 1:numel(snrValues)
            selected = perUser.positionId == positions(i) ...
                & perUser.snrDb == snrValues(j);
            candidate(i, j) = squaredError(perUser, candidateName, selected);
            reference(i, j) = squaredError(perUser, referenceName, selected);
        end
    end
else
    snr = str2double(scope);
    selected = perUser.snrDb == snr;
    candidate = squaredError(perUser, candidateName, selected);
    reference = squaredError(perUser, referenceName, selected);
    count = nnz(selected);
end
end

function output = squaredError(perUser, method, selected)
output = perUser.("rangeError_"+method)(selected).^2;
end
