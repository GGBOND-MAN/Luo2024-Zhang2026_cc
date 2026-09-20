function variants = variantProtocols(protocol)
%VARIANTPROTOCOLS Build frozen R45 angle protocols for R49 candidates.

arguments
    protocol (1, 1) struct = r49.config()
end

names = protocol.method.candidates;
width = protocol.angle.widthDeg;
if numel(names) ~= numel(width)
    error("r49:VariantConfigurationMismatch", ...
        "Every R49 candidate requires exactly one angle width.");
end
variants = repmat(struct(name="", widthDeg=nan, angleProtocol=struct()), ...
    numel(names), 1);
base = protocol.r48.r47.r45;
for index = 1:numel(names)
    candidate = base;
    candidate.pfa.angleHalfWidthDeg = width(index);
    candidate.pfa.coarseAngleGridSize = ...
        round(2*width(index)/protocol.angle.gridSpacingDeg)+1;
    candidate.pfa.tolXDeg = protocol.angle.tolXDeg;
    variants(index) = struct(name=names(index), widthDeg=width(index), ...
        angleProtocol=candidate);
end
end
