function result = r35BracketedMusicRefinement( ...
    scoreFunction, thetaGridDeg, selectedIndex, gridBestScore, protocol)
%R35BRACKETEDMUSICREFINEMENT Refine only inside final-grid neighbors.

arguments
    scoreFunction (1, 1) function_handle
    thetaGridDeg (1, :) double {mustBeFinite}
    selectedIndex (1, 1) double {mustBeInteger, mustBePositive}
    gridBestScore (1, 1) double {mustBeFinite}
    protocol (1, 1) struct = r35SchemeAConfig()
end

if selectedIndex > numel(thetaGridDeg)
    error("r35:SelectedAngleIndexOutOfRange", ...
        "The selected final-grid index is out of range.");
end
if any(diff(thetaGridDeg) <= 0)
    error("r35:NonIncreasingFinalAngleGrid", ...
        "The actual final angle grid must be strictly increasing.");
end

thetaGrid = thetaGridDeg(selectedIndex);
result = emptyResult(thetaGrid, gridBestScore);
if selectedIndex == 1 || selectedIndex == numel(thetaGridDeg)
    result.status = "grid-endpoint-no-two-sided-bracket";
    return;
end

bracket = thetaGridDeg([selectedIndex-1, selectedIndex+1]);
settings = optimset("Display", "off", ...
    "TolX", protocol.tolXDeg, ...
    "MaxFunEvals", protocol.maximumFunctionEvaluations, ...
    "MaxIter", protocol.maximumIterations, "FunValCheck", "on");
timer = tic;
try
    [optimizerTheta, negativeScore, exitflag, output] = fminbnd( ...
        @(thetaDeg) -scalarScore(scoreFunction, thetaDeg), ...
        bracket(1), bracket(2), settings);
    optimizerScore = -negativeScore;
    optimizerValid = exitflag > 0 && isfinite(optimizerTheta) ...
        && isfinite(optimizerScore) ...
        && optimizerTheta >= bracket(1) ...
        && optimizerTheta <= bracket(2);
    if optimizerValid && optimizerScore > gridBestScore
        thetaCont = optimizerTheta;
        scoreAfter = optimizerScore;
        selectedSource = "continuous";
    else
        thetaCont = thetaGrid;
        scoreAfter = gridBestScore;
        selectedSource = "grid-retained";
    end
    if scoreAfter < gridBestScore-protocol.scoreTolerance
        error("r35:GridBestRetentionFailure", ...
            "The selected continuous score is below the grid best.");
    end
    result.thetaContDeg = thetaCont;
    result.bracketDeg = bracket;
    result.scoreAfter = scoreAfter;
    result.scoreGain = scoreAfter-gridBestScore;
    result.displacementDeg = thetaCont-thetaGrid;
    result.functionEvaluations = output.funcCount;
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
    error("r35:InvalidContinuousMusicScore", ...
        "The MUSIC objective must return one finite score.");
end
end

function result = emptyResult(thetaGrid, gridBestScore)
result = struct( ...
    thetaGridDeg=thetaGrid, thetaContDeg=thetaGrid, ...
    bracketDeg=[nan, nan], scoreBefore=gridBestScore, ...
    scoreAfter=gridBestScore, scoreGain=0, displacementDeg=0, ...
    functionEvaluations=0, exitflag=0, converged=false, ...
    optimizerThetaDeg=nan, optimizerScore=nan, ...
    selectedSource="grid-retained", status="not-run", ...
    runtimeSeconds=0, errorIdentifier="", errorMessage="");
end
