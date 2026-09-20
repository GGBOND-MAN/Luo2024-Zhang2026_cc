function carrierIndex = selectUniformCarriers(numSubcarriers, count, peakCarrierIndex)
%SELECTUNIFORMCARRIERS Select deterministic full-band carriers and the peak.

arguments
    numSubcarriers (1, 1) double {mustBeInteger, mustBePositive}
    count (1, 1) double {mustBeInteger, mustBePositive}
    peakCarrierIndex (1, 1) double {mustBeInteger, mustBeNonnegative}
end

if count > numSubcarriers || peakCarrierIndex >= numSubcarriers
    error("r30:InvalidCarrierRequest", ...
        "The carrier count and peak index must fit the available band.");
end
if count == 1
    carrierIndex = peakCarrierIndex;
    return;
end

carrierIndex = round(linspace(0, numSubcarriers - 1, count)).';
if ~ismember(peakCarrierIndex, carrierIndex)
    replaceable = (2:count-1).';
    if isempty(replaceable)
        replaceable = (1:count).';
    end
    [~, nearest] = min(abs(carrierIndex(replaceable) - peakCarrierIndex));
    carrierIndex(replaceable(nearest)) = peakCarrierIndex;
end
carrierIndex = unique(sort(carrierIndex));
if numel(carrierIndex) ~= count
    missing = setdiff((0:numSubcarriers-1).', carrierIndex, "stable");
    carrierIndex = sort([carrierIndex; missing(1:count-numel(carrierIndex))]);
end
end
