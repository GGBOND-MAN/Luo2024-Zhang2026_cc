function audit_round26_theory
%AUDIT_ROUND26_THEORY Deterministic diagnostics of model assumptions.

project = fileparts(fileparts(mfilename("fullpath")));
addpath(project);
cleanup = onCleanup(@() rmpath(project));
output = fullfile(project,"results","full_spectrum","round26_audit");
if ~isfolder(output)
    mkdir(output);
end
cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
locations = [15,30;35,17;-55,48];
informationAudit = table();
for i=1:size(locations,1)
    [q,D] = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(locations(i,1)),locations(i,2),scan);
    % The delay nuisance is real, with units of equivalent path length (m).
    delayDerivative = -1i*scan.wavenumber.*q;
    J = [D,delayDerivative];
    projected = J-q*(q'*J/(q'*q));
    I = real(projected'*projected);
    gainOnly = I(1:2,1:2);
    withDelay = gainOnly-I(1:2,3)*(I(3,3)\I(3,1:2));
    withDelay = (withDelay+withDelay')/2;
    row=table(locations(i,1),locations(i,2),gainOnly(2,2), ...
        withDelay(2,2),withDelay(2,2)/gainOnly(2,2), ...
        'VariableNames',{'thetaDeg','rangeM','rangeInfoKnownTiming', ...
        'rangeInfoUnknownTiming','retainedConditionalRangeInfo'});
    informationAudit=[informationAudit;row]; %#ok<AGROW>
end
writetable(informationAudit,fullfile(output,"timing_information.csv"));

% Direct noiseless subarray alignment calculation, independent of MUSIC code.
theta = 35;
range = 17;
L = 160;
P = cfg.numAntennas-L+1;
referenceStart = floor((P+1)/2);
x = cfg.elementIndex*cfg.elementSpacing;
referenceX = x(referenceStart:referenceStart+L-1);
waveNumber = 2*pi*cfg.fc/cfg.c;
distance = @(v,t,r) r-v*sind(t)+v.^2*cosd(t)^2/(2*r);
signal = exp(-1i*waveNumber*distance(x,theta,range));
reference = exp(-1i*waveNumber*distance(referenceX,theta,range))/sqrt(L);
compensationAudit = table();
for errorM=[0,0.1,1]
    coarseRange = range+errorM;
    aligned=zeros(L,P);
    for p=1:P
        ids=p:p+L-1;
        phase=exp(-1i*waveNumber*(distance(referenceX,theta,coarseRange) ...
            -distance(x(ids),theta,coarseRange)));
        aligned(:,p)=phase.*signal(ids);
    end
    covariance=aligned*aligned'/P;
    [U,e]=eig((covariance+covariance')/2,'vector');
    [e,order]=sort(real(e),'descend');
    defect=1-abs(U(:,order(1))'*reference)^2;
    row=table(errorM,max(0,e(2))/e(1),max(0,defect), ...
        'VariableNames',{'coarseRangeErrorM','secondToFirstEigenvalue', ...
        'trueSteeringNoiseProjection'});
    compensationAudit=[compensationAudit;row]; %#ok<AGROW>
end
writetable(compensationAudit,fullfile(output,"noiseless_compensation.csv"));

% Replay only an existing calibration outlier's front end to diagnose its cause.
saved=load(fullfile(project,"results","full_spectrum", ...
    "round26_zhang_large_joint_mc","zhang_joint_mc_optimization.mat"));
row=saved.calibrationDesign(saved.calibrationDesign.seed==36400431,:);
q=fsjad.exactSpectralResponse(cfg,deg2rad(row.truthThetaDeg),row.truthRangeM,scan);
stream=RandStream("mt19937ar",Seed=row.seed);
noiseVariance=mean(abs(q).^2)/10^(row.snrDb/10);
beta=exp(1i*2*pi*rand(stream));
noise=sqrt(noiseVariance/2)*(randn(stream,cfg.numSubcarriers,1) ...
    +1i*randn(stream,cfg.numSubcarriers,1));
front=fsjad.angleMultistartProfileEstimate(cfg,beta*q+noise,scan, ...
    saved.selectedAlgorithm.frontOffsetsDeg);
continued=fsjad.refineProfileEstimate(cfg,beta*q+noise,front.thetaDeg, ...
    front.rangeM,scan,100);
reach=saved.selectedAlgorithm.localHalfWidthM;
half=reach;
for g=saved.selectedAlgorithm.gridSizes(1:end-1)
    half=4*half/(g-1);
    reach=reach+half;
end
replay=table(row.seed,row.truthThetaDeg,row.truthRangeM,front.thetaDeg, ...
    front.rangeM,front.rangeM-row.truthRangeM,front.converged, ...
    front.iterations,reach,'VariableNames', ...
    {'seed','truthThetaDeg','truthRangeM','frontThetaDeg', ...
    'frontRangeM','frontRangeErrorM','frontConverged', ...
    'frontIterations','musicMaximumReachM'});
replay.continuedRangeErrorM=continued.rangeM-row.truthRangeM;
replay.continuedConverged=continued.converged;
replay.originalProfileScore=front.score;
replay.continuedProfileScore=continued.score;
writetable(replay,fullfile(output,"calibration_outlier_front.csv"));
save(fullfile(output,"calibration_outlier_front.mat"), ...
    "front","row","reach","continued");
disp(informationAudit);
disp(compensationAudit);
disp(replay);
end
