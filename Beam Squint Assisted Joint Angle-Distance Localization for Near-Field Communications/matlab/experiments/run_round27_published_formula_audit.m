function run_round27_published_formula_audit(options)
%RUN_ROUND27_PUBLISHED_FORMULA_AUDIT Isolate the published trajectory issue.
arguments
    options.OutputRoot (1,1) string = ""
end

project=string(fileparts(fileparts(mfilename("fullpath"))));
originalPath=path;
addpath(project);
cleanup=onCleanup(@() path(originalPath));
if options.OutputRoot==""
    outputRoot=fullfile(project,"results","full_spectrum", ...
        "round27_published_formula_audit");
else
    outputRoot=options.OutputRoot;
end
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

cfg=jad.defaultConfig();
carrierIndex=(0:cfg.numSubcarriers-1).';
[thetaDeg,rangeM,frequencyHz]=jad.trajectory(cfg,carrierIndex);
insideDeclaredRange=rangeM>=cfg.rangeLimitsM(1) ...
    & rangeM<=cfg.rangeLimitsM(2);
trajectorySamples=table(carrierIndex,frequencyHz,thetaDeg,rangeM, ...
    insideDeclaredRange);

reportedThetaDeg=14.8;
reportedRangeM=29.5;
exampleCarrierIndex=carrierIndexForTheta(cfg,reportedThetaDeg);
[formulaThetaDeg,formulaRangeM]=jad.trajectory(cfg,exampleCarrierIndex);
[maximumRangeM,maximumIndex]=max(rangeM);
insideCount=sum(insideDeclaredRange);
insideFraction=insideCount/cfg.numSubcarriers;
[inclusiveThetaDeg,inclusiveRangeM]=jad.trajectory( ...
    cfg,[0;cfg.numSubcarriers]);

auditSummary=table(cfg.numSubcarriers,insideCount,insideFraction, ...
    maximumRangeM,thetaDeg(maximumIndex),reportedThetaDeg,reportedRangeM, ...
    formulaThetaDeg,formulaRangeM,formulaRangeM-reportedRangeM, ...
    thetaDeg(end),rangeM(end),inclusiveThetaDeg(end),inclusiveRangeM(end), ...
    'VariableNames',{'numSubcarriers','insideDeclaredRangeCount', ...
    'insideDeclaredRangeFraction','maximumRangeM','thetaAtMaximumRangeDeg', ...
    'reportedCoarseThetaDeg','reportedCoarseRangeM', ...
    'formulaThetaDeg','formulaRangeM','formulaMinusReportedRangeM', ...
    'lastSampleThetaDeg','lastSampleRangeM','inclusiveEndpointThetaDeg', ...
    'inclusiveEndpointRangeM'});

writetable(trajectorySamples,fullfile(outputRoot,"trajectory_samples.csv"));
writetable(auditSummary,fullfile(outputRoot,"audit_summary.csv"));
save(fullfile(outputRoot,"published_formula_audit.mat"), ...
    "cfg","trajectorySamples","auditSummary");

figureHandle=figure(Visible="off");
plot(thetaDeg,rangeM,LineWidth=1.5,DisplayName="Published equations (14)-(15)");
hold on;
yline(cfg.rangeLimitsM(2),"--",DisplayName="Declared maximum range");
scatter(reportedThetaDeg,reportedRangeM,50,"filled", ...
    DisplayName="Reported coarse point");
scatter(formulaThetaDeg,formulaRangeM,50,"filled", ...
    DisplayName="Formula at 14.8 deg");
hold off;
grid on;
xlabel("Angle (deg)");
ylabel("Range (m)");
title("Published trajectory formula consistency audit");
legend(Location="best");
exportgraphics(figureHandle,fullfile(outputRoot,"published_trajectory_audit.png"), ...
    Resolution=180);
savefig(figureHandle,fullfile(outputRoot,"published_trajectory_audit.fig"));
close(figureHandle);

assert(formulaRangeM>cfg.rangeLimitsM(2), ...
    "fsjad:Round27PublishedFormulaUnexpectedRange");
assert(maximumRangeM>cfg.rangeLimitsM(2), ...
    "fsjad:Round27PublishedTrajectoryUnexpectedCoverage");
disp(auditSummary);
fprintf("ROUND27_PUBLISHED_FORMULA_AUDIT_COMPLETE %s\n",outputRoot);
end

function carrierIndex=carrierIndexForTheta(cfg,thetaDeg)
thetaStart=deg2rad(cfg.thetaLimitsDeg(1));
thetaEnd=deg2rad(cfg.thetaLimitsDeg(2));
endWeight=(sind(thetaDeg)-sin(thetaStart))/(sin(thetaEnd)-sin(thetaStart));
fLow=cfg.fc-cfg.bandwidth/2;
frequencyOffset=endWeight*cfg.bandwidth*fLow/ ...
    (cfg.bandwidth+fLow-endWeight*cfg.bandwidth);
carrierIndex=frequencyOffset*cfg.numSubcarriers/cfg.bandwidth;
end
