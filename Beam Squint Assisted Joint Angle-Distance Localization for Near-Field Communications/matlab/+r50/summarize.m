function output = summarize(design, results, protocol)
%SUMMARIZE Build R50 mechanism tables from all 600 diagnostic rows.

arguments
    design table
    results (:, 1) cell
    protocol (1, 1) struct = r50.config()
end

if numel(results) ~= height(design) || any(cellfun(@isempty, results)) ...
        || any(cellfun(@(item) ~item.success, results))
    error("r50:IncompleteDiagnostics", ...
        "R50 summary requires every frozen R48 row to succeed.");
end

perUser = buildPerUser(design, results, protocol);
methodSummary = summarizeMethods(perUser, protocol);
oracleBootstrap = r50.clusterBootstrapRatios(perUser, protocol);
biasVariance = summarizeBiasVariance(perUser, protocol);
ridge = summarizeRidge(perUser, protocol);
decomposition = summarizeDecomposition(perUser, protocol);
modeSwitch = summarizeModes(perUser, protocol);
gridContinuous = summarizeGridContinuous(perUser, protocol);
diagnostics = table(height(perUser), ...
    sum(perUser.validKappa_P_A), sum(perUser.validKappa_P_FA), ...
    mean(perUser.responseEvaluations), ...
    sum(perUser.oracleLocalEndpoint), ...
    sum(perUser.oracleGlobalEndpoint), ...
    'VariableNames', {'n', 'validKappaPA', 'validKappaPFA', ...
    'meanResponseEvaluations', 'oracleLocalEndpointHits', ...
    'oracleGlobalEndpointHits'});
output = struct(version="R50-range-conditioning-summary-v1", ...
    perUser=perUser, methodSummary=methodSummary, ...
    oracleBootstrap=oracleBootstrap, biasVariance=biasVariance, ...
    ridge=ridge, decomposition=decomposition, ...
    modeSwitch=modeSwitch, gridContinuous=gridContinuous, ...
    diagnostics=diagnostics);
end

function perUser = buildPerUser(design, results, protocol)
perUser = design(:, ["positionId", "seed", "trialIndex", ...
    "snrDb", "truthThetaDeg", "truthRangeM"]);
names = ["P_A", "P_FA", "P_FAM5", "grid", ...
    "oracleLocal", "oracleGlobal"];
theta = struct();
rangeM = struct();
theta.P_A = cellfun(@(x) x.thetaA, results);
theta.P_FA = cellfun(@(x) x.thetaFA, results);
theta.P_FAM5 = theta.P_FA;
theta.grid = cellfun(@(x) x.thetaGrid, results);
theta.oracleLocal = perUser.truthThetaDeg;
theta.oracleGlobal = perUser.truthThetaDeg;
rangeM.P_A = cellfun(@(x) x.rangeA, results);
rangeM.P_FA = cellfun(@(x) x.rangeFA, results);
rangeM.P_FAM5 = cellfun(@(x) x.rangeFAM5, results);
rangeM.grid = cellfun(@(x) x.rangeGrid, results);
rangeM.oracleLocal = cellfun(@(x) x.rangeOracleLocal, results);
rangeM.oracleGlobal = cellfun(@(x) x.rangeOracleGlobal, results);
for name = names
    perUser.("theta_"+name) = theta.(name);
    perUser.("range_"+name) = rangeM.(name);
    perUser.("angleError_"+name) = theta.(name)-perUser.truthThetaDeg;
    perUser.("rangeError_"+name) = rangeM.(name)-perUser.truthRangeM;
end
perUser.kappa_P_A = cellfun(@(x) x.hessianA.kappaMPerDeg, results);
perUser.kappa_P_FA = cellfun(@(x) x.hessianFA.kappaMPerDeg, results);
perUser.validKappa_P_A = cellfun(@(x) x.hessianA.valid, results);
perUser.validKappa_P_FA = cellfun(@(x) x.hessianFA.valid, results);
perUser.gradientRange_P_A = cellfun( ...
    @(x) x.hessianA.gradientRangePerM, results);
perUser.gradientRange_P_FA = cellfun( ...
    @(x) x.hessianFA.gradientRangePerM, results);
perUser.peakRange_P_A = cellfun( ...
    @(x) x.modeA.selectedPeakRangeM, results);
perUser.peakRange_P_FA = cellfun( ...
    @(x) x.modeFA.selectedPeakRangeM, results);
perUser.peakMargin_P_A = cellfun(@(x) x.modeA.scoreMargin, results);
perUser.peakMargin_P_FA = cellfun(@(x) x.modeFA.scoreMargin, results);
perUser.selectedPeakDifferenceM = cellfun( ...
    @(x) x.selectedPeakDifferenceM, results);
perUser.predictedRangeDifferenceM = cellfun( ...
    @(x) x.predictedRangeDifferenceM, results);
perUser.actualRangeDifferenceM = cellfun( ...
    @(x) x.actualRangeDifferenceM, results);
for threshold = protocol.derivative.modeSensitivityM
    label = replace(compose("%.2f", threshold), ".", "p");
    perUser.("modeSwitch_"+label) = ...
        perUser.selectedPeakDifferenceM > threshold;
end
perUser.oracleLocalEndpoint = cellfun( ...
    @(x) x.oracleLocal.endpointHit, results);
perUser.oracleGlobalEndpoint = cellfun( ...
    @(x) x.oracleGlobal.endpointHit, results);
perUser.responseEvaluations = cellfun( ...
    @(x) x.responseEvaluations, results);
end

function output = summarizeMethods(perUser, protocol)
methods = ["P_A", "P_FA", "P_FAM5", "grid", ...
    "oracleLocal", "oracleGlobal"];
output = table();
for method = methods
    for scope = [string(protocol.r48.design.snrDb), "equal-SNR"]
        selected = selectScope(perUser, scope);
        ae = perUser.("angleError_"+method)(selected);
        re = perUser.("rangeError_"+method)(selected);
        output = [output; table(method, scope, nnz(selected), ...
            mean(ae.^2), sqrt(mean(ae.^2)), mean(re.^2), ...
            sqrt(mean(re.^2)), median(abs(re)), quantile(abs(re), .95), ...
            max(abs(re)), nnz(abs(re)>1), 'VariableNames', ...
            {'method', 'scope', 'n', 'angleMseDeg2', 'angleRmseDeg', ...
            'rangeMseM2', 'rangeRmseM', 'rangeMedianAbsM', ...
            'rangeP95AbsM', 'rangeMaximumAbsM', 'rangeMissAbove1m'})]; %#ok<AGROW>
    end
end
end

function output = summarizeBiasVariance(perUser, protocol)
output = table();
for method = ["P_A", "P_FA"]
    for scope = [string(protocol.r48.design.snrDb), "equal-SNR"]
        selected = selectScope(perUser, scope);
        error = perUser.("angleError_"+method)(selected);
        output = [output; table(method, scope, nnz(selected), ...
            mean(error), var(error, 1), mean(error.^2), ...
            'VariableNames', {'method', 'scope', 'n', ...
            'angleBiasDeg', 'angleVarianceDeg2', 'angleMseDeg2'})]; %#ok<AGROW>
    end
end
end

function output = summarizeRidge(perUser, protocol)
output = table();
for method = ["P_A", "P_FA"]
    for scope = [string(protocol.r48.design.snrDb), "equal-SNR"]
        selected = selectScope(perUser, scope);
        valid = selected & perUser.("validKappa_"+method);
        kappa = perUser.("kappa_"+method)(valid);
        angleMse = mean(perUser.("angleError_"+method)(selected).^2);
        rangeMse = mean(perUser.("rangeError_"+method)(selected).^2);
        rho = kappa.^2*angleMse/rangeMse;
        output = [output; table(method, scope, nnz(selected), nnz(valid), ...
            median(kappa), quantile(kappa, .25), quantile(kappa, .75), ...
            median(abs(kappa)), median(rho), quantile(rho, .25), ...
            quantile(rho, .75), 'VariableNames', {'method', 'scope', ...
            'n', 'validN', 'medianKappaMPerDeg', 'q1KappaMPerDeg', ...
            'q3KappaMPerDeg', 'medianAbsKappaMPerDeg', 'medianRho', ...
            'q1Rho', 'q3Rho'})]; %#ok<AGROW>
    end
end

sameMode = ~perUser.modeSwitch_0p10 ...
    & perUser.validKappa_P_A & perUser.validKappa_P_FA ...
    & isfinite(perUser.predictedRangeDifferenceM);
predicted = perUser.predictedRangeDifferenceM(sameMode);
actual = perUser.actualRangeDifferenceM(sameMode);
agreement = mean(sign(predicted) == sign(actual));
fit = table("P_FA-minus-P_A", "same-mode-0.10m", nnz(sameMode), ...
    safeCorrelation(predicted, actual), agreement, ...
    sqrt(mean((predicted-actual).^2)), sqrt(mean(actual.^2)), ...
    'VariableNames', {'method', 'scope', 'n', 'correlation', ...
    'signAgreement', 'predictionRmseM', 'actualDifferenceRmseM'});
output = struct(distribution=output, smoothPrediction=fit);
end

function output = summarizeDecomposition(perUser, protocol)
output = table();
epsilon = perUser.rangeError_oracleLocal;
for method = ["P_A", "P_FA"]
    for scope = [string(protocol.r48.design.snrDb), "equal-SNR"]
        selected = selectScope(perUser, scope) ...
            & perUser.("validKappa_"+method);
        eTheta = perUser.("angleError_"+method)(selected);
        eRange = perUser.("rangeError_"+method)(selected);
        kappa = perUser.("kappa_"+method)(selected);
        epsRange = epsilon(selected);
        angleTerm = (kappa.*eTheta).^2;
        epsilonTerm = epsRange.^2;
        crossTerm = 2*kappa.*eTheta.*epsRange;
        actualMse = mean(eRange.^2);
        predictedMse = mean(angleTerm+epsilonTerm+crossTerm);
        output = [output; table(method, scope, nnz(selected), actualMse, ...
            predictedMse, mean(angleTerm), mean(epsilonTerm), ...
            mean(crossTerm), mean(angleTerm)/actualMse, ...
            mean(epsilonTerm)/actualMse, mean(crossTerm)/actualMse, ...
            safeCorrelation(eTheta, epsRange), ...
            'VariableNames', {'method', 'scope', 'n', 'actualRangeMse', ...
            'predictedRangeMse', 'angleTerm', 'epsilonTerm', ...
            'crossTerm', 'angleFraction', 'epsilonFraction', ...
            'crossFraction', 'angleOracleErrorCorrelation'})]; %#ok<AGROW>
    end
end
end

function output = summarizeModes(perUser, protocol)
difference = perUser.rangeError_P_FA.^2-perUser.rangeError_P_A.^2;
output = table();
for scope = [string(protocol.r48.design.snrDb), "equal-SNR"]
    selected = selectScope(perUser, scope);
    totalDifference = sum(difference(selected));
    for threshold = protocol.derivative.modeSensitivityM
        switched = selected & perUser.selectedPeakDifferenceM > threshold;
        contribution = sum(difference(switched))/totalDifference;
        output = [output; table(scope, threshold, nnz(selected), ...
            nnz(switched), mean(switched(selected)), contribution, ...
            mean(difference(switched), "omitnan"), ...
            'VariableNames', {'scope', 'thresholdM', 'n', ...
            'switchCount', 'switchRate', 'netDifferenceShare', ...
            'meanSquaredErrorDifferenceOnSwitchRows'})]; %#ok<AGROW>
    end
end
end

function output = summarizeGridContinuous(perUser, protocol)
output = table();
for scope = [string(protocol.r48.design.snrDb), "equal-SNR"]
    selected = selectScope(perUser, scope);
    gridError = perUser.rangeError_grid(selected);
    continuousError = perUser.rangeError_P_FA(selected);
    paError = perUser.rangeError_P_A(selected);
    displacement = perUser.range_grid(selected)-perUser.range_P_FA(selected);
    output = [output; table(scope, nnz(selected), ...
        mean(gridError.^2)/mean(continuousError.^2), ...
        mean(gridError.^2)/mean(paError.^2), ...
        sqrt(mean(displacement.^2)), max(abs(displacement)), ...
        nnz(gridError.^2 < continuousError.^2), ...
        nnz(gridError.^2 == continuousError.^2), ...
        nnz(gridError.^2 > continuousError.^2), ...
        'VariableNames', {'scope', 'n', 'gridToContinuousMseRatio', ...
        'gridToPAMseRatio', 'rangeDisplacementRmsM', ...
        'rangeDisplacementMaximumM', 'gridWinCount', ...
        'gridTieCount', 'gridLossCount'})]; %#ok<AGROW>
end
end

function selected = selectScope(perUser, scope)
if scope == "equal-SNR"
    selected = true(height(perUser), 1);
else
    selected = perUser.snrDb == str2double(scope);
end
end

function value = safeCorrelation(left, right)
if numel(left) < 3 || std(left) == 0 || std(right) == 0
    value = nan;
else
    matrix = corrcoef(left, right);
    value = matrix(1, 2);
end
end
