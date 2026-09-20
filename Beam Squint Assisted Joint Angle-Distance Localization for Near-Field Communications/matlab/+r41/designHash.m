function digest = designHash(design)
%DESIGNHASH Hash every frozen numeric design field in canonical order.

arguments
    design table
end

required = ["positionId", "positionSeed", "truthThetaDeg", ...
    "truthRangeM", "snrIndex", "snrDb", "seed", ...
    "trialIndex", "shardId"];
if ~all(ismember(required, string(design.Properties.VariableNames)))
    error("r41:FinalDesignColumns", ...
        "The final design is missing a frozen field.");
end
digest = r31.arrayHash(table2array(design(:, cellstr(required))));
end
