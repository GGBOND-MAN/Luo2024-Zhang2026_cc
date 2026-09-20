function output = subsetScan(scan, carrierIndex)
%SUBSETSCAN Restrict a prepared scan to zero-based carrier indices.

arguments
    scan (1, 1) struct
    carrierIndex (:, 1) double {mustBeInteger, mustBeNonnegative}
end

columns = carrierIndex + 1;
if any(columns > numel(scan.wavenumber))
    error("r30:SubsetCarrierOutOfRange", ...
        "Every selected carrier must exist in the prepared scan.");
end
output = scan;
output.wavenumber = scan.wavenumber(columns);
output.beamformer = scan.beamformer(:, columns);
output.focusThetaDeg = scan.focusThetaDeg(columns);
output.focusRangeM = scan.focusRangeM(columns);
output.carrierIndex = carrierIndex;
end
