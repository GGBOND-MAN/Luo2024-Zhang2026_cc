function result = r35BuildCarrierWeights( ...
    cfg, state, stateCost, method, protocol)
%R35BUILDCARRIERWEIGHTS Build one frozen parameter-free carrier weighting.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    stateCost (1, 1) struct
    method (1, 1) string {mustBeMember(method, ...
        ["D0_uniform", "D1_gap", "D2_information", "D3_mix"])}
    protocol (1, 1) struct = r35SchemeDConfig()
end

carrierCount = numel(state.frequencyHz);
timer = tic;
switch method
    case "D0_uniform"
        raw = ones(carrierCount, 1);
        rawGap = nan(carrierCount, 1);
        rawInformation = nan(carrierCount, 1);
    case "D1_gap"
        rawGap = gapReliability(stateCost, carrierCount);
        rawInformation = nan(carrierCount, 1);
        raw = rawGap;
    case "D2_information"
        rawGap = nan(carrierCount, 1);
        rawInformation = angleInformation(cfg, state);
        raw = rawInformation;
    case "D3_mix"
        rawGap = gapReliability(stateCost, carrierCount);
        rawInformation = angleInformation(cfg, state);
        raw = sqrt(rawGap.*rawInformation);
end

raw = real(raw(:));
if any(~isfinite(raw)) || any(raw < 0) || sum(raw) <= 0
    error("r35:InvalidSchemeDWeightMeasure", ...
        "The declared parameter-free carrier measure is invalid.");
end
weights = raw/sum(raw);
constructionSeconds = toc(timer);
if abs(sum(weights)-1) > protocol.weightSumTolerance
    error("r35:SchemeDWeightNormalizationFailure", ...
        "Carrier weights do not sum to one within the frozen tolerance.");
end

result = struct(version="R35-parameter-free-carrier-weights-v1", ...
    method=method, weights=weights, rawMeasure=raw, ...
    rawGap=rawGap, rawInformation=rawInformation, ...
    constructionSeconds=constructionSeconds, ...
    diagnostics=weightDiagnostics(weights, state.frequencyHz, protocol));
end

function rho = gapReliability(stateCost, carrierCount)
if ~isfield(stateCost, "relativeEigengap") ...
        || numel(stateCost.relativeEigengap) ~= carrierCount
    error("r35:MissingFrozenEigenGap", ...
        "D1/D3 require the eigengap saved by the frozen direct EVD.");
end
rho = max(real(stateCost.relativeEigengap(:)), 0);
end

function rho = angleInformation(cfg, state)
thetaRad = deg2rad(state.coarseThetaDeg);
[steering, derivativeRad] = r35AngleSteeringDerivative( ...
    cfg, state, thetaRad, state.coarseRangeM);
parallelCoefficient = sum(conj(steering).*derivativeRad, 1);
orthogonalDerivative = derivativeRad-steering.*parallelCoefficient;
rho = real(sum(abs(orthogonalDerivative).^2, 1)).';
rho = max(rho, 0);
end

function diagnostics = weightDiagnostics(weights, frequencyHz, protocol)
carrierCount = numel(weights);
positive = weights(weights > 0);
ordered = sort(weights, "descend");
edgeCount = max(1, round(protocol.edgeFractionPerSide*carrierCount));
centerCount = max(1, round(protocol.centerFraction*carrierCount));
centerFirst = floor((carrierCount-centerCount)/2)+1;
centerLast = centerFirst+centerCount-1;
edgeIds = [1:edgeCount, carrierCount-edgeCount+1:carrierCount];
centerIds = centerFirst:centerLast;
entropyTerms = weights(weights > 0).*log(weights(weights > 0));
diagnostics = struct(maxWeight=max(weights), ...
    minNonzeroWeight=min(positive), ...
    effectiveCarrierCount=1/sum(weights.^2), ...
    normalizedEntropy=-sum(entropyTerms)/log(carrierCount), ...
    top1Cumulative=sum(ordered(1:min(1, carrierCount))), ...
    top10Cumulative=sum(ordered(1:min(10, carrierCount))), ...
    top100Cumulative=sum(ordered(1:min(100, carrierCount))), ...
    weightedMeanFrequencyHz=sum(weights.*frequencyHz(:)), ...
    edgeCumulative=sum(weights(edgeIds)), ...
    centerCumulative=sum(weights(centerIds)), ...
    edgeCountPerSide=edgeCount, centerCount=centerCount);
end
