function writeDesignCsv(design, file)
%WRITEDESIGNCSV Write a round-trip exact numeric final design CSV.

arguments
    design table
    file (1, 1) string
end

required = ["positionId", "positionSeed", "truthThetaDeg", ...
    "truthRangeM", "snrIndex", "snrDb", "seed", ...
    "trialIndex", "shardId"];
if ~isequal(string(design.Properties.VariableNames), required)
    error("r41:DesignCsvColumnOrder", ...
        "The design CSV requires the exact frozen column order.");
end
handle = fopen(file, "wt");
if handle < 0
    error("r41:DesignCsvOpenFailed", ...
        "Cannot create the frozen design CSV.");
end
cleanup = onCleanup(@() fclose(handle));
fprintf(handle, "%s\n", join(required, ","));
values = table2array(design);
for index = 1:height(design)
    fprintf(handle, ...
        "%.0f,%.0f,%.17g,%.17g,%.0f,%.17g,%.0f,%.0f,%.0f\n", ...
        values(index, :));
end
clear cleanup
end
