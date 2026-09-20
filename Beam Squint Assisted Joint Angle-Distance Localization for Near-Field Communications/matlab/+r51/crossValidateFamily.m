function output = crossValidateFamily(cfg, family, thetaDeg, ...
    baseThetaDeg, baseRangeM, baseInterval, split, feasibleRangeM, protocol)
%CROSSVALIDATEFAMILY Generate candidates on one split and score on the other.

arguments
    cfg (1, 1) struct
    family (1, 1) string {mustBeMember(family, ["wide_local", "remote"])}
    thetaDeg (1, 1) double {mustBeFinite}
    baseThetaDeg (1, 1) double {mustBeFinite}
    baseRangeM (1, 1) double {mustBeFinite, mustBePositive}
    baseInterval (1, 2) double {mustBeFinite}
    split (1, 1) struct
    feasibleRangeM (:, 1) double {mustBeFinite} = zeros(0, 1)
    protocol (1, 1) struct = r51.config()
end

if family == "wide_local"
    odd = r51.profileInterval(cfg, thetaDeg, split.odd, baseInterval, ...
        baseRangeM, protocol);
    even = r51.profileInterval(cfg, thetaDeg, split.even, baseInterval, ...
        baseRangeM, protocol);
    valid = true;
    basinConsistent = abs(odd.value-even.value) ...
        <= protocol.certificate.sameBasinRangeM;
    oddSide = 0;
    evenSide = 0;
else
    odd = r51.remoteProfile(cfg, thetaDeg, split.odd, baseInterval, ...
        feasibleRangeM, protocol);
    even = r51.remoteProfile(cfg, thetaDeg, split.even, baseInterval, ...
        feasibleRangeM, protocol);
    valid = odd.valid && even.valid;
    oddSide = odd.side;
    evenSide = even.side;
    basinConsistent = valid && oddSide == evenSide ...
        && abs(odd.value-even.value) ...
        <= protocol.certificate.sameBasinRangeM;
end

if valid
    oddRemoteScore = qScore(cfg, thetaDeg, even.value, split.odd);
    evenRemoteScore = qScore(cfg, thetaDeg, odd.value, split.even);
    oddBaseScore = qScore(cfg, baseThetaDeg, baseRangeM, split.odd);
    evenBaseScore = qScore(cfg, baseThetaDeg, baseRangeM, split.even);
    oddGain = oddRemoteScore-oddBaseScore;
    evenGain = evenRemoteScore-evenBaseScore;
    oddTolerance = numericTolerance( ...
        oddRemoteScore, oddBaseScore, protocol);
    evenTolerance = numericTolerance( ...
        evenRemoteScore, evenBaseScore, protocol);
    crossPassOdd = oddGain > oddTolerance;
    crossPassEven = evenGain > evenTolerance;
else
    oddGain = -inf;
    evenGain = -inf;
    oddTolerance = nan;
    evenTolerance = nan;
    crossPassOdd = false;
    crossPassEven = false;
end

output = struct(version="R51-split-spectrum-cross-fitted-candidate-v1", ...
    family=family, thetaDeg=thetaDeg, valid=valid, ...
    oddRangeM=fieldOrNaN(odd, "value"), ...
    evenRangeM=fieldOrNaN(even, "value"), ...
    oddGeneratedScore=fieldOrNaN(odd, "score"), ...
    evenGeneratedScore=fieldOrNaN(even, "score"), ...
    oddCrossGain=oddGain, evenCrossGain=evenGain, ...
    minimumCrossGain=min(oddGain, evenGain), ...
    oddTolerance=oddTolerance, evenTolerance=evenTolerance, ...
    crossPassOdd=crossPassOdd, crossPassEven=crossPassEven, ...
    basinConsistent=basinConsistent, oddSide=oddSide, evenSide=evenSide, ...
    accepted=valid && basinConsistent && crossPassOdd && crossPassEven, ...
    evaluationCount=fieldOrZero(odd, "evaluationCount") ...
        +fieldOrZero(even, "evaluationCount"));
end

function score = qScore(cfg, thetaDeg, rangeM, context)
score = r33.fixedAngleProfileLogScore(cfg, thetaDeg, rangeM, context);
end

function value = numericTolerance(first, second, protocol)
scale = max([1, abs(first), abs(second)]);
value = protocol.recovery.numericalToleranceScale*eps(scale);
end

function value = fieldOrNaN(input, name)
value = nan;
if isfield(input, name)
    value = input.(name);
end
end

function value = fieldOrZero(input, name)
value = 0;
if isfield(input, name)
    value = input.(name);
end
end
