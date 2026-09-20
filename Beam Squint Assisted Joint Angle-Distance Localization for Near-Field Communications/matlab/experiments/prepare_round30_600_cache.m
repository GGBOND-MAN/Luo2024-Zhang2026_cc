function prepare_round30_600_cache()
%PREPARE_ROUND30_600_CACHE Reuse completed pilot rows for two selected shards.

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
pilotFile = fullfile(project, "results", "full_spectrum", ...
    "round30_pilot_v1", "aggregate", "aggregate.mat");
pilot = load(pilotFile, "design", "results", "selected", "expected");
pilotSetup = r30.setup(project, "pilot");
r30.assertIdentity(pilot.expected, pilotSetup);
setup = r30.setup(project, "calibration600");
selectedRows = find(ismember(setup.protocol.candidates.candidateId, ...
    pilot.selected.candidateId));
candidates = setup.protocol.candidates(selectedRows, :);
root = fullfile(project, "results", "full_spectrum", ...
    "round30_calibration600_v1");
if ~isfolder(root)
    mkdir(root);
end

for shardId = 1:2
    rows = (shardId:2:height(setup.design)).';
    design = setup.design(rows, :);
    identity = struct(setup=setup, selected=pilot.selected, ...
        candidates=candidates, design=design, shardId=shardId, shardCount=2);
    results = cell(height(design), 1);
    reused = false(height(design), 1);
    for row = 1:height(design)
        pilotRow = find(pilot.design.seed == design.seed(row), 1);
        if ~isempty(pilotRow)
            source = pilot.results{pilotRow};
            item = source;
            item.candidateId = candidates.candidateId;
            item.candidateResults = source.candidateResults(selectedRows);
            item.success = all(cellfun(@(value) value.success, ...
                item.candidateResults));
            results{row} = item;
            reused(row) = true;
        end
    end
    folder = fullfile(root, sprintf("shard_%02d_of_02", shardId));
    if ~isfolder(folder)
        mkdir(folder);
    end
    checkpoint = fullfile(folder, "checkpoint.mat");
    if isfile(checkpoint)
        saved = load(checkpoint);
        r30.assertIdentity(saved.identity, identity);
    else
        save(checkpoint, "identity", "results", "-v7.3");
    end
    provenance = table(design.seed(reused), design.snrDb(reused), ...
        repmat("round30_pilot_v1", nnz(reused), 1), ...
        'VariableNames', {'seed', 'snrDb', 'source'});
    writetable(provenance, fullfile(folder, "reuse_provenance.csv"));
    fprintf("R30 shard %d cache reused=%d pending=%d\n", ...
        shardId, nnz(reused), nnz(~reused));
end
end
