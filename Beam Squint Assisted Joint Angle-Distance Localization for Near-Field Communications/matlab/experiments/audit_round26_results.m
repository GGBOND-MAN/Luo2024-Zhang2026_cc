function audit_round26_results
%AUDIT_ROUND26_RESULTS Re-pair saved results without retuning any algorithm.

project = fileparts(fileparts(mfilename("fullpath")));
root = fullfile(project, "results", "full_spectrum");
output = fullfile(root, "round26_audit");
if ~isfolder(output)
    mkdir(output);
end
z = load(fullfile(root, "round26_zhang_large_joint_mc", ...
    "zhang_joint_mc_optimization.mat"));
f = load(fullfile(root, "round26_fsjad_large_joint_mc", ...
    "fsjad_joint_mc_optimization.mat"));
assert(isequal(z.cfg, f.cfg), "audit:DifferentModels");
assert(isequal(z.calibrationDesign, f.calibrationDesign), ...
    "audit:DifferentCalibration");
assert(isequal(z.validationDesign, f.validationDesign), ...
    "audit:DifferentValidation");
assert(isempty(intersect(z.calibrationDesign.seed, ...
    z.validationDesign.seed)), "audit:SeedLeakage");
assert(z.selectedAlgorithm.version == "Zhang-EF-JointMC-R26-locked");
assert(f.selectedAlgorithm.version == "FSJAD-JointMC-R26-locked");
assert(height(z.calibrationDesign) == 3000);
assert(height(z.validationDesign) == 600);
assert(isequal(z.validation.oursThetaDeg, f.validation.baselineThetaDeg));
assert(isequal(z.validation.oursRangeM, f.validation.baselineRangeM));

savedRuns = {z, f};
labels = ["Zhang", "FSJAD"];
integrity = table();
for runIndex = 1:2
    s = savedRuns{runIndex};
    counts = sum(isfinite(s.calibration.rangeM), 2);
    assert(sum(counts) == 68880);
    assert(isequal(sort(counts), ...
        [repmat(201,104,1); repmat(999,24,1); repmat(3000,8,1)]));
    assert(isequal(isfinite(s.calibration.rangeM), ...
        isfinite(s.calibration.thetaDeg)));
    assert(all(isfinite(s.validation.selectedRangeM)));
    assert(all(isfinite(s.validation.selectedThetaDeg)));
    eligible = s.stageSummaries{end};
    eligible = sortrows(eligible(eligible.feasible,:), ...
        "normalizedRangeMse");
    assert(s.selected.candidateId == eligible.candidateId(1));
    finalIds = s.stageSummaries{end}.candidateId;
    assert(all(counts(finalIds) == 3000));
    integrity = [integrity; table(labels(runIndex), sum(counts), ...
        sum(counts==201),sum(counts==999),sum(counts==3000), ...
        s.selected.candidateId, 'VariableNames', ...
        {'method','evaluations','stage1Only','stage2Only', ...
        'stage3Count','selectedId'})]; %#ok<AGROW>
end
writetable(integrity,fullfile(output,"integrity.csv"));

design = z.validationDesign;
trials = design;
trials.zhangRangeErrorM = z.validation.selectedRangeM-design.truthRangeM;
trials.fsjadRangeErrorM = f.validation.selectedRangeM-design.truthRangeM;
trials.zhangAngleErrorDeg = z.validation.selectedThetaDeg-design.truthThetaDeg;
trials.fsjadAngleErrorDeg = f.validation.selectedThetaDeg-design.truthThetaDeg;
trials.oldFsjadRangeErrorM = f.validation.baselineRangeM-design.truthRangeM;
trials.oldFsjadAngleErrorDeg = f.validation.baselineThetaDeg-design.truthThetaDeg;
writetable(trials, fullfile(output,"paired_trials.csv"));

stream = RandStream("mt19937ar",Seed=2026090501);
comparison = table();
comparisons = ["FSJAD-R26 vs Zhang-R26", "FSJAD-R26 vs FSJAD-R23", ...
    "Zhang-R26 vs Zhang-R23"];
for snr = [-10,0,20]
    chosen = design.snrDb == snr;
    for comparisonIndex = 1:3
        if comparisonIndex == 1
            methodFields = {f.validation.selectedRangeM, f.validation.selectedThetaDeg};
            referenceFields = {z.validation.selectedRangeM, z.validation.selectedThetaDeg};
        elseif comparisonIndex == 2
            methodFields = {f.validation.selectedRangeM, f.validation.selectedThetaDeg};
            referenceFields = {f.validation.baselineRangeM, f.validation.baselineThetaDeg};
        else
            methodFields = {z.validation.selectedRangeM, z.validation.selectedThetaDeg};
            referenceFields = {f.validation.zhangRangeM, f.validation.zhangThetaDeg};
        end
        truths = {design.truthRangeM, design.truthThetaDeg};
        metrics = ["rangeM", "angleDeg"];
        for metricIndex = 1:2
            a = methodFields{metricIndex}(chosen)-truths{metricIndex}(chosen);
            b = referenceFields{metricIndex}(chosen)-truths{metricIndex}(chosen);
            delta = a.^2-b.^2;
            normalCI = mean(delta)+[-1,1]*1.96*std(delta)/sqrt(numel(delta));
            % Resample paired trials, never estimators independently.
            indices = randi(stream,numel(delta),numel(delta),20000);
            bootDelta = mean(delta(indices),1);
            bootReduction = 100*(1-sqrt(mean(a(indices).^2,1) ...
                ./mean(b(indices).^2,1)));
            bootCI = prctile(bootDelta,[2.5,97.5]);
            gainCI = prctile(bootReduction,[2.5,97.5]);
            row = table(comparisons(comparisonIndex),snr,metrics(metricIndex), ...
                numel(a),rms(b),rms(a),100*(1-rms(a)/rms(b)), ...
                mean(delta),normalCI(1),normalCI(2), ...
                bootCI(1),bootCI(2),gainCI(1),gainCI(2), ...
                mean(abs(a)<abs(b)),max(a.^2)/sum(a.^2), ...
                max(b.^2)/sum(b.^2), 'VariableNames', ...
                {'comparison','snrDb','metric','count','referenceRmse', ...
                'methodRmse','rmseReductionPercent','mseDifference', ...
                'normalLower','normalUpper','bootstrapLower', ...
                'bootstrapUpper','reductionLower','reductionUpper', ...
                'trialWinRate','methodMaxSseShare','referenceMaxSseShare'});
            comparison = [comparison;row]; %#ok<AGROW>
        end
    end
end
writetable(comparison,fullfile(output,"paired_comparison.csv"));

calibrationAudit = table();
for runIndex = 1:2
    s = savedRuns{runIndex};
    for snr = [-10,0,20]
        chosen = s.calibrationDesign.snrDb == snr;
        errors = s.calibration.rangeM(s.selected.candidateId,chosen).' ...
            -s.calibrationDesign.truthRangeM(chosen);
        seeds = s.calibrationDesign.seed(chosen);
        [~,i] = max(abs(errors));
        row = table(labels(runIndex),snr,rms(errors),max(errors.^2)/sum(errors.^2), ...
            seeds(i),errors(i),'VariableNames', ...
            {'method','snrDb','rangeRmseM','maxSseShare','worstSeed','worstErrorM'});
        calibrationAudit = [calibrationAudit;row]; %#ok<AGROW>
    end
end
writetable(calibrationAudit,fullfile(output,"calibration_tail.csv"));

% Compare only finalists already evaluated on all calibration trials.
selectionStability = table();
for runIndex = 1:2
    s = savedRuns{runIndex};
    ids = s.stageSummaries{end}.candidateId;
    baselineId = 129;
    eR = s.calibration.rangeM(ids,:)-s.calibrationDesign.truthRangeM.';
    eA = s.calibration.thetaDeg(ids,:)-s.calibrationDesign.truthThetaDeg.';
    bR = s.calibration.rangeM(baselineId,:)-s.calibrationDesign.truthRangeM.';
    bA = s.calibration.thetaDeg(baselineId,:)-s.calibrationDesign.truthThetaDeg.';
    winners = zeros(numel(ids),1);
    snrValues = [-10,0,20];
    for repetition = 1:2000
        rangeRatios = zeros(numel(ids),3);
        angleRatios = zeros(numel(ids),3);
        for k = 1:3
            pool = find(s.calibrationDesign.snrDb == snrValues(k));
            ix = pool(randi(stream,numel(pool),numel(pool),1));
            rangeRatios(:,k) = mean(eR(:,ix).^2,2)/mean(bR(ix).^2);
            angleRatios(:,k) = sqrt(mean(eA(:,ix).^2,2)/mean(bA(ix).^2));
        end
        score = exp(mean(log(rangeRatios),2));
        score(max(angleRatios,[],2)>1.15) = inf;
        [~,winner] = min(score);
        winners(winner) = winners(winner)+1;
    end
    rows = table(repmat(labels(runIndex),numel(ids),1),ids,winners/2000, ...
        'VariableNames',{'method','candidateId','conditionalSelectionRate'});
    selectionStability = [selectionStability;rows]; %#ok<AGROW>
end
writetable(selectionStability,fullfile(output,"finalist_stability.csv"));

figureHandle = figure('Visible','off');
layout = tiledlayout(1,2);
for k=1:2
    ax=nexttile(layout);
    metric=["rangeM","angleDeg"];
    rows=comparison.comparison==comparisons(1) & comparison.metric==metric(k);
    semilogy(ax,comparison.snrDb(rows),comparison.referenceRmse(rows),'-o', ...
        comparison.snrDb(rows),comparison.methodRmse(rows),'-s','LineWidth',1.5);
    xlabel(ax,'SNR (dB)'); ylabel(ax,"RMSE ("+metric(k)+")");
    grid(ax,'on'); legend(ax,'Zhang R26','FSJAD R26');
end
title(layout,'Paired independent validation: 200 trials per SNR');
exportgraphics(figureHandle,fullfile(output,"paired_rmse.png"),'Resolution',180);
close(figureHandle);
disp(integrity);
disp(comparison);
disp(calibrationAudit);
disp(selectionStability);
fprintf("AUDIT_COMPLETE %s\n",output);
end
