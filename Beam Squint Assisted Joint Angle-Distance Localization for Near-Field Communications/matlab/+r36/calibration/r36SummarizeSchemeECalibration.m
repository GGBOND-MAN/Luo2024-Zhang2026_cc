function output = r36SummarizeSchemeECalibration( ...
    design, results, developmentMask, commonProtocol, calibrationProtocol)
%R36SUMMARIZESCHEMEECALIBRATION Summarize fixed all-600 and holdout-540.

arguments
    design table
    results cell
    developmentMask (:, 1) logical
    commonProtocol (1, 1) struct = r36CommonProtocol()
    calibrationProtocol (1, 1) struct = r36SchemeECalibrationProtocol()
end

if numel(developmentMask) ~= height(design) ...
        || nnz(developmentMask) ~= calibrationProtocol.development.requiredUsers
    error("r36:CalibrationDevelopmentMaskMismatch", ...
        "Calibration requires the fixed 60-row development overlap.");
end
holdoutMask = ~developmentMask;
if nnz(holdoutMask) ~= calibrationProtocol.calibration.holdoutUsers
    error("r36:CalibrationHoldoutMaskMismatch", ...
        "Calibration requires the fixed 540-row holdout subset.");
end

all600 = r36SummarizeSchemeE(design, results, commonProtocol);
holdout540 = r36SummarizeSchemeE( ...
    design(holdoutMask, :), results(holdoutMask), commonProtocol);
development60 = r36SummarizeSchemeE( ...
    design(developmentMask, :), results(developmentMask), commonProtocol);
all600.version = "R36-schemeE-calibration-all600-summary-v1";
all600.dataRole = calibrationProtocol.evidenceRole;
holdout540.version = "R36-schemeE-calibration-holdout540-summary-v1";
holdout540.dataRole = "fixed-nondevelopment-calibration-holdout-540";
development60.version = "R36-schemeE-calibration-overlap60-summary-v1";
development60.dataRole = "rerun-development-overlap-diagnostic";

gate = [tagGate(all600.gate, "all600"); ...
    tagGate(holdout540.gate, "holdout540")];
decision = table(all(all600.gate.pass), all(holdout540.gate.pass), ...
    all(all600.gate.pass) && all(holdout540.gate.pass), ...
    'VariableNames', {'all600GatePassed', 'holdout540GatePassed', ...
    'calibrationReady'});
perUser = all600.perUser;
perUser.subset = repmat("holdout540", height(perUser), 1);
perUser.subset(developmentMask) = "development-overlap60";
output = struct(version="R36-schemeE-calibration600-summary-v1", ...
    dataRole=calibrationProtocol.evidenceRole, perUser=perUser, ...
    all600=all600, holdout540=holdout540, ...
    developmentOverlap60=development60, gate=gate, ...
    decision=decision, calibrationReady=decision.calibrationReady);
end

function output = tagGate(input, population)
output = addvars(input, repmat(population, height(input), 1), ...
    Before=1, NewVariableNames="population");
end
