function output = basis(context, protocol)
%BASIS Orthonormal phase-nuisance basis on the selected carrier grid.
%   Gram-Schmidt on {1, t, t^2, ...} with uniform weight. Column 2 is the
%   degree-1 (delay) direction: it is returned only so that callers can
%   assert it is never used as a nuisance outside P_FACR_T.

arguments
    context (1, 1) struct
    protocol (1, 1) struct = r57.config()
end

frequencyHz = context.frequencyHz(:);
span = max(frequencyHz)-min(frequencyHz);
if span <= 0
    error("r57:DegenerateCarrierGrid", ...
        "The selected carrier set must span a positive bandwidth.");
end
t = (frequencyHz-mean(frequencyHz))/(span/2);
maxDegree = max([1, protocol.gain.dispersionDegrees]);
vectors = zeros(numel(t), maxDegree+1);
for degree = 0:maxDegree
    v = t.^degree;
    for previous = 1:degree
        v = v-(v.'*vectors(:, previous))*vectors(:, previous);
    end
    normValue = norm(v);
    if normValue <= 0
        error("r57:RankDeficientPhaseBasis", ...
            "The phase-nuisance basis lost rank at degree %d.", degree);
    end
    vectors(:, degree+1) = v/normValue;
end
degrees = protocol.gain.dispersionDegrees(:).';
if any(degrees == protocol.gain.forbiddenPhaseDegree)
    error("r57:ForbiddenPhaseDegree", ...
        "Degree %d is exactly collinear with the range score.", ...
        protocol.gain.forbiddenPhaseDegree);
end
output = struct(version="R57-orthonormal-phase-basis-v1", ...
    t=t, all=vectors, degrees=degrees, ...
    dispersion=vectors(:, degrees+1), ...
    delayDirection=vectors(:, protocol.gain.forbiddenPhaseDegree+1));
end
