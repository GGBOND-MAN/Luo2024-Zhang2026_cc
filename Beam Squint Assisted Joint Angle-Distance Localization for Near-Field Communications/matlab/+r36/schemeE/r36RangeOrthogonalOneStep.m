function result = r36RangeOrthogonalOneStep( ...
    cfg, state, thetaGridDeg, selectedIndex, rangeM, protocol)
%R36RANGEORTHOGONALONESTEP Apply one range-profiled local Newton update.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    thetaGridDeg (1, :) double {mustBeFinite}
    selectedIndex (1, 1) double {mustBeInteger, mustBePositive}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r36SchemeEConfig()
end

if selectedIndex > numel(thetaGridDeg) || numel(thetaGridDeg) < 3 ...
        || any(diff(thetaGridDeg) <= 0)
    error("r36:InvalidFinalAngleGrid", ...
        "Scheme E requires the actual ordered final P_A angle grid.");
end

thetaBaseDeg = thetaGridDeg(selectedIndex);
result = emptyResult(thetaBaseDeg, rangeM);
if selectedIndex == 1 || selectedIndex == numel(thetaGridDeg)
    result.status = "final-grid-endpoint-retained";
    return;
end
result.bracketDeg = thetaGridDeg(selectedIndex+[-1, 1]);
timer = tic;
linearization = r36SubspaceResidualGaussNewton( ...
    cfg, state, deg2rad(thetaBaseDeg), rangeM);
gTheta = linearization.gradient(1);
gRange = linearization.gradient(2);
jThetaTheta = linearization.information(1, 1);
jThetaRange = linearization.information(1, 2);
jRangeRange = linearization.information(2, 2);
rangeTolerance = protocol.informationScaleTolerance ...
    *max(abs(jRangeRange), 1);
finitePass = all(isfinite([linearization.gradient; ...
    linearization.information(:)]));
rangeInformationPass = jRangeRange > rangeTolerance;
if rangeInformationPass
    effectiveGradient = gTheta-jThetaRange/jRangeRange*gRange;
    effectiveInformation = jThetaTheta ...
        -jThetaRange^2/jRangeRange;
else
    effectiveGradient = nan;
    effectiveInformation = nan;
end
effectiveTolerance = protocol.informationScaleTolerance ...
    *max(abs(effectiveInformation), 1);
effectiveInformationPass = effectiveInformation > effectiveTolerance;
valid = finitePass && rangeInformationPass && effectiveInformationPass;

result.linearization = linearization;
result.finitePass = finitePass;
result.rangeInformationPass = rangeInformationPass;
result.effectiveInformationPass = effectiveInformationPass;
result.effectiveGradient = effectiveGradient;
result.effectiveInformation = effectiveInformation;
result.couplingCoefficient = jThetaRange ...
    /sqrt(max(jThetaTheta*jRangeRange, eps));
if valid
    rawDeltaThetaRad = -effectiveGradient/effectiveInformation;
    rawThetaDeg = thetaBaseDeg+rad2deg(rawDeltaThetaRad);
    thetaDeg = min(max(rawThetaDeg, result.bracketDeg(1)), ...
        result.bracketDeg(2));
    deltaThetaRad = deg2rad(thetaDeg-thetaBaseDeg);
    deltaRangeM = -(gRange+jThetaRange*deltaThetaRad)/jRangeRange;
    diagnosticRangeM = rangeM+deltaRangeM;
    actualAfter = r36SubspaceResidualGaussNewton( ...
        cfg, state, deg2rad(thetaDeg), diagnosticRangeM);
    predictedCostReduction = -(effectiveGradient*deltaThetaRad ...
        +0.5*effectiveInformation*deltaThetaRad^2);
    result.thetaDeg = thetaDeg;
    result.rawThetaDeg = rawThetaDeg;
    result.displacementDeg = thetaDeg-thetaBaseDeg;
    result.rawDisplacementDeg = rawThetaDeg-thetaBaseDeg;
    result.diagnosticRangeM = diagnosticRangeM;
    result.diagnosticRangeDisplacementM = deltaRangeM;
    result.predictedCostReduction = predictedCostReduction;
    result.actualCostAfter = actualAfter.cost;
    result.actualCostReduction = linearization.cost-actualAfter.cost;
    result.clippedToBracket = thetaDeg ~= rawThetaDeg;
    result.selectedSource = "range-orthogonal-one-step";
    result.status = "completed";
    result.validUpdate = true;
else
    result.status = "invalid-information-retained";
end
result.runtimeSeconds = toc(timer);
end

function result = emptyResult(thetaDeg, rangeM)
result = struct(version="R36-range-orthogonal-one-step-v1", ...
    thetaBaseDeg=thetaDeg, thetaDeg=thetaDeg, rawThetaDeg=thetaDeg, ...
    bracketDeg=[nan, nan], displacementDeg=0, ...
    rawDisplacementDeg=0, diagnosticRangeM=rangeM, ...
    diagnosticRangeDisplacementM=0, predictedCostReduction=0, ...
    actualCostAfter=nan, actualCostReduction=0, clippedToBracket=false, ...
    selectedSource="P_A-retained", status="not-run", ...
    validUpdate=false, finitePass=false, rangeInformationPass=false, ...
    effectiveInformationPass=false, effectiveGradient=nan, ...
    effectiveInformation=nan, couplingCoefficient=nan, ...
    linearization=struct(), runtimeSeconds=0);
end
