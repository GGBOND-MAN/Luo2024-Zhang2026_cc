function raw = loadRound30Raw(project, options)
%LOADROUND30RAW Load and validate the immutable 60-user Round30 artifacts.

arguments
    project (1, 1) string
    options.IncludeBaselineResults (1, 1) logical = true
end

raw.pilotFile = fullfile(project, "results", "full_spectrum", ...
    "round30_pilot_v1", "aggregate", "aggregate.mat");
raw.baselineFile = fullfile(project, "results", "full_spectrum", ...
    "round30_selected_baselines_v1", "result.mat");
if ~isfile(raw.pilotFile) || ~isfile(raw.baselineFile)
    error("r31:MissingRound30Raw", ...
        "The local Round30 pilot and selected-baseline raw MAT files are required.");
end

raw.pilot = load(raw.pilotFile, "design", "results", "selected", ...
    "expected", "baseline");
if options.IncludeBaselineResults
    raw.baselines = load(raw.baselineFile, "identity", "results");
else
    raw.baselines = load(raw.baselineFile, "identity");
end
if height(raw.pilot.design) ~= 60 ...
        || ~isequaln(raw.baselines.identity.setup, raw.pilot.expected) ...
        || (options.IncludeBaselineResults ...
        && size(raw.baselines.results, 1) ~= 60)
    error("r31:Round30RawIdentityMismatch", ...
        "The Round30 raw artifacts do not share the frozen 60-user identity.");
end

candidateIds = raw.pilot.expected.protocol.candidates.candidateId;
pilotMask = candidateIds == "L06";
selectedMask = ismember(candidateIds, ...
    raw.baselines.identity.selected.candidateId);
selectedIds = candidateIds(selectedMask);
baselineMask = selectedIds == "L06";
if nnz(pilotMask) ~= 1 || nnz(baselineMask) ~= 1
    error("r31:MissingL06Raw", ...
        "The required L06 pilot and baseline results were not found.");
end
raw.l06PilotIndex = (1:numel(candidateIds))*double(pilotMask(:));
raw.l06BaselineIndex = (1:numel(selectedIds))*double(baselineMask(:));
raw.l06Candidate = raw.pilot.expected.protocol.candidates( ...
    raw.l06PilotIndex, :);
raw.source = r31.manifest(project);
raw.pilotHash = hashRelativeFile(project, raw.pilotFile);
raw.baselineHash = hashRelativeFile(project, raw.baselineFile);
end

function digest = hashRelativeFile(project, file)
relative = replace(extractAfter(file, strlength(project)+1), ...
    string(filesep), "/");
manifest = fsjad.sourceHashManifest(project, relative);
digest = manifest.sha256(1);
end
