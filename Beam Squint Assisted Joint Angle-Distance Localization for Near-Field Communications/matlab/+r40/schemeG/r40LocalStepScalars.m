function output = r40LocalStepScalars(gradient, information, protocol)
%R40LOCALSTEPSCALARS Compute fixed-range and Schur raw angle steps.

arguments
    gradient (2, 1) double
    information (2, 2) double
    protocol (1, 1) struct = r40SchemeGProtocol()
end

gTheta = gradient(1);
gRange = gradient(2);
jThetaTheta = information(1, 1);
jThetaRange = information(1, 2);
jRangeRange = information(2, 2);
finitePass = all(isfinite([gradient; information(:)]));
jThetaTolerance = protocol.numerical.informationScaleTolerance ...
    *max(abs(jThetaTheta), 1);
jRangeTolerance = protocol.numerical.informationScaleTolerance ...
    *max(abs(jRangeRange), 1);
jThetaPass = jThetaTheta > jThetaTolerance;
jRangePass = jRangeRange > jRangeTolerance;
if jRangePass
    effectiveGradient = gTheta-jThetaRange/jRangeRange*gRange;
    effectiveInformation = jThetaTheta-jThetaRange^2/jRangeRange;
else
    effectiveGradient = nan;
    effectiveInformation = nan;
end
effectiveTolerance = protocol.numerical.informationScaleTolerance ...
    *max(abs(effectiveInformation), 1);
effectivePass = effectiveInformation > effectiveTolerance;
fixedValid = finitePass && jThetaPass && jRangePass;
schurValid = fixedValid && effectivePass;
fixedRawStepRad = nan;
schurRawStepRad = nan;
if fixedValid
    fixedRawStepRad = -gTheta/jThetaTheta;
end
if schurValid
    schurRawStepRad = -effectiveGradient/effectiveInformation;
end
coupling = nan;
informationRetention = nan;
if jThetaTheta > 0 && jRangeRange > 0
    coupling = jThetaRange/sqrt(jThetaTheta*jRangeRange);
    informationRetention = effectiveInformation/jThetaTheta;
end
output = struct(version="R40-local-step-scalars-v1", ...
    gTheta=gTheta, gRange=gRange, jThetaTheta=jThetaTheta, ...
    jThetaRange=jThetaRange, jRangeRange=jRangeRange, ...
    effectiveGradient=effectiveGradient, ...
    effectiveInformation=effectiveInformation, ...
    fixedRawStepRad=fixedRawStepRad, schurRawStepRad=schurRawStepRad, ...
    finitePass=finitePass, jThetaPass=jThetaPass, ...
    jRangePass=jRangePass, effectivePass=effectivePass, ...
    fixedValid=fixedValid, schurValid=schurValid, ...
    normalizedCoupling=coupling, ...
    effectiveInformationRatio=informationRetention);
end

