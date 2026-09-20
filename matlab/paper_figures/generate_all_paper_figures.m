function generate_all_paper_figures(root)
%GENERATE_ALL_PAPER_FIGURES Publication figures from independent saved sources.
% Pure plotting: no simulation, RNG calls, parameter search or estimator calls.
% Run from repository root: addpath('matlab/paper_figures'); generate_all_paper_figures
arguments
    root (1,1) string = string(fileparts(fileparts(fileparts(mfilename('fullpath')))))
end
D=fullfile(root,'paper','figure_data'); O=fullfile(root,'paper','figures');
if ~isfolder(O), mkdir(O); end
set(groot,'defaultAxesFontName','Arial','defaultTextFontName','Arial', ...
    'defaultTextInterpreter','none','defaultLegendInterpreter','none', ...
    'defaultAxesTickLabelInterpreter','none', ...
    'defaultAxesFontSize',9,'defaultTextFontSize',9, ...
    'defaultLineLineWidth',1.4,'defaultAxesLineWidth',1.2, ...
    'defaultAxesBox','off','defaultFigureColor','w');
colors=[0 .447 .698; .835 .369 0; 0 .620 .451; .65 .35 .70];
styles={'-o','--s',':^','-.d'};
labels={'P_A','C_enhanced','H_A','C_public'};
methods=["P_A","C_enhanced","H_A","C_public"];

% Figure 1: original conceptual geometry, arbitrary coordinates.
T=readtable(fullfile(D,'Fig01_schematic.csv'),TextType='string');
f=canvas(7.16,3.5); tl=tiledlayout(f,1,3,'TileSpacing','compact','Padding','compact');
for k=1:3
    ax=nexttile(tl); hold(ax,'on'); xlim([0 1]); ylim([0 1]);
    xlabel('Angle (schematic)'); ylabel('Range (schematic)'); xticks([]); yticks([]);
    q=T(k,:); c=[q.frontTheta q.frontRange]; p=[q.truthTheta q.truthRange]; e=[q.estimateTheta q.estimateRange];
    if k<3
        rectangle('Position',[c-[q.angleHalfWidth q.rangeHalfWidth],2*q.angleHalfWidth,2*q.rangeHalfWidth], ...
            'FaceColor',[.93 .95 .97],'EdgeColor',colors(2,:),'LineWidth',1.4,'LineStyle','--');
        plot(c(1),c(2),'s','Color',[.25 .25 .25],'MarkerFaceColor','w','MarkerSize',6);
        plot(e(1),e(2),'x','Color',colors(2,:),'MarkerSize',8,'LineWidth',1.8);
        plot(p(1),p(2),'p','Color','k','MarkerFaceColor','k','MarkerSize',8);
        text(c(1)-.04,c(2)-.10,'p_F','HorizontalAlignment','right');
        text(.96,p(2)+.08,'True user p','HorizontalAlignment','right','FontSize',8.5);
        if k==1
            text(.04,.90,'(a) Successful refinement','FontSize',9);
            text(.06,.10,'Truth is inside W(p_F)','FontSize',8.5);
            text(.05,.79,'W(p_F): Δθ, Δr','FontSize',8.5);
            text(.57,.32,{'Joint MUSIC','peak'},'FontSize',8.5);
        else
            text(.04,.93,'(b) Coarse-center miss','FontSize',9);
            quiver(c(1),c(2),p(1)-c(1),p(2)-c(2),0,'k:','LineWidth',1.2,'MaxHeadSize',.15);
            text(.02,.07,{'Coarse error -> shifted W','Truth excluded -> no recovery'},'FontSize',8);
            text(.04,.55,'W(p_F)','FontSize',8.5);
        end
    else
        text(.04,.93,'(c) Proposed architecture','FontSize',9);
        plot(c(1),c(2),'s','Color',[.25 .25 .25],'MarkerFaceColor','w','MarkerSize',6);
        quiver(c(1),c(2),e(1)-c(1),0,0,'Color',colors(1,:),'LineWidth',1.4,'MaxHeadSize',.25);
        plot([e(1) e(1)],[.13 .86],'-.','Color',colors(3,:),'LineWidth',1.4);
        plot(e(1),e(2),'o','Color',colors(1,:),'MarkerFaceColor','w','MarkerSize',7);
        plot(p(1),p(2),'p','Color','k','MarkerFaceColor','k','MarkerSize',8);
        text(.06,.20,'p_F'); text(.38,.31,'θ_F -> θ_A','FontSize',8.5);
        text(.04,.56,{'Coherent full spectrum','range profile','at refined angle'},'FontSize',8.5);
        text(.97,.84,'True user p','HorizontalAlignment','right','FontSize',8.5);
        text(.08,.08,'r_F +/- 2 m (clipped)','FontSize',8.5);
        text(.79,.73,'P_A','HorizontalAlignment','left','FontSize',8.5);
    end
end
savefigures(f,O,'01_local_refinement_failure_mechanism');

% Figure 2: true final estimates + saved profile. No replay curve accepted.
T=readtable(fullfile(D,'Fig02_case.csv'),TextType='string');
g=readtable(fullfile(D,'Fig02_profile_grid.csv'));
v=readtable(fullfile(D,'Fig02_profile_candidates.csv'),TextType='string');
t=T.truthRangeM(1); rf=T.frontRangeM(1); rc=T.rangeM(T.method=="C_enhanced"); rp=T.rangeM(T.method=="P_A");
f=canvas(7.16,4.7); tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl,[1 2]); hold(ax,'on');
plot([T.pLowerM(1) T.pUpperM(1)],[2 2],'-.','Color',colors(1,:),'LineWidth',2);
plot([T.cLowerM(1) T.cUpperM(1)],[1 1],'--','Color',colors(2,:),'LineWidth',3);
plot(rf,1,'s','Color',[.2 .2 .2],'MarkerSize',7); plot(rc,1,'x','Color',colors(2,:),'MarkerSize',8);
plot(rp,2,'o','Color',colors(1,:),'MarkerFaceColor','w','MarkerSize',7);
xline(t,'k:','LineWidth',1.4); plot(t,2.6,'kp','MarkerFaceColor','k','MarkerSize',8);
text(t-.02,2.78,sprintf('Truth %.6f m',t),'HorizontalAlignment','right');
text(rp-.01,2.23,sprintf('P_A %.6f m',rp),'HorizontalAlignment','right','Color',colors(1,:));
text(15.13,1.16,sprintf('r_F = %.6f m; C = %.6f m',rf,rc),'Color',colors(2,:));
text(15.13,.71,'C interval: r_F +/- 0.0025 m (project strengthened baseline)','FontSize',8.5);
text(15.08,2.28,'P_A: [15, r_F + 2] m','FontSize',8.5);
xlim([14.97 17.12]); ylim([.55 3]); yticks([1 2]); yticklabels({'C_enhanced','P_A'}); xlabel('Range (m)'); title('(a) Frozen final-test support and estimates','FontSize',9,'FontWeight','normal');
ax=nexttile(tl); hold(ax,'on');
plot(1000*([T.cLowerM(1) T.cUpperM(1)]-rf),[1 1],'--','Color',colors(2,:),'LineWidth',2);
plot(0,1,'ks','MarkerSize',7); plot(1000*(rc-rf),1,'x','Color',colors(2,:),'MarkerSize',8,'LineWidth',1.8);
text(0,1.14,'Front','HorizontalAlignment','center'); text(2.5,.87,'C at boundary','HorizontalAlignment','right');
text(0,.68,sprintf('|C error| = %.4f m',abs(rc-t)),'HorizontalAlignment','center');
xlim([-3 3]); ylim([.6 1.35]); yticks([]); xlabel('Range offset from r_F (mm)'); title('(b) Narrow interval detail','FontSize',9,'FontWeight','normal');
ax=nexttile(tl); hold(ax,'on');
scale=max(v.rawLogScore); plot(g.rangeM,exp(g.rawLogScore-scale),'-o','Color',colors(1,:),'MarkerSize',2.4);
plot(rp,1,'o','Color',colors(1,:),'MarkerFaceColor','w','MarkerSize',7);
xline(t,'k:','LineWidth',1.4); xline(rf,'--','Color',[.3 .3 .3],'LineWidth',1.2);
xlim([T.pLowerM(1) T.pUpperM(1)]); ylim([0 1.09]); xlabel('Range (m)'); ylabel('Normalized coherent score');
title('(c) Saved profile grid and selected candidate','FontSize',9,'FontWeight','normal');
savefigures(f,O,'02_case_52100034_support_and_recovery');

% Figure 3: range superiority symbols belong to the range panel ONLY.
T=readtable(fullfile(D,'Fig03_rmse.csv'),TextType='string'); I=readtable(fullfile(D,'Fig03_primary_inference.csv'));
f=canvas(7.16,3.0); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
for k=1:2
    ax=nexttile(tl); hold(ax,'on');
    vars={'rangeRmseM','positionRmseM'}; labs={'Range RMSE (m)','Position RMSE (m)'};
    hh=gobjects(3,1);
    for j=1:3
        q=T(T.method==methods(j),:); hh(j)=plot(q.snrDb,q.(vars{k}),styles{j},'Color',colors(j,:),'MarkerSize',5);
    end
    set(ax,'YScale','log'); xlabel('SNR (dB)'); ylabel(labs{k}); xticks(-10:5:20); xlim([-11 21]);
    title("("+char('a'+k-1)+")",'FontSize',9,'FontWeight','normal');
    if k==1
        q=T(T.method=="P_A",:); take=logical(I.rangeSuperiorityPass);
        plot(q.snrDb(take),q.rangeRmseM(take)*.76,'kv','MarkerFaceColor','k','MarkerSize',5,'HandleVisibility','off');
    end
    legend(hh,labels(1:3),'Location','southoutside','Orientation','horizontal','Box','off','FontSize',8.5);
end
savefigures(f,O,'03_final_range_position_rmse');

% Figure 4: angle preservation and preregistered simultaneous bound.
T=readtable(fullfile(D,'Fig04_angle.csv'),TextType='string');
f=canvas(7.16,3); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl); hold(ax,'on');
for j=1:2
    q=T(T.method==methods(j),:); plot(q.snrDb,q.angleRmseDeg,styles{j},'Color',colors(j,:),'MarkerSize',6+(j==1)*2);
end
set(ax,'YScale','log'); xlabel('SNR (dB)'); ylabel('Angle RMSE (deg)'); xticks(-10:5:20); xlim([-11 21]);
title('(a) Nearly overlapping estimates','FontSize',9,'FontWeight','normal'); legend(labels(1:2),'Location','southoutside','Orientation','horizontal','Box','off','FontSize',8.5);
ax=nexttile(tl); q=T(T.method=="P_A",:); hold(ax,'on');
plot(q.snrDb,q.angleRatioSimultaneousUpper95,'-o','Color',colors(1,:),'MarkerFaceColor','w');
yline(1.21,'k--','LineWidth',1.4); text(-9,1.235,'Noninferiority margin: 1.21','FontSize',8.5);
xlim([-11 21]); ylim([.97 1.27]); xticks(-10:5:20); xlabel('SNR (dB)'); ylabel('Angle MSE ratio: upper bound');
title('(b) One-sided simultaneous 95% bound','FontSize',9,'FontWeight','normal');
savefigures(f,O,'04_angle_preservation_noninferiority');

% Figure 5: unsmoothed empirical survival with all 200 observations.
T=readtable(fullfile(D,'Fig05_tail_raw.csv'),TextType='string');
f=canvas(7.16,3); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
for k=1:2
    ax=nexttile(tl); hold(ax,'on'); hh=gobjects(3,1);
    for j=1:3
        x=sort(T.absoluteRangeErrorM(T.method==methods(j))); n=numel(x);
        [sx,sy]=stairs([0;x], [1;(n-(1:n)')/n]);
        hh(j)=plot(sx,sy,styles{j},'Color',colors(j,:),'MarkerIndices',1:40:numel(sx),'MarkerSize',4);
    end
    xline(1,'k:','LineWidth',1.4,'HandleVisibility','off'); xlim([0 2.05]);
    xlabel('Absolute range error (m)'); ylabel('Empirical Pr(|range error| > x)');
    if k==1
        ylim([0 1]); title('(a) Entire empirical distribution','FontSize',9,'FontWeight','normal');
    else
        ylim([0 .055]); title('(b) Tail detail (linear probability scale)','FontSize',9,'FontWeight','normal');
        text(.80,.047,{'C: max 1.9111 m; >1 m: 2/200','P_A: max 0.6656 m; >1 m: 0/200'},'FontSize',8.5);
    end
    legend(hh,labels(1:3),'Location','southoutside','Orientation','horizontal','Box','off','FontSize',8.5);
end
savefigures(f,O,'05_low_snr_range_error_tail');

% Figure 6: descriptive profile increment; retain negative changes.
T=readtable(fullfile(D,'Fig06_profile_effect.csv'));
f=canvas(3.5,2.8); ax=axes(f); hold(ax,'on');
plot(T.snrDb,T.relativeImprovementPercent,'-o','Color',colors(1,:),'MarkerFaceColor','w');
yline(0,'k--','LineWidth',1.3); xlim([-12 22]); ylim([-12 49]); xticks(-10:5:20);
for j=1:height(T)
    dy=3; if T.relativeImprovementPercent(j)<0,dy=-3.6;end
    if T.snrDb(j)==15,dy=-7.5;end
    align='center'; if j==1,align='left';elseif j==height(T),align='right';end
    text(T.snrDb(j),T.relativeImprovementPercent(j)+dy,sprintf('%+.2f',T.relativeImprovementPercent(j)),'HorizontalAlignment',align,'FontSize',8);
end
xlabel('SNR (dB)'); ylabel('Range RMSE improvement over H_A (%)');
savefigures(f,O,'06_profile_incremental_effect');

% Figure 7: different cost measures in independent panels.
T=readtable(fullfile(D,'Fig07_runtime.csv'),TextType='string'); G=readtable(fullfile(D,'Fig07_search.csv'),TextType='string');
f=canvas(7.16,3); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl); hold(ax,'on'); order=["C_public","H_A","P_A","C_enhanced"];
for j=1:4
    q=T(T.method==order(j),:); barh(j,q.meanOnlineSeconds,'FaceColor',colors(find(methods==order(j)),:),'EdgeColor','k','LineWidth',1.2);
    text(q.meanOnlineSeconds+.3,j,sprintf('%.4f',q.meanOnlineSeconds),'VerticalAlignment','middle','FontSize',8.5);
end
yticks(1:4); yticklabels({'C_public','H_A','P_A','C_enhanced'}); xlim([0 23]); ylim([.4 4.6]); xlabel('Complete online runtime (s)');
title('(a) Frozen same-machine means','FontSize',9,'FontWeight','normal');
ax=nexttile(tl); hold(ax,'on');
bar(1,G.musicGridPoints(1),'FaceColor',colors(2,:),'LineWidth',1.2); bar(2,G.musicGridPoints(2),'FaceColor',colors(1,:),'LineWidth',1.2);
xticks([1 2]); xticklabels({'C_enhanced','P_A angle'}); ylabel('MUSIC score grid points'); ylim([0 3700]); xlim([.4 2.6]);
text(1,3200,'3083','HorizontalAlignment','center'); text(2,240,'93','HorizontalAlignment','center');
text(1.55,2750,{'Search points: -96.98%','Full runtime: -50.19%'},'HorizontalAlignment','center','FontSize',8.5);
title('(b) Search count, not total complexity','FontSize',9,'FontWeight','normal');
savefigures(f,O,'07_runtime_and_search_complexity');

% Figure 8: deliberately separate measurement cohorts in caption.
T=readtable(fullfile(D,'Fig08_tradeoff.csv'),TextType='string');
f=canvas(3.5,2.8); ax=axes(f); hold(ax,'on');
for j=1:4
    q=T(T.method==methods(j),:); symbol={'o','s','^','d'};
    plot(q.meanOnlineSeconds,q.rangeRmse0dBM,symbol{j},'Color',colors(j,:),'MarkerSize',8,'LineWidth',1.5);
    if j==2,dx=-.4;align='right';else,dx=.4;align='left';end
    dy=1.0; if j==3,dy=1.25;end
    text(q.meanOnlineSeconds+dx,q.rangeRmse0dBM*dy,labels{j},'HorizontalAlignment',align,'FontSize',9);
end
set(ax,'YScale','log'); xlim([2 21]); ylim([.009 1.3]); xlabel('Complete online runtime (s)'); ylabel('Final 0-dB range RMSE (m)');
savefigures(f,O,'08_accuracy_complexity_tradeoff_0db');

% S1: paired coarse-error scatter, every final low-SNR observation retained.
T=readtable(fullfile(D,'FigS1_scatter.csv'),TextType='string');
f=canvas(7.16,3); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
for j=1:2
    ax=nexttile(tl); hold(ax,'on'); q=T(T.method==methods(j),:);
    scatter(abs(q.frontErrorM),q.absoluteRangeErrorM,18,colors(j,:),'Marker',char('o'+(j==2)*4),'LineWidth',1.2);
    plot([0 2],[0 2],'k--'); xlim([0 2]); ylim([0 2]); axis square;
    xlabel('|Front range error| (m)'); ylabel('|Final range error| (m)'); title(labels{j},'FontSize',9,'FontWeight','normal');
end
savefigures(f,O,'S1_front_vs_final_range_error');

% S2: exact zeros and one-step differences; zero is not hidden on a log axis.
T=readtable(fullfile(D,'FigS2_angle_difference.csv'));
counts=[nnz(T.deltaThetaDeg<0),nnz(T.deltaThetaDeg==0),nnz(T.deltaThetaDeg>0)];
f=canvas(3.5,2.8); ax=axes(f); bar(1:3,counts,'FaceColor',colors(1,:),'LineWidth',1.2); ylim([0 1600]);
xticks(1:3); xticklabels({'-1 step','Exact zero','+1 step'}); ylabel('Paired trial count'); xlabel('Angle difference (step = 0.0002666667 deg)');
for j=1:3,text(j,counts(j)+55,string(counts(j)),'HorizontalAlignment','center');end
savefigures(f,O,'S2_angle_difference_distribution');

% S3: development mechanism data visibly labeled, never pooled with final.
T=readtable(fullfile(D,'FigS3_boundary.csv'),TextType='string');
f=canvas(3.5,2.8); ax=axes(f); bar(1:4,T.boundaryHits,'FaceColor',colors(2,:),'LineWidth',1.2); ylim([0 650]);
xticks(1:4); xticklabels({'M_n','P_n','M_w','P_w'}); ylabel('Boundary hits / 600');
title('Development / calibration mechanism data','FontSize',8.5,'FontWeight','normal');
for j=1:4,text(j,T.boundaryHits(j)+25,string(T.boundaryHits(j)),'HorizontalAlignment','center');end
savefigures(f,O,'S3_development_boundary_mechanism');

% S4: explicit overhead prevents component sums from masquerading as wall time.
T=readtable(fullfile(D,'FigS4_components.csv'),TextType='string');
f=canvas(7.16,3); ax=axes(f); vals=[T.mean_frontSeconds,T.mean_geometrySeconds+T.mean_alignmentSeconds+T.mean_subspaceSeconds,T.mean_angleOrJointSeconds,T.mean_profileSeconds,T.mean_otherSeconds];
b=barh(vals,'stacked','LineWidth',1.2); pal=[colors; .7 .7 .7];
for j=1:numel(b),b(j).FaceColor=pal(j,:);end
for k=1:2
    edges=[0 cumsum(vals(k,:))];
    for j=1:4
        if vals(k,j)>.6
            text(mean(edges(j:j+1)),k,sprintf('%.2f',vals(k,j)), ...
                'HorizontalAlignment','center','Color','k','BackgroundColor','w','FontSize',8.5,'Margin',1);
        end
    end
end
yticks(1:2); yticklabels({'C_enhanced','P_A'}); ylim([.4 2.6]); xlabel('Mean complete online runtime components (s)');
legend({'Front','Compensation + covariance/EVD','MUSIC search','Profile','Other overhead'},'Location','southoutside','NumColumns',3,'Box','off','FontSize',8.5);
savefigures(f,O,'S4_frozen_timing_components');

% Internal research evolution, generated by the same entry point.
T=readtable(fullfile(D,'Timeline_nodes.csv'),TextType='string');
f=canvas(10,7); ax=axes(f,'Position',[.03 .03 .94 .94]); hold(ax,'on'); axis(ax,[0 3 0 4.5]); axis off;
for j=1:height(T)
    row=floor((j-1)/3); col=mod(j-1,3);
    if mod(row,2)==1,col=2-col;end
    x=.05+col; y=3.5-row;
    cc=[.9 .95 .95]; if T.status(j)=="REJECTED",cc=[.98 .91 .87];elseif T.status(j)=="SUPERSEDED",cc=[.94 .94 .94];elseif T.status(j)=="FINAL",cc=[.88 .93 .98];end
    rectangle('Position',[x,y,.86,.72],'FaceColor',cc,'LineWidth',1.2);
    titleLines=split(T.event(j),' / ');
    if strlength(T.event(j))>28, titleLines=string(textwrap(cellstr(T.event(j)),29));end
    text(x+.43,y+.48,titleLines,'HorizontalAlignment','center','FontSize',10);
    text(x+.43,y+.19,T.round(j)+" | "+T.status(j),'HorizontalAlignment','center','FontSize',9);
    if mod(j,3)~=0
        if mod(row,2)==0,quiver(x+.87,y+.36,.11,0,0,'k','LineWidth',1.2,'MaxHeadSize',1);
        else,quiver(x-.01,y+.36,-.11,0,0,'k','LineWidth',1.2,'MaxHeadSize',1);end
    elseif j<height(T)
        quiver(x+.43,y-.015,0,-.24,0,'k','LineWidth',1.2,'MaxHeadSize',.5);
    end
end
text(1.5,4.35,'Internal research evolution (not a main-paper figure)','HorizontalAlignment','center','FontSize',12);
savefigures(f,fullfile(root,'research_figures'),'research_evolution_timeline');
disp('ALL_PAPER_FIGURES_COMPLETE: 8 main, 4 supplementary, 1 internal timeline');
end

function f=canvas(w,h)
f=figure('Visible','off','Units','inches','Position',[1 1 w h], ...
    'PaperUnits','inches','PaperSize',[w h],'PaperPosition',[0 0 w h],'Renderer','painters');
end

function savefigures(f,folder,name)
if ~isfolder(folder),mkdir(folder);end
name=string(name);
axesList=findall(f,'Type','axes');
if f.Position(3)<4 && numel(axesList)==1
    axesList(1).Position=[.20 .22 .75 .70];
end
for k=1:numel(axesList)
    ax=axesList(k);
    if strcmp(ax.YScale,'log')
        yt=ax.YTick; ax.YTickLabel=compose('%g',yt);
    end
    ax.Box='off';
end
drawnow;
print(f,fullfile(folder,name+".pdf"),'-dpdf','-painters');
print(f,fullfile(folder,name+".svg"),'-dsvg','-painters');
print(f,fullfile(folder,name+".png"),'-dpng','-r600');
close(f);
end
