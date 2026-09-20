function output = summarizeFinal(design, results, protocol)
%SUMMARIZEFINAL Apply corrected R32-frozen statistics to the exact final design.

arguments
    design table
    results cell
    protocol (1, 1) struct = r34.config()
end

if height(design) ~= protocol.finalTest.expectedRows ...
        || r32.designHash(design) ~= protocol.finalTest.designHash
    error("r34:FinalDesignIdentityMismatch", ...
        "Final inference requires the exact unchanged 1400-row design.");
end
output = r34.summarizePaired(design, results, protocol);
output.statisticsVersion = protocol.statisticsVersion;
output.finalDesignHash = protocol.finalTest.designHash;
end
