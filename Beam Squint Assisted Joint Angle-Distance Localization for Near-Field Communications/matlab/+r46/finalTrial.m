function result = finalTrial(cfg, scan, row, rowIndex, protocol)
%FINALTRIAL Execute one frozen R46 accuracy row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r46.config()
end

result = r45.trial(cfg, scan, row, rowIndex, protocol.r45);
result.finalProtocolVersion = protocol.version;
result.performanceExecution = "shared-exact-accuracy-not-runtime";
end
