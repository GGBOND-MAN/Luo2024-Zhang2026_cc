function [methods, paired] = statistics(design, results, protocol)
%STATISTICS Paired fixed-n summaries, bootstrap intervals, and Holm family.
arguments
    design table
    results cell
    protocol struct
end
theta = cell2mat(cellfun(@(r)r.thetaDeg,results,UniformOutput=false));
range = cell2mat(cellfun(@(r)r.rangeM,results,UniformOutput=false));
re = range-design.truthRangeM;
ae = theta-design.truthThetaDeg;
je = hypot(range.*sind(theta)-design.truthRangeM.*sind(design.truthThetaDeg), ...
    range.*cosd(theta)-design.truthRangeM.*cosd(design.truthThetaDeg));
methods = table(); paired = table();
for snr = [-10,0,20]
    rows = design.snrDb==snr;
    n = nnz(rows);
    stream = RandStream("mt19937ar",Seed=protocol.bootstrapSeed+snr+10);
    indices = randi(stream,n,n,protocol.bootstrapCount);
    for m = 1:numel(protocol.methodNames)
        e = re(rows,m);
        boot = mean(e(indices).^2,1);
        bounds = quantile(boot,[0.025,0.975]);
        sorted = sort(e.^2,"descend");
        denom = sum(sorted);
        q = quantile(abs(e),[.5,.9,.95,.99]);
        entry = table(snr,protocol.methodNames(m),n,mean(e.^2),sqrt(mean(e.^2)), ...
            bounds(1),bounds(2),sqrt(bounds(1)),sqrt(bounds(2)), ...
            sqrt(mean(ae(rows,m).^2)),sqrt(mean(je(rows,m).^2)), ...
            q(1),q(2),q(3),q(4),mean(abs(e)>1), ...
            sum(sorted(1:max(1,ceil(.01*n))))/max(denom,realmin), ...
            sum(sorted(1:max(1,ceil(.05*n))))/max(denom,realmin), ...
            'VariableNames',{'snrDb','method','n','mseM2','rmseM','mseLow','mseHigh', ...
            'rmseLow','rmseHigh','angleRmseDeg','jointRmseM','medianM','p90M','p95M', ...
            'p99M','missOver1m','top1PercentSse','top5PercentSse'});
        methods = [methods;entry]; %#ok<AGROW>
    end
    for k = 1:size(protocol.pairs,1)
        a = re(rows,protocol.pairs(k,1)); b = re(rows,protocol.pairs(k,2));
        d = a.^2-b.^2;
        boot = mean(d(indices),1);
        ci = quantile(boot,[.025,.975]);
        rmseBoot = sqrt(mean(a(indices).^2,1))-sqrt(mean(b(indices).^2,1));
        rci = quantile(rmseBoot,[.025,.975]);
        % Center the paired bootstrap at the null, with finite-resample correction.
        nullStatistics = mean((d(indices)-mean(d)),1);
        p = (1+nnz(abs(nullStatistics)>=abs(mean(d))))/(protocol.bootstrapCount+1);
        entry = table(snr,protocol.comparisonNames(k),n,mean(d),ci(1),ci(2), ...
            sqrt(mean(a.^2))-sqrt(mean(b.^2)),rci(1),rci(2), ...
            mean(abs(a)<abs(b)-1e-12),mean(abs(abs(a)-abs(b))<=1e-12),p,NaN, ...
            'VariableNames',{'snrDb','comparison','n','mseDelta','mseDeltaLow', ...
            'mseDeltaHigh','rmseDelta','rmseDeltaLow','rmseDeltaHigh','winRate', ...
            'tieRate','centeredBootstrapP','holmPrimaryP'});
        paired = [paired;entry]; %#ok<AGROW>
    end
end
rows = find(paired.comparison==protocol.comparisonNames(1));
[p,order] = sort(paired.centeredBootstrapP(rows));
adjusted = min(1,cummax(p.*(numel(p):-1:1).'));
paired.holmPrimaryP(rows(order)) = adjusted;
end
