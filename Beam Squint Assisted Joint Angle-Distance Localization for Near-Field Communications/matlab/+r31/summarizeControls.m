function [summary, perUser] = summarizeControls(design, results)
%SUMMARIZECONTROLS Summarize C, A, and B on the fixed 60-user design.

arguments
    design table
    results cell
end

methodNames = results{1}.methodNames;
theta = cell2mat(cellfun(@(item) item.thetaDeg, ...
    results, UniformOutput=false));
range = cell2mat(cellfun(@(item) item.rangeM, ...
    results, UniformOutput=false));
perUser = table();
summary = table();

for methodIndex = 1:numel(methodNames)
    method = methodNames(methodIndex);
    methodRows = table(design.seed, design.snrDb, ...
        repmat(method, height(design), 1), theta(:, methodIndex), ...
        range(:, methodIndex), theta(:, methodIndex)-design.truthThetaDeg, ...
        range(:, methodIndex)-design.truthRangeM, ...
        'VariableNames', {'seed', 'snrDb', 'method', 'thetaDeg', ...
        'rangeM', 'angleErrorDeg', 'rangeErrorM'});
    perUser = [perUser; methodRows]; %#ok<AGROW>
    for snrDb = [-10, 0, 20]
        rows = design.snrDb == snrDb;
        entry = methodSummary(design(rows, :), ...
            theta(rows, methodIndex), range(rows, methodIndex), method);
        summary = [summary; entry]; %#ok<AGROW>
    end
end
end

function entry = methodSummary(design, theta, range, method)
angleError = theta-design.truthThetaDeg;
rangeError = range-design.truthRangeM;
xError = range.*sind(theta)-design.truthRangeM.*sind(design.truthThetaDeg);
yError = range.*cosd(theta)-design.truthRangeM.*cosd(design.truthThetaDeg);
entry = table(design.snrDb(1), method, height(design), ...
    sqrt(mean(angleError.^2)), sqrt(mean(rangeError.^2)), ...
    sqrt(mean(xError.^2+yError.^2)), quantile(abs(rangeError), 0.95), ...
    mean(abs(rangeError) > 1), ...
    'VariableNames', {'snrDb', 'method', 'n', 'angleRmseDeg', ...
    'rangeRmseM', 'positionRmseM', 'p95RangeM', 'missOver1m'});
end
