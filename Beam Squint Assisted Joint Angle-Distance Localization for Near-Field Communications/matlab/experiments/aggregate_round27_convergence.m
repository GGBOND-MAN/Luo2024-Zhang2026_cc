function aggregate_round27_convergence(outputRoot)
%AGGREGATE_ROUND27_CONVERGENCE Verify coverage and summarize paired trials.
arguments
    outputRoot (1,1) string = ""
end

project=string(fileparts(fileparts(mfilename('fullpath'))));
if outputRoot==""
    outputRoot=fullfile(project,"results","full_spectrum", ...
        "round27_v3_0010_per_snr");
end
listing=dir(fullfile(outputRoot,"shard_*_of_*","shard_result.mat"));
assert(~isempty(listing),"fsjad:Round27NoShards");

design=table();
results=cell(0,1);
seen=zeros(numel(listing),1);
for fileIndex=1:numel(listing)
    saved=load(fullfile(listing(fileIndex).folder,listing(fileIndex).name));
    assert(isfile(fullfile(listing(fileIndex).folder,"COMPLETE.csv")), ...
        "fsjad:Round27IncompleteShard");
    if fileIndex==1
        setup=saved.setup;
    else
        assert(isequaln(setup,saved.setup),"fsjad:Round27DifferentProtocols");
    end
    assert(numel(saved.results)==height(saved.design) ...
        && all(cellfun(@(item) ~isempty(item) && item.success,saved.results)), ...
        "fsjad:Round27FailedResults");
    expected=saved.setup.design(mod(saved.setup.design.trialIndex-1, ...
        saved.setup.protocol.shardCount)==saved.shardId-1,:);
    assert(isequal(saved.design,expected),"fsjad:Round27ShardDesign");
    seen(fileIndex)=saved.shardId;
    design=[design;saved.design]; %#ok<AGROW>
    results=[results;saved.results]; %#ok<AGROW>
end
assert(isequal(sort(seen),(1:setup.protocol.shardCount).'), ...
    "fsjad:Round27ShardCoverage");
[design,order]=sortrows(design,{'snrDb','trialIndex'});
assert(isequal(design,sortrows(setup.design,{'snrDb','trialIndex'})), ...
    "fsjad:Round27TrialCoverage");
results=results(order);

theta=cell2mat(cellfun(@(item) item.thetaDeg,results,'UniformOutput',false));
range=cell2mat(cellfun(@(item) item.rangeM,results,'UniformOutput',false));
angleError=theta-design.truthThetaDeg;
rangeError=range-design.truthRangeM;
initialThetaBoundary=cell2mat(cellfun( ...
    @(item) item.initialThetaBoundary,results,'UniformOutput',false));
initialRangeBoundary=cell2mat(cellfun( ...
    @(item) item.initialRangeBoundary,results,'UniformOutput',false));
finalThetaBoundary=cell2mat(cellfun( ...
    @(item) item.finalThetaBoundary,results,'UniformOutput',false));
finalRangeBoundary=cell2mat(cellfun( ...
    @(item) item.finalRangeBoundary,results,'UniformOutput',false));
profileBoundary=cell2mat(cellfun( ...
    @(item) item.profileFinalBoundary,results,'UniformOutput',false));

trials=design;
for methodIndex=1:numel(setup.protocol.methodNames)
    methodName=setup.protocol.methodNames(methodIndex);
    trials.(methodName+"_thetaDeg")=theta(:,methodIndex);
    trials.(methodName+"_rangeM")=range(:,methodIndex);
end
trials.legacyFrontConverged=cellfun(@(item) item.legacyFrontConverged,results);
trials.stableFrontConverged=cellfun(@(item) item.stableFrontConverged,results);
trials.allStartsConverged=cellfun(@(item) item.allStartsConverged,results);
trials.frontStatus=string(cellfun(@(item) item.frontStatus, ...
    results,'UniformOutput',false));
trials.frontStationarity=cellfun(@(item) item.frontStationarity,results);
trials.frontScoreGain=cellfun(@(item) item.frontScoreGain,results);
trials.frontIterations=cellfun(@(item) item.frontIterations,results);
trials.frontAcceptedSteps=cellfun(@(item) item.frontAcceptedSteps,results);
trials.frontRuntimeSeconds=cellfun(@(item) item.frontRuntimeSeconds,results);
method=setup.protocol.methodIndex;
trials.bMinusARangeM=range(:,method.B)-range(:,method.A);
trials.dMinusCRangeM=range(:,method.D)-range(:,method.C);
trials.dMinusERangeM=range(:,method.D)-range(:,method.StableFront);
trials.stableMinusLegacyFrontRangeM=range(:,method.StableFront) ...
    -range(:,method.LegacyFront);
trials.aMinusZhangCachedThetaDeg=theta(:,method.A)-theta(:,method.ZhangCached);
trials.aMinusZhangCachedRangeM=range(:,method.A)-range(:,method.ZhangCached);

methodSummary=table();
pairedSummary=table();
boundarySummary=table();
convergenceSummary=table();
statusSummary=table();
snrValues=[-10,0,20];
for snrIndex=1:numel(snrValues)
    snrDb=snrValues(snrIndex);
    rows=design.snrDb==snrDb;
    for methodIndex=1:numel(setup.protocol.methodNames)
        methodName=setup.protocol.methodNames(methodIndex);
        absoluteRangeError=abs(rangeError(rows,methodIndex));
        absoluteAngleError=abs(angleError(rows,methodIndex));
        rangePercentiles=empiricalPercentile(absoluteRangeError,[0.5,0.9,0.95,0.99]);
        anglePercentiles=empiricalPercentile(absoluteAngleError,[0.5,0.95]);
        entry=table(methodName,snrDb,sum(rows), ...
            rms(angleError(rows,methodIndex)),rms(rangeError(rows,methodIndex)), ...
            rangePercentiles(1),rangePercentiles(2),rangePercentiles(3), ...
            rangePercentiles(4),max(absoluteRangeError), ...
            topSseShare(rangeError(rows,methodIndex),0.01), ...
            topSseShare(rangeError(rows,methodIndex),0.05), ...
            anglePercentiles(1),anglePercentiles(2), ...
            'VariableNames',{'method','snrDb','count','angleRmseDeg', ...
            'rangeRmseM','rangeMedianAbsM','rangeP90AbsM','rangeP95AbsM', ...
            'rangeP99AbsM','rangeMaxAbsM','rangeTop1PercentSseShare', ...
            'rangeTop5PercentSseShare','angleMedianAbsDeg','angleP95AbsDeg'});
        methodSummary=[methodSummary;entry]; %#ok<AGROW>

        boundaryEntry=table(methodName,snrDb,sum(rows), ...
            mean(initialThetaBoundary(rows,methodIndex),'omitnan'), ...
            mean(initialRangeBoundary(rows,methodIndex),'omitnan'), ...
            mean(finalThetaBoundary(rows,methodIndex),'omitnan'), ...
            mean(finalRangeBoundary(rows,methodIndex),'omitnan'), ...
            mean(profileBoundary(rows,methodIndex),'omitnan'), ...
            'VariableNames',{'method','snrDb','count', ...
            'initialThetaBoundaryRate','initialRangeBoundaryRate', ...
            'finalThetaBoundaryRate','finalRangeBoundaryRate', ...
            'profileBoundaryRate'});
        boundarySummary=[boundarySummary;boundaryEntry]; %#ok<AGROW>
    end

    for comparisonIndex=1:numel(setup.protocol.comparisonNames)
        pair=setup.protocol.comparisonPairs(comparisonIndex,:);
        methodError=rangeError(rows,pair(1));
        referenceError=rangeError(rows,pair(2));
        delta=methodError.^2-referenceError.^2;
        normalHalfWidth=1.96*std(delta)/sqrt(numel(delta));
        bootstrapSeed=setup.protocol.bootstrapSeed+1000*snrIndex+comparisonIndex;
        bootstrap=pairedBootstrap(methodError,referenceError, ...
            setup.protocol.bootstrapResamples,bootstrapSeed);
        tieTolerance=1e-12;
        absoluteDifference=abs(methodError)-abs(referenceError);
        entry=table(setup.protocol.comparisonNames(comparisonIndex), ...
            setup.protocol.methodNames(pair(1)),setup.protocol.methodNames(pair(2)), ...
            snrDb,numel(delta),mean(delta),mean(delta)-normalHalfWidth, ...
            mean(delta)+normalHalfWidth,bootstrap.mseLower,bootstrap.mseUpper, ...
            100*(1-rms(methodError)/rms(referenceError)), ...
            bootstrap.reductionLower,bootstrap.reductionUpper, ...
            mean(absoluteDifference<-tieTolerance), ...
            mean(abs(absoluteDifference)<=tieTolerance), ...
            topSseShare(methodError,0.01),topSseShare(referenceError,0.01), ...
            'VariableNames',{'comparison','method','reference','snrDb','count', ...
            'mseDifferenceM2','normalCi95LowerM2','normalCi95UpperM2', ...
            'bootstrapCi95LowerM2','bootstrapCi95UpperM2', ...
            'rmseReductionPercent','reductionCi95LowerPercent', ...
            'reductionCi95UpperPercent','methodWinRate','tieRate', ...
            'methodTop1PercentSseShare','referenceTop1PercentSseShare'});
        pairedSummary=[pairedSummary;entry]; %#ok<AGROW>
    end

    convergenceEntry=table(snrDb,sum(rows), ...
        mean(trials.legacyFrontConverged(rows)), ...
        mean(trials.stableFrontConverged(rows)), ...
        mean(trials.allStartsConverged(rows)), ...
        min(trials.frontScoreGain(rows)),max(trials.frontScoreGain(rows)), ...
        max(trials.frontStationarity(rows)),median(trials.frontIterations(rows)), ...
        max(trials.frontIterations(rows)),median(trials.frontRuntimeSeconds(rows)), ...
        max(abs(trials.aMinusZhangCachedThetaDeg(rows))), ...
        max(abs(trials.aMinusZhangCachedRangeM(rows))), ...
        'VariableNames',{'snrDb','count','legacyConvergedRate', ...
        'stableConvergedRate','allStartsConvergedRate','minScoreGain', ...
        'maxScoreGain','maxStationarity','medianIterations','maxIterations', ...
        'medianFrontRuntimeSeconds','zhangReproductionMaxThetaDifferenceDeg', ...
        'zhangReproductionMaxRangeDifferenceM'});
    convergenceSummary=[convergenceSummary;convergenceEntry]; %#ok<AGROW>

    statuses=unique(trials.frontStatus(rows));
    for statusIndex=1:numel(statuses)
        statusEntry=table(snrDb,statuses(statusIndex), ...
            sum(trials.frontStatus(rows)==statuses(statusIndex)), ...
            'VariableNames',{'snrDb','status','count'});
        statusSummary=[statusSummary;statusEntry]; %#ok<AGROW>
    end
end

folder=fullfile(outputRoot,'aggregate');
if ~isfolder(folder)
    mkdir(folder);
end
writetable(trials,fullfile(folder,'trials.csv'));
writetable(methodSummary,fullfile(folder,'method_summary.csv'));
writetable(pairedSummary,fullfile(folder,'paired_summary.csv'));
writetable(boundarySummary,fullfile(folder,'boundary_summary.csv'));
writetable(convergenceSummary,fullfile(folder,'convergence_summary.csv'));
writetable(statusSummary,fullfile(folder,'front_status_summary.csv'));
save(fullfile(folder,'round27_aggregate.mat'),'setup','design','results', ...
    'trials','methodSummary','pairedSummary','boundarySummary', ...
    'convergenceSummary','statusSummary','-v7.3');
disp(methodSummary);
disp(pairedSummary);
disp(convergenceSummary);
fprintf('ROUND27_AGGREGATE_COMPLETE %s\n',folder);
end

function bootstrap=pairedBootstrap(methodError,referenceError,resampleCount,seed)
stream=RandStream('mt19937ar',Seed=seed);
sampleCount=numel(methodError);
mseDifference=zeros(resampleCount,1);
reduction=zeros(resampleCount,1);
batchSize=1000;
for first=1:batchSize:resampleCount
    last=min(first+batchSize-1,resampleCount);
    indices=randi(stream,sampleCount,sampleCount,last-first+1);
    methodMse=mean(methodError(indices).^2,1).';
    referenceMse=mean(referenceError(indices).^2,1).';
    mseDifference(first:last)=methodMse-referenceMse;
    reduction(first:last)=100*(1-sqrt(methodMse)./sqrt(referenceMse));
end
mseBounds=empiricalPercentile(mseDifference,[0.025,0.975]);
reductionBounds=empiricalPercentile(reduction,[0.025,0.975]);
bootstrap.mseLower=mseBounds(1);
bootstrap.mseUpper=mseBounds(2);
bootstrap.reductionLower=reductionBounds(1);
bootstrap.reductionUpper=reductionBounds(2);
end

function percentiles=empiricalPercentile(values,probabilities)
values=sort(values(:));
if isscalar(values)
    percentiles=repmat(values,size(probabilities));
    return;
end
positions=1+(numel(values)-1)*probabilities;
lower=floor(positions);
upper=ceil(positions);
fraction=positions-lower;
percentiles=values(lower).'+fraction.*(values(upper).'-values(lower).');
end

function share=topSseShare(error,proportion)
squaredError=sort(error(:).^2,'descend');
total=sum(squaredError);
if total==0
    share=0;
    return;
end
count=max(1,ceil(proportion*numel(squaredError)));
share=sum(squaredError(1:count))/total;
end
