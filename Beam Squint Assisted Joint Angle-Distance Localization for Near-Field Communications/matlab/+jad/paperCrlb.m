function [angleRmseDeg, rangeRmseM] = paperCrlb(cfg, thetaDeg, rangeM, snrDb)
%PAPERCRLB Implement Appendix B, equations (62)-(66), as printed.

thetaRad = deg2rad(thetaDeg);
x = cfg.elementIndex * cfg.elementSpacing;
scale = 2 * pi * cfg.fc / cfg.c;
dPhaseTheta = scale * (x * cos(thetaRad) ...
    - x.^2 * sin(2 * thetaRad) / (2 * rangeM));
dPhaseRange = -scale * (1 - x.^2 * cos(thetaRad)^2 / (2 * rangeM^2));

aTerm = sum(abs(dPhaseTheta).^2);
bTerm = real(sum(conj(dPhaseTheta) .* dPhaseRange));
cTerm = sum(abs(dPhaseRange).^2);
determinant = aTerm * cTerm - bTerm^2;
snrLinear = 10.^(snrDb / 10);

angleVarianceRad = cTerm ./ (2 * snrLinear * determinant);
rangeVariance = aTerm ./ (2 * snrLinear * determinant);
angleRmseDeg = rad2deg(sqrt(angleVarianceRad));
rangeRmseM = sqrt(rangeVariance);
end
