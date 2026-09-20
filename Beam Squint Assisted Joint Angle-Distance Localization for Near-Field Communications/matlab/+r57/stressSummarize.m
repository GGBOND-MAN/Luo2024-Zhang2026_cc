function output = stressSummarize(design, results, protocol)
%STRESSSUMMARIZE Delay-stress curves plus the array-mode invariance check.

arguments
    design table
    results (:, 1) cell
    protocol (1, 1) struct = r57.config()
end

if numel(results) ~= height(design) || any(cellfun(@isempty, results)) ...
        || any(cellfun(@(item) ~item.success, results))
    error("r57:StressIncomplete", ...
        "Every delay-stress row must succeed before summarizing.");
end
methods = protocol.stress.methods;
perUser = design(:, ["positionId", "seed", "trialIndex", "snrDb", ...
    "truthThetaDeg", "truthRangeM", "mode", "levelIndex", ...
    "sigmaTauSeconds"]);
for method = methods
    rangeM = double(cellfun(@(item) double(item.(method).rangeM), results));
    perUser.("range_"+method) = rangeM;
    perUser.("rangeError_"+method) = rangeM-double(perUser.truthRangeM);
end
perUser.tauSeconds = double(cellfun(@(item) double(item.tauSeconds), results));
perUser.crlbHybridStdM = double(cellfun( ...
    @(item) double(item.crlbHybridStdM), results));
perUser.crlbCoherentStdM = double(cellfun( ...
    @(item) double(item.crlbCoherentStdM), results));
perUser.crlbFreeAlphaStdM = double(cellfun( ...
    @(item) double(item.crlbFreeAlphaStdM), results));
perUser.backendSeconds = double(cellfun( ...
    @(item) double(item.backendSeconds), results));

invariance = invarianceCheck(perUser, protocol);
curves = curveTable(perUser, protocol);
output = struct(version="R57-delay-stress-summary-v1", ...
    perUser=perUser, curves=curves, invariance=invariance, ...
    entersPrimaryJudgement=false);
end

function output = invarianceCheck(perUser, protocol)
%INVARIANCECHECK In array mode the injected phase is constant across the
%   aperture, so the free per-carrier gain of P_FALF absorbs it exactly and
%   P_A never sees it. Both estimates must be identical across every jitter
%   level for a given position and SNR. A deviation is an implementation
%   fault, not a finding.
output = table();
selected = perUser.mode == "array";
subset = perUser(selected, :);
tolerance = protocol.stress.invarianceToleranceM;
worst = 0;
for method = ["P_A", "P_FALF"]
    for positionId = unique(subset.positionId, "stable").'
        for snr = protocol.stress.snrDb
            rows = subset.positionId == positionId & subset.snrDb == snr;
            values = subset.("range_"+method)(rows);
            deviation = max(abs(values-values(1)));
            worst = max(worst, deviation);
            output = [output; table(method, double(positionId), ...
                double(snr), double(numel(values)), double(deviation), ...
                deviation <= tolerance, ...
                'VariableNames', {'method', 'positionId', 'snrDb', ...
                'levels', 'maxDeviationM', 'pass'})]; %#ok<AGROW>
        end
    end
end
if any(~output.pass)
    error("r57:StressInvarianceViolated", ...
        ['Array-mode injection changed P_A or P_FALF by up to %.3e m, ', ...
        'above the %.3e m tolerance. The free per-carrier gain must ', ...
        'absorb a constant-across-aperture phase exactly, so this is an ', ...
        'implementation fault.'], worst, tolerance);
end
end

function output = curveTable(perUser, protocol)
c = 299792458;
output = table();
for mode = protocol.stress.modes
    for snr = protocol.stress.snrDb
        for levelIndex = 1:numel(protocol.stress.sigmaTauSeconds)
            sigmaTau = protocol.stress.sigmaTauSeconds(levelIndex);
            rows = perUser.mode == mode & perUser.snrDb == snr ...
                & perUser.levelIndex == levelIndex;
            subset = perUser(rows, :);
            facr = sqrt(mean(subset.rangeError_P_FACR.^2));
            falf = sqrt(mean(subset.rangeError_P_FALF.^2));
            baseline = sqrt(mean(subset.rangeError_P_A.^2));
            hybrid = sqrt(mean(subset.crlbHybridStdM.^2));
            output = [output; table(mode, double(snr), double(sigmaTau), ...
                double(height(subset)), double(facr), double(falf), ...
                double(baseline), double(hybrid), ...
                double(c*sigmaTau), double(facr/hybrid), ...
                double(facr/falf), double(facr/baseline), ...
                'VariableNames', {'mode', 'snrDb', 'sigmaTauSeconds', ...
                'n', 'facrRmseM', 'pfalfRmseM', 'paRmseM', ...
                'hybridCrlbM', 'cTimesSigmaTauM', 'facrOverHybridCrlb', ...
                'facrOverPfalf', 'facrOverPa'})]; %#ok<AGROW>
        end
    end
end
end
