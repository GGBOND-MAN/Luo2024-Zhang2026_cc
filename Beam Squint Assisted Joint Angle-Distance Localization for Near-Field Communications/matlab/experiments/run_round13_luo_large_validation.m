function run_round13_luo_large_validation
%RUN_ROUND13_LUO_LARGE_VALIDATION Validate the frozen CBS-Low reproduction.

projectFolder = fileparts(fileparts(mfilename("fullpath")));
repositoryFolder = fileparts(projectFolder);
workspaceFolder = fileparts(repositoryFolder);
luoFolder = fullfile(workspaceFolder, "repro_paper2");
addpath(projectFolder, luoFolder);
cleanupPath = onCleanup(@() rmpath(projectFolder, luoFolder));
outputFolder = fullfile(projectFolder, "results", "full_spectrum", ...
    "round13");
loaded = load(fullfile(outputFolder, ...
    "luo_reproduction_calibration.mat"), "P", "snrValues", ...
    "truthThetaRad", "truthRangeM", "luoSnrAdjustmentDb", ...
    "selectedLuo");
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Threads", 8);
end
fprintf("Luo validation uses %d workers.\n", pool.NumWorkers);

numPerSnr = 3334;
snrDb = repelem(loaded.snrValues, numPerSnr);
numRows = numel(snrDb);
seed = 20289001 + (1:numRows).';
checkpointFile = fullfile(outputFolder, ...
    "luo_reproduction_large_validation_checkpoint.mat");
if isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    thetaErrorDeg = checkpoint.thetaErrorDeg;
    rangeErrorM = checkpoint.rangeErrorM;
    completedRows = checkpoint.completedRows;
else
    thetaErrorDeg = zeros(numRows, 1);
    rangeErrorM = zeros(numRows, 1);
    completedRows = 0;
end

L = bs_lib();
candidate = loaded.selectedLuo(1, :);
batchSize = 240;
for batchStart = completedRows + 1:batchSize:numRows
    rows = batchStart:min(batchStart + batchSize - 1, numRows);
    batchThetaErrorDeg = zeros(numel(rows), 1);
    batchRangeErrorM = zeros(numel(rows), 1);
    parfor batchIndex = 1:numel(rows)
        row = rows(batchIndex);
        rng(seed(row), "twister");
        settings = L.sense_par("rmin", 15, "rmax", 50, ...
            "thmin", deg2rad(-candidate.angleHalfSpanDeg), ...
            "thmax", deg2rad(candidate.angleHalfSpanDeg), ...
            "rmid1", candidate.rMid1M, "rmid2", candidate.rMid2M, ...
            "snr", 10^((snrDb(row) + ...
            loaded.luoSnrAdjustmentDb) / 10));
        estimate = L.cbs_low(loaded.P, loaded.truthRangeM, ...
            loaded.truthThetaRad, settings);
        batchThetaErrorDeg(batchIndex) = rad2deg( ...
            estimate.th - loaded.truthThetaRad);
        batchRangeErrorM(batchIndex) = ...
            estimate.r - loaded.truthRangeM;
    end
    thetaErrorDeg(rows) = batchThetaErrorDeg;
    rangeErrorM(rows) = batchRangeErrorM;
    completedRows = rows(end);
    save(checkpointFile, "thetaErrorDeg", "rangeErrorM", ...
        "completedRows", "snrDb", "seed");
    fprintf("Luo large validation %d/%d complete.\n", ...
        completedRows, numRows);
end

details = table(snrDb, seed, thetaErrorDeg, rangeErrorM);
summary = summarizeErrors(details, loaded.snrValues);
writetable(details, fullfile(outputFolder, ...
    "luo_reproduction_large_validation_details.csv"));
writetable(summary, fullfile(outputFolder, ...
    "luo_reproduction_large_validation_summary.csv"));
save(fullfile(outputFolder, ...
    "luo_reproduction_large_validation.mat"), "details", "summary", ...
    "numPerSnr", "candidate");
disp(summary);
end

function summary = summarizeErrors(details, snrValues)
snrDb = snrValues;
sampleCount = zeros(size(snrValues));
angleRmseDeg = zeros(size(snrValues));
rangeRmseM = zeros(size(snrValues));
rangeMseCi95Lower = zeros(size(snrValues));
rangeMseCi95Upper = zeros(size(snrValues));
for snrIndex = 1:numel(snrValues)
    selected = details.snrDb == snrValues(snrIndex);
    sampleCount(snrIndex) = sum(selected);
    angleRmseDeg(snrIndex) = sqrt(mean( ...
        details.thetaErrorDeg(selected).^2));
    squaredRangeError = details.rangeErrorM(selected).^2;
    rangeMse = mean(squaredRangeError);
    halfWidth = 1.96 * std(squaredRangeError) ...
        / sqrt(sampleCount(snrIndex));
    rangeRmseM(snrIndex) = sqrt(rangeMse);
    rangeMseCi95Lower(snrIndex) = max(0, rangeMse - halfWidth);
    rangeMseCi95Upper(snrIndex) = rangeMse + halfWidth;
end
summary = table(snrDb, sampleCount, angleRmseDeg, rangeRmseM, ...
    rangeMseCi95Lower, rangeMseCi95Upper);
end
