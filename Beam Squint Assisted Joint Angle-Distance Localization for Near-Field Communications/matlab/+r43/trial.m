function result = trial(cfg, scan, row, rowIndex, protocol)
%TRIAL Execute one paired R43 development row.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
    rowIndex (1, 1) double {mustBeInteger, mustBePositive}
    protocol (1, 1) struct = r43.config()
end

result = struct(success=false, errorIdentifier="", errorMessage="", ...
    seed=row.seed, snrDb=row.snrDb, truthThetaDeg=row.truthThetaDeg, ...
    truthRangeM=row.truthRangeM);
try
    replay = fsjad.replayRound27Data(cfg, scan, row);
    orderIndex = mod(rowIndex-1, 3)+1;
    if orderIndex == 1
        order = "P_A-C-H";
        pa = runBaseline("P_A");
        c = runBaseline("C_enhanced");
        h = r43.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, protocol);
    elseif orderIndex == 2
        order = "C-H-P_A";
        c = runBaseline("C_enhanced");
        h = r43.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, protocol);
        pa = runBaseline("P_A");
    else
        order = "H-P_A-C";
        h = r43.estimate(cfg, replay.observation, replay.snapshots, ...
            scan, protocol);
        pa = runBaseline("P_A");
        c = runBaseline("C_enhanced");
    end
    front = h.front.selected;
    result.success = true;
    result.runtimeOrder = order;
    result.methodNames = ["P_A", "C_enhanced", "H_seqZ", ...
        "H_seqY", "H_seqZY", "F_L06"];
    result.thetaDeg = [pa.thetaDeg, c.thetaDeg, h.H_seqZ.thetaDeg, ...
        h.H_seqY.thetaDeg, h.H_seqZY.thetaDeg, front.thetaDeg];
    result.rangeM = [pa.rangeM, c.rangeM, h.H_seqZ.rangeM, ...
        h.H_seqY.rangeM, h.H_seqZY.rangeM, front.rangeM];
    commonH = h.cost.frontSeconds+h.cost.angleSeconds;
    result.runtimeSeconds = [pa.cost.totalOnlineSeconds, ...
        c.cost.totalOnlineSeconds, commonH+h.cost.zProfileSeconds, ...
        commonH+h.cost.yProfileSeconds, commonH+h.cost.zyProfileSeconds, ...
        h.cost.frontSeconds];
    result.h = h;
    result.pa = pa;
    result.c = c;
catch exception
    result.errorIdentifier = string(exception.identifier);
    result.errorMessage = string(getReport( ...
        exception, "extended", "hyperlinks", "off"));
end

    function baseline = runBaseline(method)
        baseline = r34.estimate(cfg, replay.observation, ...
            replay.snapshots, scan, method, r34.config());
    end
end
