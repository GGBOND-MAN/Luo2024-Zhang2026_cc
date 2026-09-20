function output = finiteDifference2D(score, x, y, stepX, stepY)
%FINITEDIFFERENCE2D Central gradient and Hessian for a scalar score.

arguments
    score (1, 1) function_handle
    x (1, 1) double {mustBeFinite}
    y (1, 1) double {mustBeFinite}
    stepX (1, 1) double {mustBePositive}
    stepY (1, 1) double {mustBePositive}
end

f0 = checked(score(x, y));
fxMinus = checked(score(x-stepX, y));
fxPlus = checked(score(x+stepX, y));
fyMinus = checked(score(x, y-stepY));
fyPlus = checked(score(x, y+stepY));
fmm = checked(score(x-stepX, y-stepY));
fmp = checked(score(x-stepX, y+stepY));
fpm = checked(score(x+stepX, y-stepY));
fpp = checked(score(x+stepX, y+stepY));

gradient = [(fxPlus-fxMinus)/(2*stepX); ...
    (fyPlus-fyMinus)/(2*stepY)];
hxx = (fxMinus-2*f0+fxPlus)/stepX^2;
hyy = (fyMinus-2*f0+fyPlus)/stepY^2;
hxy = (fpp-fpm-fmp+fmm)/(4*stepX*stepY);
output = struct(value=f0, gradient=gradient, ...
    hessian=[hxx, hxy; hxy, hyy], evaluationCount=9, ...
    step=[stepX, stepY]);
end

function value = checked(value)
if ~isscalar(value) || ~isfinite(value)
    error("r50:InvalidFiniteDifferenceScore", ...
        "The finite-difference score must return one finite scalar.");
end
end
