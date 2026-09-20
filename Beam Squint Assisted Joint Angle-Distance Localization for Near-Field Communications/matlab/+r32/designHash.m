function digest = designHash(design)
%DESIGNHASH Hash all numeric fields in the frozen final design.

arguments
    design table
end

required = ["positionId", "truthThetaDeg", "truthRangeM", ...
    "snrDb", "seed", "trialIndex"];
if ~all(ismember(required, string(design.Properties.VariableNames)))
    error("r32:FinalDesignColumns", ...
        "The final-test design is missing a frozen field.");
end
digest = r31.arrayHash(table2array(design(:, cellstr(required))));
end
