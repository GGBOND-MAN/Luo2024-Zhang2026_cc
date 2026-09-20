function result = r35BracketedSpectralRefinement( ...
    scoreFunction, thetaGridDeg, selectedIndex, protocol)
%R35BRACKETEDSPECTRALREFINEMENT Optimize the frozen spectral score locally.

arguments
    scoreFunction (1, 1) function_handle
    thetaGridDeg (1, :) double {mustBeFinite}
    selectedIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r35SchemeBConfig()
end

if selectedIndex > numel(thetaGridDeg)
    error("r35:SchemeBSelectedIndexOutOfRange", ...
        "The selected final-grid index is out of range.");
end
if numel(thetaGridDeg) < 2 || any(diff(thetaGridDeg) <= 0)
    error("r35:SchemeBInvalidFinalGrid", ...
        "The actual final angle grid must be strictly increasing.");
end

thetaA = thetaGridDeg(selectedIndex);
scoreA = scalarScore(scoreFunction, thetaA);
lowerIndex = max(1, selectedIndex-1);
upperIndex = min(numel(thetaGridDeg), selectedIndex+1);
bracket = thetaGridDeg([lowerIndex, upperIndex]);
boundaryFlag = selectedIndex == 1 || selectedIndex == numel(thetaGridDeg);
settings = optimset("Display", "off", ...
    "TolX", protocol.tolXDeg, ...
    "MaxFunEvals", protocol.maximumFunctionEvaluations, ...
    "MaxIter", protocol.maximumIterations, "FunValCheck", "on");

timer = tic;
result = emptyResult(thetaA, scoreA, bracket, boundaryFlag);
try
    [optimizerTheta, negativeScore, exitflag, output] = fminbnd( ...
        @(thetaDeg) -scalarScore(scoreFunction, thetaDeg), ...
        bracket(1), bracket(2), settings);
    optimizerScore = -negativeScore;
    optimizerValid = exitflag > 0 && isfinite(optimizerTheta) ...
        && isfinite(optimizerScore) ...
        && optimizerTheta >= bracket(1) ...
        && optimizerTheta <= bracket(2);
    if optimizerValid && optimizerScore > scoreA
        thetaB = optimizerTheta;
        scoreB = optimizerScore;
        selectedSource = "spectral-continuous";
    else
        thetaB = thetaA;
        scoreB = scoreA;
        selectedSource = "theta_A-retained";
    end
    if scoreB < scoreA-protocol.scoreTolerance
        error("r35:SchemeBScoreRetentionFailure", ...
            "The selected spectral score is below the theta_A score.");
    end
    result.thetaSpectralDeg = thetaB;
    result.scoreAfter = scoreB;
    result.scoreGain = scoreB-scoreA;
    result.displacementDeg = thetaB-thetaA;
    result.functionEvaluations = 1+output.funcCount;
    result.exitflag = exitflag;
    result.converged = optimizerValid;
    result.optimizerThetaDeg = optimizerTheta;
    result.optimizerScore = optimizerScore;
    result.selectedSource = selectedSource;
    result.status = "completed";
catch exception
    result.status = "optimizer-exception";
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(exception.message);
end
result.runtimeSeconds = toc(timer);
end

function score = scalarScore(scoreFunction, thetaDeg)
score = scoreFunction(thetaDeg);
if ~isscalar(score) || ~isfinite(score)
    error("r35:SchemeBInvalidSpectralScore", ...
        "The spectral objective must return one finite score.");
end
end

function result = emptyResult(thetaA, scoreA, bracket, boundaryFlag)
result = struct(thetaBaseDeg=thetaA, thetaSpectralDeg=thetaA, ...
    bracketDeg=bracket, boundaryFlag=boundaryFlag, ...
    scoreBefore=scoreA, scoreAfter=scoreA, scoreGain=0, ...
    displacementDeg=0, functionEvaluations=1, exitflag=0, ...
    converged=false, optimizerThetaDeg=nan, optimizerScore=nan, ...
    selectedSource="theta_A-retained", status="not-run", ...
    runtimeSeconds=0, errorIdentifier="", errorMessage="");
end
