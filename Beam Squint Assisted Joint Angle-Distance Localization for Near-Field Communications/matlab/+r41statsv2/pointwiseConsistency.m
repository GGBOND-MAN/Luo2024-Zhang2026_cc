function output = pointwiseConsistency(summary, protocol)
%POINTWISECONSISTENCY Apply the noninferential strict observed-MSE gate.

arguments
    summary table
    protocol (1, 1) struct = r41statsv2.config()
end

snrValues = protocol.design.snrDb(:);
angleMseG = zeros(numel(snrValues), 1);
angleMseC = zeros(numel(snrValues), 1);
rangeMseG = zeros(numel(snrValues), 1);
rangeMseC = zeros(numel(snrValues), 1);
for index = 1:numel(snrValues)
    snrDb = snrValues(index);
    g = summary(summary.method == "G_schur" ...
        & summary.snrDb == snrDb, :);
    c = summary(summary.method == "C_enhanced" ...
        & summary.snrDb == snrDb, :);
    if height(g) ~= 1 || height(c) ~= 1
        error("r41v2:PointwiseSummaryIdentity", ...
            "Each SNR requires one G_schur and one C_enhanced summary row.");
    end
    angleMseG(index) = g.angleMseDeg2;
    angleMseC(index) = c.angleMseDeg2;
    rangeMseG(index) = g.rangeMseM2;
    rangeMseC(index) = c.rangeMseM2;
end
angleLower = angleMseG < angleMseC;
rangeLower = rangeMseG < rangeMseC;
bothLower = angleLower & rangeLower;
role = repmat("descriptive-engineering-not-significance-test", ...
    numel(snrValues), 1);
output = table(snrValues, angleMseG, angleMseC, angleLower, ...
    rangeMseG, rangeMseC, rangeLower, bothLower, role, ...
    'VariableNames', {'snrDb', 'angleMseG', 'angleMseC', ...
    'angleStrictlyLower', 'rangeMseG', 'rangeMseC', ...
    'rangeStrictlyLower', 'bothStrictlyLower', 'role'});
end
