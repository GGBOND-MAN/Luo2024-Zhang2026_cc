function result = screenStressRow(cfg, scan, row, rowIndex, protocol)
%SCREENSTRESSROW Classify natural L06 support misses without certificates.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r52.config()
end

result = struct(success=false, rowIndex=rowIndex, ...
    positionId=row.positionId, seed=row.seed, snrDb=row.snrDb, ...
    truthThetaDeg=row.truthThetaDeg, truthRangeM=row.truthRangeM, ...
    errorIdentifier="", errorMessage="");
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    front = r33.front(cfg, replay.observation, scan, ...
        protocol.base.r34.r32, r32.candidate(protocol.base.r34.r32));
    angleMiss = abs(row.truthThetaDeg-front.selected.thetaDeg) ...
        > protocol.support.angleHalfWidthDeg;
    rangeMiss = abs(row.truthRangeM-front.selected.rangeM) ...
        > protocol.support.rangeHalfWidthM;
    supportClass = "none";
    if angleMiss && rangeMiss
        supportClass = "joint";
    elseif angleMiss
        supportClass = "angle";
    elseif rangeMiss
        supportClass = "range";
    end
    result.success = true;
    result.frontThetaDeg = front.selected.thetaDeg;
    result.frontRangeM = front.selected.rangeM;
    result.angleSupportMiss = angleMiss;
    result.rangeSupportMiss = rangeMiss;
    result.supportClass = supportClass;
    result.frontRuntimeSeconds = front.runtimeSeconds;
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end
