function result = r38BracketedVpmlRefinement( ...
    scoreFunction, thetaGridDeg, selectedIndex, protocol)
%R38BRACKETEDVPMLREFINEMENT Refine raw-array ML in one P_A bracket.

arguments
    scoreFunction (1, 1) function_handle
    thetaGridDeg (1, :) double {mustBeFinite}
    selectedIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r38SchemeFConfig()
end

if selectedIndex > numel(thetaGridDeg) || numel(thetaGridDeg) < 3 ...
        || any(diff(thetaGridDeg) <= 0)
    error("r38:InvalidFinalAngleGrid", ...
        "Scheme F requires the ordered actual final P_A grid.");
end

thetaBaseDeg = thetaGridDeg(selectedIndex);
timer = tic;
result = emptyResult(thetaBaseDeg);
if selectedIndex == 1 || selectedIndex == numel(thetaGridDeg)
    score = checkedScore(scoreFunction, thetaBaseDeg);
    result.bracketDeg = [thetaBaseDeg, thetaBaseDeg];
    result.fixedThetaDeg = thetaBaseDeg;
    result.fixedScore = score;
    result.thetaDeg = thetaBaseDeg;
    result.scoreBefore = score;
    result.scoreAfter = score;
    result.selectedSource = "P_A-retained";
    result.status = "final-grid-endpoint-retained";
    result.functionEvaluations = 1;
    result.runtimeSeconds = toc(timer);
    return;
end

fixedTheta = thetaGridDeg(selectedIndex+[-1, 0, 1]);
fixedScore = zeros(1, 3);
for index = 1:3
    fixedScore(index) = checkedScore(scoreFunction, fixedTheta(index));
end
observedEvaluations = 0;
continuousTheta = nan;
continuousScore = nan;
exitflag = nan;
reportedEvaluations = nan;
optimizerErrorIdentifier = "";
optimizerErrorMessage = "";
try
    settings = optimset("TolX", protocol.tolXDeg, "Display", "off");
    [continuousTheta, negativeScore, exitflag, details] = fminbnd( ...
        @objective, fixedTheta(1), fixedTheta(3), settings);
    continuousScore = -negativeScore;
    reportedEvaluations = details.funcCount;
catch exception
    optimizerErrorIdentifier = string(exception.identifier);
    optimizerErrorMessage = string(exception.message);
end

candidateTheta = fixedTheta(:);
candidateScore = fixedScore(:);
candidateSource = ["fixed-left"; "P_A-grid"; "fixed-right"];
converged = exitflag > 0 && isfinite(continuousTheta) ...
    && isfinite(continuousScore);
if converged
    candidateTheta(end+1, 1) = continuousTheta;
    candidateScore(end+1, 1) = continuousScore;
    candidateSource(end+1, 1) = "continuous-vpml";
end
[scoreAfter, selected] = max(candidateScore);
thetaDeg = candidateTheta(selected);
scoreBefore = fixedScore(2);
scoreTolerance = protocol.scoreScaleTolerance ...
    *max([1, abs(scoreBefore), abs(scoreAfter)]);
if scoreAfter < scoreBefore-scoreTolerance
    error("r38:VpmlCandidateRetentionInvariant", ...
        "Scheme F selected a score below the P_A grid candidate.");
end

result.bracketDeg = fixedTheta([1, 3]);
result.fixedThetaDeg = fixedTheta;
result.fixedScore = fixedScore;
result.thetaDeg = thetaDeg;
result.continuousThetaDeg = continuousTheta;
result.scoreBefore = scoreBefore;
result.scoreAfter = scoreAfter;
result.continuousScore = continuousScore;
result.scoreGain = scoreAfter-scoreBefore;
result.displacementDeg = thetaDeg-thetaBaseDeg;
result.functionEvaluations = 3+observedEvaluations;
result.reportedOptimizerEvaluations = reportedEvaluations;
result.observedOptimizerEvaluations = observedEvaluations;
result.exitflag = exitflag;
result.converged = converged;
result.selectedSource = candidateSource(selected);
result.bracketEndpointSelected = selected <= 3 && selected ~= 2;
result.optimizerErrorIdentifier = optimizerErrorIdentifier;
result.optimizerErrorMessage = optimizerErrorMessage;
if converged
    result.status = "completed";
else
    result.status = "optimizer-failed-fixed-candidate-selected";
end
result.runtimeSeconds = toc(timer);

    function negativeScore = objective(thetaCandidateDeg)
        observedEvaluations = observedEvaluations+1;
        negativeScore = -checkedScore(scoreFunction, thetaCandidateDeg);
    end
end

function score = checkedScore(scoreFunction, thetaDeg)
score = scoreFunction(thetaDeg);
if ~isscalar(score) || ~isfinite(score)
    error("r38:InvalidVpmlScore", ...
        "The VPML objective must return one finite scalar score.");
end
end

function result = emptyResult(thetaDeg)
result = struct(version="R38-bracketed-conditional-vpml-v1", ...
    thetaBaseDeg=thetaDeg, thetaDeg=thetaDeg, ...
    continuousThetaDeg=nan, bracketDeg=[nan, nan], ...
    fixedThetaDeg=nan(1, 3), fixedScore=nan(1, 3), ...
    scoreBefore=nan, scoreAfter=nan, continuousScore=nan, ...
    scoreGain=0, displacementDeg=0, functionEvaluations=0, ...
    reportedOptimizerEvaluations=nan, observedOptimizerEvaluations=0, ...
    exitflag=nan, converged=false, selectedSource="P_A-retained", ...
    bracketEndpointSelected=false, status="not-run", ...
    optimizerErrorIdentifier="", optimizerErrorMessage="", ...
    runtimeSeconds=0);
end
