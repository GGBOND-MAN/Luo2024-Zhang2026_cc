function logScore = localMusicLogScore(cfg, state, thetaDeg, rangeM, options)
%LOCALMUSICLOGSCORE Evaluate an unnormalized fused log-MUSIC score.

arguments
    cfg (1, 1) struct
    state (1, 1) struct
    thetaDeg double {mustBeFinite}
    rangeM double {mustBeFinite, mustBePositive}
    options.MaxPointsPerChunk (1, 1) double ...
        {mustBeInteger, mustBePositive} = 128
end

required = ["signalVectors", "carrierIndex", "frequencyHz", ...
    "referencePositionM", "subarraySize"];
if ~all(isfield(state, required))
    error("jad:IncompleteFrozenSubspace", ...
        "The frozen MUSIC state is missing required fields.");
end
if state.subarraySize ~= cfg.subarraySize ...
        || size(state.signalVectors, 1) ~= cfg.subarraySize
    error("jad:FrozenSubspaceSizeMismatch", ...
        "The frozen MUSIC state does not match cfg.subarraySize.");
end
if size(state.signalVectors, 2) ~= numel(state.carrierIndex) ...
        || numel(state.frequencyHz) ~= numel(state.carrierIndex)
    error("jad:FrozenSubspaceCarrierMismatch", ...
        "The frozen MUSIC state has inconsistent carrier dimensions.");
end

[thetaDeg, rangeM, outputSize] = expandInputs(thetaDeg, rangeM);
thetaVector = thetaDeg(:).';
rangeVector = rangeM(:).';
scoreVector = zeros(size(thetaVector));
x = state.referencePositionM(:);

for firstPoint = 1:options.MaxPointsPerChunk:numel(thetaVector)
    lastPoint = min(firstPoint + options.MaxPointsPerChunk - 1, ...
        numel(thetaVector));
    columns = firstPoint:lastPoint;
    thetaRad = deg2rad(thetaVector(columns));
    candidateRangeM = rangeVector(columns);
    chunkScore = zeros(1, numel(columns));
    for carrier = 1:numel(state.frequencyHz)
        distanceM = candidateRangeM - x*sin(thetaRad) ...
            + x.^2*(cos(thetaRad).^2./(2*candidateRangeM));
        steering = exp(-1i*2*pi*state.frequencyHz(carrier)/cfg.c ...
            .*distanceM)/sqrt(cfg.subarraySize);
        denominator = 1 - abs( ...
            state.signalVectors(:, carrier)'*steering).^2;
        denominator = max(real(denominator), eps);
        chunkScore = chunkScore - log(denominator);
    end
    scoreVector(columns) = chunkScore/numel(state.frequencyHz);
end

logScore = reshape(scoreVector, outputSize);
end

function [thetaDeg, rangeM, outputSize] = expandInputs(thetaDeg, rangeM)
if isscalar(thetaDeg)
    outputSize = size(rangeM);
    thetaDeg = repmat(thetaDeg, outputSize);
elseif isscalar(rangeM)
    outputSize = size(thetaDeg);
    rangeM = repmat(rangeM, outputSize);
elseif isequal(size(thetaDeg), size(rangeM))
    outputSize = size(thetaDeg);
else
    error("jad:MusicScoreSizeMismatch", ...
        "thetaDeg and rangeM must have equal sizes or one must be scalar.");
end
end
