function carrierIndex = selectLocalCarriers(numSubcarriers, count, peakCarrierIndex)
%SELECTLOCALCARRIERS Select a contiguous carrier set around the power peak.

arguments
    numSubcarriers (1, 1) double {mustBeInteger, mustBePositive}
    count (1, 1) double {mustBeInteger, mustBePositive}
    peakCarrierIndex (1, 1) double {mustBeInteger, mustBeNonnegative}
end

if count > numSubcarriers || peakCarrierIndex >= numSubcarriers
    error("r30:InvalidLocalCarrierRequest", ...
        "The carrier count and peak index must fit the available band.");
end
first = max(0, min(peakCarrierIndex - floor(count/2), ...
    numSubcarriers - count));
carrierIndex = (first:first+count-1).';
end
