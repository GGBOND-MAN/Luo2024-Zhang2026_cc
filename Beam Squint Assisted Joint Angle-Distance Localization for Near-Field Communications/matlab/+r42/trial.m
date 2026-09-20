function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R42 development row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r42.config()
end

result = struct(success=false, errorIdentifier="", errorMessage="", ...
    seed=row.seed, snrDb=row.snrDb, truthThetaDeg=row.truthThetaDeg, ...
    truthRangeM=row.truthRangeM);
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    if mod(rowIndex, 2) == 1
        order = "P_A-then-H";
        pa = r32.estimatePA(cfg, replay.observation, replay.snapshots, ...
            scan, r32.config());
        h = r42.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, protocol);
    else
        order = "H-then-P_A";
        h = r42.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, protocol);
        pa = r32.estimatePA(cfg, replay.observation, replay.snapshots, ...
            scan, r32.config());
    end
    result.success = true;
    result.runtimeOrder = order;
    result.methodNames = ["P_A", "H_array", "H_joint", "F_L06"];
    result.thetaDeg = [pa.P_A.thetaDeg, h.array.thetaDeg, ...
        h.thetaDeg, h.front.selected.thetaDeg];
    result.rangeM = [pa.P_A.rangeM, h.array.rangeM, ...
        h.rangeM, h.front.selected.rangeM];
    result.runtimeSeconds = [pa.cost.totalOnlineSeconds, ...
        h.frontSeconds+h.arraySeconds, h.totalOnlineSeconds, ...
        h.frontSeconds];
    result.h = h;
    result.paCost = pa.cost;
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end
end
