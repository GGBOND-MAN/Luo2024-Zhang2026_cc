function [output, audit] = applyStressFront(front, row, protocol)
%APPLYSTRESSFRONT Replace only the L06 support center for controlled stress.

arguments
    front (1, 1) struct
    row (1, :) table
    protocol (1, 1) struct = r51.config()
end

output = front;
originalThetaDeg = front.selected.thetaDeg;
originalRangeM = front.selected.rangeM;
thetaDeg = row.truthThetaDeg;
rangeM = row.truthRangeM;
if row.stressType == "angle" || row.stressType == "joint"
    thetaDeg = thetaDeg+row.stressSign*protocol.stressDesign.angleOffsetDeg;
end
if row.stressType == "range" || row.stressType == "joint"
    rangeM = rangeM+row.stressSign*protocol.stressDesign.rangeOffsetM;
end
output.selected.thetaDeg = thetaDeg;
output.selected.rangeM = rangeM;
audit = struct(version="R51-controlled-front-center-stress-v1", ...
    stressType=row.stressType, stressSign=row.stressSign, ...
    originalThetaDeg=originalThetaDeg, originalRangeM=originalRangeM, ...
    stressedThetaDeg=thetaDeg, stressedRangeM=rangeM, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM);
end
