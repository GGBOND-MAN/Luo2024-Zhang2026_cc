function digest = designHash(design)
%DESIGNHASH Hash every frozen numeric design field in canonical order.

arguments
    design table
end

required = ["positionId", "positionSeed", "seed", "trialIndex", ...
    "snrIndex", "snrDb", "truthThetaDeg", "truthRangeM"];
if ~all(ismember(required, string(design.Properties.VariableNames)))
    error("r46:FinalDesignColumns", ...
        "The R46 final design is missing a frozen field.");
end
digest = r31.arrayHash(table2array(design(:, cellstr(required))));
end
