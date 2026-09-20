function output = basinCertificate(front, frozenR51, protocol)
%BASINCERTIFICATE Add C3b to the frozen R51 observable certificates.

arguments
    front (1, 1) struct
    frozenR51 (1, 1) struct
    protocol (1, 1) struct = r52.config()
end

audit = frozenR51.certificate.candidateAudit;
[~, oddIndex] = max(audit.oddLogScore);
[~, evenIndex] = max(audit.evenLogScore);
odd = [audit.thetaDeg(oddIndex), audit.rangeM(oddIndex)];
even = [audit.thetaDeg(evenIndex), audit.rangeM(evenIndex)];
frontBasin = [front.selected.thetaDeg, front.selected.rangeM];
sameOddEven = sameBasin(odd, even, protocol);
sameOddFront = sameBasin(odd, frontBasin, protocol);
sameEvenFront = sameBasin(even, frontBasin, protocol);
c3a = frozenR51.certificate.C3;
c3b = sameOddEven && ~sameOddFront && ~sameEvenFront;
c3star = c3a || c3b;
trigger = frozenR51.certificate.C1 || frozenR51.certificate.C2 ...
    || c3star || frozenR51.certificate.C4;
output = struct(version="R52-basin-consistency-certificate-v1", ...
    C1=frozenR51.certificate.C1, C2=frozenR51.certificate.C2, ...
    C3a=c3a, C3b=c3b, C3star=c3star, C4=frozenR51.certificate.C4, ...
    trigger=trigger, oddCandidateIndex=oddIndex, ...
    evenCandidateIndex=evenIndex, oddThetaDeg=odd(1), ...
    oddRangeM=odd(2), evenThetaDeg=even(1), evenRangeM=even(2), ...
    frontThetaDeg=frontBasin(1), frontRangeM=frontBasin(2), ...
    sameOddEven=sameOddEven, sameOddFront=sameOddFront, ...
    sameEvenFront=sameEvenFront);
end

function value = sameBasin(first, second, protocol)
value = abs(first(1)-second(1)) <= protocol.basin.angleToleranceDeg ...
    && abs(first(2)-second(2)) <= protocol.basin.rangeToleranceM;
end
