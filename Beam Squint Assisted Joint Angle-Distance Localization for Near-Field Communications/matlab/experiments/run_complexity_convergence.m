function run_complexity_convergence
%RUN_COMPLEXITY_CONVERGENCE Measure runtime, calls, and convergence rates.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
addpath(projectFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder));

cfg = jad.defaultConfig();
scan = fsjad.prepareScan(cfg);
location = ["Known counterexample"; "Off-grid interior"; "Weak EFIM"];
truthThetaDeg = [15; 12.3; 0];
truthRangeM = [30; 34.2; 15];
snrDbValues = [-10, 0, 10, 20];
numTrials = 10;
centerCarrier = round(cfg.numSubcarriers / 2);
halfCarrierCount = floor(cfg.numFusionCarriers / 2);
carrierIndex = (centerCarrier-halfCarrierCount: ...
    centerCarrier+halfCarrierCount).';
musicCandidateCarrierEvaluations = numel(carrierIndex) ...
    * sum(cfg.gridSizes.^2);
musicEvdCount = numel(carrierIndex);
stream = RandStream("mt19937ar", Seed=cfg.randomSeed + 503);

numRows = numel(location) * numel(snrDbValues) * numTrials;
locationColumn = strings(numRows, 1);
snrDb = zeros(numRows, 1);
trialNumber = zeros(numRows, 1);
peakRuntimeMs = zeros(numRows, 1);
complexRuntimeMs = zeros(numRows, 1);
peakMusicRuntimeMs = zeros(numRows, 1);
complexMusicRuntimeMs = zeros(numRows, 1);
peakPipelineRuntimeMs = zeros(numRows, 1);
complexPipelineRuntimeMs = zeros(numRows, 1);
complexIterations = zeros(numRows, 1);
complexConverged = false(numRows, 1);
complexResponseEvaluations = zeros(numRows, 1);
complexProfileScore = zeros(numRows, 1);
peakCoarseCaptured = false(numRows, 1);
complexCoarseCaptured = false(numRows, 1);
peakMusicCaptured = false(numRows, 1);
complexMusicCaptured = false(numRows, 1);
rowIndex = 0;

warmResponse = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(truthThetaDeg(1)), truthRangeM(1), scan);
warmEstimate = fsjad.peakInitializedProfileEstimate(cfg, warmResponse, scan);
warmSnapshots = jad.simulateSnapshots(cfg, truthThetaDeg(1), ...
    truthRangeM(1), 20, carrierIndex, stream);
jad.localMusicEstimate(cfg, warmSnapshots, carrierIndex, ...
    warmEstimate.thetaDeg, warmEstimate.rangeM);

for locationIndex = 1:numel(location)
    truthResponse = fsjad.exactSpectralResponse(cfg, ...
        deg2rad(truthThetaDeg(locationIndex)), truthRangeM(locationIndex), scan);
    signalPower = mean(abs(truthResponse).^2);
    for snrIndex = 1:numel(snrDbValues)
        noiseVariance = signalPower / 10^(snrDbValues(snrIndex) / 10);
        for trialIndex = 1:numTrials
            commonPhase = 2 * pi * rand(stream);
            scalarNoise = sqrt(noiseVariance / 2) * ( ...
                randn(stream, cfg.numSubcarriers, 1) ...
                + 1i * randn(stream, cfg.numSubcarriers, 1));
            observation = truthResponse * exp(1i * commonPhase) + scalarNoise;
            snapshots = jad.simulateSnapshots(cfg, ...
                truthThetaDeg(locationIndex), truthRangeM(locationIndex), ...
                snrDbValues(snrIndex), carrierIndex, stream);

            timer = tic;
            [~, peakIndex] = max(abs(observation).^2);
            peakThetaDeg = scan.focusThetaDeg(peakIndex);
            peakRangeM = scan.focusRangeM(peakIndex);
            peakElapsedMs = 1000 * toc(timer);

            timer = tic;
            complexEstimate = fsjad.peakInitializedProfileEstimate( ...
                cfg, observation, scan);
            complexElapsedMs = 1000 * toc(timer);

            timer = tic;
            peakMusic = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
                peakThetaDeg, peakRangeM);
            peakMusicElapsedMs = 1000 * toc(timer);

            timer = tic;
            complexMusic = jad.localMusicEstimate(cfg, snapshots, carrierIndex, ...
                complexEstimate.thetaDeg, complexEstimate.rangeM);
            complexMusicElapsedMs = 1000 * toc(timer);

            rowIndex = rowIndex + 1;
            locationColumn(rowIndex) = location(locationIndex);
            snrDb(rowIndex) = snrDbValues(snrIndex);
            trialNumber(rowIndex) = trialIndex;
            peakRuntimeMs(rowIndex) = peakElapsedMs;
            complexRuntimeMs(rowIndex) = complexElapsedMs;
            peakMusicRuntimeMs(rowIndex) = peakMusicElapsedMs;
            complexMusicRuntimeMs(rowIndex) = complexMusicElapsedMs;
            peakPipelineRuntimeMs(rowIndex) = peakElapsedMs ...
                + peakMusicElapsedMs;
            complexPipelineRuntimeMs(rowIndex) = complexElapsedMs ...
                + complexMusicElapsedMs;
            complexIterations(rowIndex) = complexEstimate.iterations;
            complexConverged(rowIndex) = complexEstimate.converged;
            complexResponseEvaluations(rowIndex) = ...
                complexEstimate.totalResponseEvaluations;
            complexProfileScore(rowIndex) = complexEstimate.score;
            peakCoarseCaptured(rowIndex) = isCaptured(peakThetaDeg, ...
                peakRangeM, truthThetaDeg(locationIndex), ...
                truthRangeM(locationIndex));
            complexCoarseCaptured(rowIndex) = isCaptured( ...
                complexEstimate.thetaDeg, complexEstimate.rangeM, ...
                truthThetaDeg(locationIndex), truthRangeM(locationIndex));
            peakMusicCaptured(rowIndex) = isCaptured(peakMusic.thetaDeg, ...
                peakMusic.rangeM, truthThetaDeg(locationIndex), ...
                truthRangeM(locationIndex));
            complexMusicCaptured(rowIndex) = isCaptured( ...
                complexMusic.thetaDeg, complexMusic.rangeM, ...
                truthThetaDeg(locationIndex), truthRangeM(locationIndex));
        end
        fprintf("Completed complexity timing at %s, %g dB.\n", ...
            location(locationIndex), snrDbValues(snrIndex));
    end
end

trials = table(locationColumn, snrDb, trialNumber, peakRuntimeMs, ...
    complexRuntimeMs, peakMusicRuntimeMs, complexMusicRuntimeMs, ...
    peakPipelineRuntimeMs, complexPipelineRuntimeMs, complexIterations, ...
    complexConverged, complexResponseEvaluations, complexProfileScore, ...
    peakCoarseCaptured, complexCoarseCaptured, peakMusicCaptured, ...
    complexMusicCaptured);
summary = groupsummary(trials, "snrDb", {"mean", "median"}, ...
    ["peakRuntimeMs", "complexRuntimeMs", "peakMusicRuntimeMs", ...
    "complexMusicRuntimeMs", "peakPipelineRuntimeMs", ...
    "complexPipelineRuntimeMs", "complexIterations", ...
    "complexConverged", "complexResponseEvaluations", ...
    "complexProfileScore", "peakCoarseCaptured", ...
    "complexCoarseCaptured", "peakMusicCaptured", ...
    "complexMusicCaptured"]);

method = ["Peak index coarse"; "Complex spectrum coarse"; ...
    "Peak to local MUSIC"; "Complex to local MUSIC"];
medianRuntimeMs = [median(peakRuntimeMs); median(complexRuntimeMs); ...
    median(peakPipelineRuntimeMs); median(complexPipelineRuntimeMs)];
medianResponseEvaluations = [0; median(complexResponseEvaluations); ...
    0; median(complexResponseEvaluations)];
candidateCarrierEvaluations = [0; 0; ...
    musicCandidateCarrierEvaluations; musicCandidateCarrierEvaluations];
evdCount = [0; 0; musicEvdCount; musicEvdCount];
convergenceRate = [NaN; mean(complexConverged); NaN; ...
    mean(complexConverged)];
captureRate = [mean(peakCoarseCaptured); mean(complexCoarseCaptured); ...
    mean(peakMusicCaptured); mean(complexMusicCaptured)];
methodSummary = table(method, medianRuntimeMs, medianResponseEvaluations, ...
    candidateCarrierEvaluations, evdCount, convergenceRate, captureRate);

outputFolder = fullfile(projectFolder, "results", "full_spectrum", "round3");
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(trials, fullfile(outputFolder, ...
    "complexity_convergence_trials.csv"));
writetable(summary, fullfile(outputFolder, ...
    "complexity_convergence_by_snr.csv"));
writetable(methodSummary, fullfile(outputFolder, ...
    "complexity_convergence_methods.csv"));
save(fullfile(outputFolder, "complexity_convergence.mat"), ...
    "cfg", "location", "truthThetaDeg", "truthRangeM", ...
    "snrDbValues", "numTrials", "carrierIndex", ...
    "musicCandidateCarrierEvaluations", "musicEvdCount", ...
    "trials", "summary", "methodSummary");

figureHandle = figure(Color="w", Position=[100, 100, 1080, 420]);
layout = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");
nexttile;
bar(categorical(method), medianRuntimeMs);
set(gca, YScale="log"); grid on;
ylabel("Median runtime (ms)");
title("Measured end-to-end runtime");
nexttile;
plot(summary.snrDb, summary.mean_complexConverged, "-o", ...
    summary.snrDb, summary.mean_complexCoarseCaptured, "-s", ...
    LineWidth=1.5, MarkerSize=6);
grid on; ylim([0, 1.02]);
xlabel("Output SNR (dB)"); ylabel("Probability");
legend("Optimizer convergence", "Coarse capture", Location="southeast");
title("Convergence is not capture");
title(layout, "Complexity and convergence audit");
exportgraphics(figureHandle, fullfile(outputFolder, ...
    "complexity_convergence.png"), Resolution=180);
savefig(figureHandle, fullfile(outputFolder, ...
    "complexity_convergence.fig"));
close(figureHandle);

disp(methodSummary);
disp(summary);
end

function captured = isCaptured(estimateThetaDeg, estimateRangeM, ...
    truthThetaDeg, truthRangeM)
captured = abs(estimateThetaDeg - truthThetaDeg) <= 1 ...
    && abs(estimateRangeM - truthRangeM) <= 1;
end
