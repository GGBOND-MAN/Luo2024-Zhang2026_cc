function result = round27Trial(setup, scan, row)
%ROUND27TRIAL Run paired convergence and same-angle distance ablations.
arguments
    setup (1,1) struct
    scan (1,1) struct
    row (1,:) table
end

cfg=setup.cfg;
index=setup.protocol.methodIndex;
count=numel(setup.protocol.methodNames);
result.version=setup.protocol.version;
result.thetaDeg=nan(1,count);
result.rangeM=nan(1,count);
result.initialThetaBoundary=nan(1,count);
result.initialRangeBoundary=nan(1,count);
result.finalThetaBoundary=nan(1,count);
result.finalRangeBoundary=nan(1,count);
result.profileFinalBoundary=nan(1,count);
result.musicStages=cell(1,count);
result.legacyFrontConverged=false;
result.stableFrontConverged=false;
result.allStartsConverged=false;
result.frontStatus="not_run";
result.frontScoreGain=NaN;
result.frontStationarity=NaN;
result.frontIterations=NaN;
result.frontAcceptedSteps=NaN;
result.frontSelectedStart=NaN;
result.frontRuntimeSeconds=NaN;
result.frontStartConverged=[];
result.frontStartStatus=strings(0,1);
result.frontStartIterations=[];
result.frontStartStationarity=[];
result.frontScoreHistory=[];
result.frontParameterHistory=[];
result.peakCarrierIndex=NaN;
result.success=false;
result.errorIdentifier="";
result.errorMessage="";
result.errorReport="";

try
    q=fsjad.exactSpectralResponse(cfg,deg2rad(row.truthThetaDeg),row.truthRangeM,scan);
    stream=RandStream("mt19937ar",Seed=row.seed);
    variance=mean(abs(q).^2)/10^(row.snrDb/10);
    beta=exp(1i*2*pi*rand(stream));
    noise=sqrt(variance/2)*(randn(stream,cfg.numSubcarriers,1) ...
        +1i*randn(stream,cfg.numSubcarriers,1));
    observation=beta*q+noise;
    [~,peak]=max(abs(observation).^2);
    result.peakCarrierIndex=peak-1;
    snapshots=jad.simulateSnapshots(cfg,row.truthThetaDeg,row.truthRangeM, ...
        row.snrDb,(0:cfg.numSubcarriers-1).',stream);

    legacy=fsjad.angleMultistartProfileEstimate(cfg,observation,scan, ...
        setup.zhang.frontOffsetsDeg);
    timer=tic;
    stable=fsjad.convergedFrontEstimate(cfg,observation,scan,legacy, ...
        MaxIterations=setup.protocol.maxIterations, ...
        StepTolerance=setup.protocol.stepTolerance);
    result.frontRuntimeSeconds=toc(timer);

    % A/B share the old front and exactly the same Zhang MUSIC angle.
    a=musicAt(cfg,snapshots,peak,legacy,setup.zhang,false);
    bProfile=profileAt(cfg,observation,a.thetaDeg,legacy.rangeM,scan,setup.ours);

    % C/D share the converged front and exactly the same Zhang MUSIC angle.
    c=musicAt(cfg,snapshots,peak,stable,setup.zhang,false);
    dProfile=profileAt(cfg,observation,c.thetaDeg,stable.rangeM,scan,setup.ours);

    fsjadMusic=musicAt(cfg,snapshots,peak,stable,setup.ours,false);
    fsjadProfile=profileAt(cfg,observation,fsjadMusic.thetaDeg, ...
        stable.rangeM,scan,setup.ours);
    frontProfile=profileAt(cfg,observation,stable.thetaDeg, ...
        stable.rangeM,scan,setup.ours);

    result.thetaDeg(index.LegacyFront)=legacy.thetaDeg;
    result.rangeM(index.LegacyFront)=legacy.rangeM;
    result.thetaDeg(index.StableFront)=stable.thetaDeg;
    result.rangeM(index.StableFront)=stable.rangeM;
    result.thetaDeg([index.A,index.B])=a.thetaDeg;
    result.rangeM(index.A)=a.rangeM;
    result.rangeM(index.B)=fuseProfile(legacy.rangeM,bProfile.rangeM,setup.ours);
    result.thetaDeg([index.C,index.D])=c.thetaDeg;
    result.rangeM(index.C)=c.rangeM;
    result.rangeM(index.D)=fuseProfile(stable.rangeM,dProfile.rangeM,setup.ours);
    result.thetaDeg(index.ZhangCached)=row.legacyZhangThetaDeg;
    result.rangeM(index.ZhangCached)=row.legacyZhangRangeM;
    result.thetaDeg(index.FsjadCached)=row.legacyFsjadThetaDeg;
    result.rangeM(index.FsjadCached)=row.legacyFsjadRangeM;
    result.thetaDeg([index.FsjadStable,index.FsjadMusic])=fsjadMusic.thetaDeg;
    result.rangeM(index.FsjadStable)=fuseProfile( ...
        stable.rangeM,fsjadProfile.rangeM,setup.ours);
    result.rangeM(index.FsjadMusic)=fsjadMusic.rangeM;
    result.thetaDeg(index.ProfileAtFront)=stable.thetaDeg;
    result.rangeM(index.ProfileAtFront)=fuseProfile( ...
        stable.rangeM,frontProfile.rangeM,setup.ours);
    result=storeMusic(result,[index.A,index.B],a);
    result=storeMusic(result,[index.C,index.D],c);
    result=storeMusic(result,[index.FsjadStable,index.FsjadMusic],fsjadMusic);
    result=storeProfileBoundary(result,index.B,bProfile);
    result=storeProfileBoundary(result,index.D,dProfile);
    result=storeProfileBoundary(result,index.FsjadStable,fsjadProfile);
    result=storeProfileBoundary(result,index.ProfileAtFront,frontProfile);

    result.legacyFrontConverged=legacy.converged;
    result.stableFrontConverged=stable.converged;
    result.allStartsConverged=all(stable.startConverged);
    result.frontStatus=stable.status;
    result.frontScoreGain=stable.score-legacy.score;
    result.frontStationarity=stable.stationarity;
    result.frontIterations=stable.iterations;
    result.frontAcceptedSteps=stable.acceptedSteps;
    result.frontSelectedStart=stable.selectedStart;
    result.frontStartConverged=stable.startConverged;
    result.frontStartStatus=string(cellfun(@(item) item.status, ...
        stable.allStarts,'UniformOutput',false));
    result.frontStartIterations=cellfun(@(item) item.iterations,stable.allStarts);
    result.frontStartStationarity=cellfun(@(item) item.stationarity,stable.allStarts);
    result.frontScoreHistory=stable.scoreHistory;
    result.frontParameterHistory=stable.parameterHistory;
    result.success=all(isfinite([result.thetaDeg,result.rangeM]));
catch exception
    result.errorIdentifier=string(exception.identifier);
    result.errorMessage=string(exception.message);
    result.errorReport=string(getReport(exception,'extended','hyperlinks','off'));
end
end

function music=musicAt(cfg,snapshots,peak,front,algorithm,fixedWindow)
cfg.subarraySize=algorithm.subarraySize;
cfg.numSubarrays=cfg.numAntennas-cfg.subarraySize+1;
cfg.localHalfWidthDeg=algorithm.localHalfWidthDeg;
cfg.localHalfWidthM=algorithm.localHalfWidthM;
cfg.gridSizes=algorithm.gridSizes;
carrierCount=algorithm.fusionCarrierCount;
first=max(0,min(peak-1-floor(carrierCount/2),cfg.numSubcarriers-carrierCount));
carriers=(first:first+carrierCount-1).';
music=jad.localMusicEstimate(cfg,snapshots(:,carriers+1),carriers, ...
    front.thetaDeg,front.rangeM,ConstrainToInitialWindow=fixedWindow);
end

function profile=profileAt(cfg,observation,thetaDeg,centerRangeM,scan,algorithm)
lower=max(cfg.rangeLimitsM(1),centerRangeM-algorithm.profileHalfWidthM);
upper=min(cfg.rangeLimitsM(2),centerRangeM+algorithm.profileHalfWidthM);
intervalCount=max(1,ceil((upper-lower)/algorithm.profileSpacingM));
rangeSeeds=linspace(lower,upper,intervalCount+1).';
profile=fsjad.profileRangeAtAngle(cfg,observation,thetaDeg,scan,rangeSeeds);
end

function rangeM=fuseProfile(frontRangeM,profileRangeM,algorithm)
rangeM=frontRangeM+algorithm.profileLambda*(profileRangeM-frontRangeM);
end

function result=storeMusic(result,indices,music)
for index=indices
    result.initialThetaBoundary(index)=music.initialThetaBoundary;
    result.initialRangeBoundary(index)=music.initialRangeBoundary;
    result.finalThetaBoundary(index)=music.finalThetaBoundary;
    result.finalRangeBoundary(index)=music.finalRangeBoundary;
    result.musicStages{index}=music.stages;
end
end

function result=storeProfileBoundary(result,index,profile)
endpoints=profile.rangeSeedsM([1,end]);
result.profileFinalBoundary(index)=min(abs(profile.rangeM-endpoints))<=1e-6;
end
