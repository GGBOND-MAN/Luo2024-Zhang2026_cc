function protocol = config()
%CONFIG Frozen finite acceptance and reference-front rules.
protocol.version = "R29-reference-front-backend-v1";
protocol.frontVersion = "R29-observation-only-reference-v1";
protocol.angleOffsetsDeg = [-0.2;-0.1;0;0.1;0.2];
protocol.initialSpacingM = 0.05;
protocol.peakCount = 16;
protocol.refinementLevels = 3;
protocol.maxIterations = 200;
protocol.stepTolerance = 1e-6;
protocol.scoreTolerance = 1e-10;
protocol.angleToleranceDeg = 1e-6;
protocol.rangeToleranceM = 1e-5;
protocol.modeAngleDeg = 0.01;
protocol.modeRangeM = 0.01;
protocol.anchorPolicy = "none-observation-only-not-identical-to-R28-v2";
protocol.solver = struct(InitialSpacingM=0.05, MinimumIntervals=40, ...
    RefinementLevels=3, PeakCount=8, TolX=1e-6, ...
    ScoreTolerance=1e-10, KeepTrace=false);
protocol.halfWidthsM = [2,4,8];
protocol.methodNames = ["E_star","C_star","H_star","M_n","P_n", ...
    "M_w","P_w","P_F_star","M_extended","P_extended"];
protocol.pairs = [7,6;7,3;7,8;6,4;7,5;4,2;10,9];
protocol.comparisonNames = ["Pw-Mw-primary","Pw-H-necessity", ...
    "Pw-PF-angle","Mw-Mn-window","Pw-Pn-window", ...
    "Mn-C-path-diagnostic","P-M-common-extension"];
protocol.bootstrapCount = 20000;
protocol.bootstrapSeed = 20260908;
protocol.noPerformanceGate = true;
protocol.noSignificanceStopping = true;
end
