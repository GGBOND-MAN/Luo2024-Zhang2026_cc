function summary = summarize(design, rowResults, candidates)
%SUMMARIZE Accuracy, tail, boundary, and complexity for F_L, H_L, and P_L.

arguments
    design table
    rowResults cell
    candidates table
end

methodNames = ["F_L", "H_L", "P_L"];
summary = table();
for candidateIndex = 1:height(candidates)
    theta = nan(height(design), numel(methodNames));
    range = nan(height(design), numel(methodNames));
    equivalent = nan(height(design), 1);
    fullUpper = nan(height(design), 1);
    totalSeconds = nan(height(design), 1);
    angleBoundary = false(height(design), 1);
    profileBoundary = false(height(design), 1);
    for row = 1:height(design)
        item = rowResults{row}.candidateResults{candidateIndex};
        theta(row, :) = item.thetaDeg(1:3);
        range(row, :) = item.rangeM(1:3);
        equivalent(row) = item.complexity.totalEquivalentFullResponses;
        fullUpper(row) = item.complexity.frontFullResponseUpperBound;
        totalSeconds(row) = item.totalSeconds;
        angleBoundary(row) = item.angleSolver.boundary;
        profileBoundary(row) = item.profileSolver.boundary;
    end
    for snrDb = [-10, 0, 20]
        rows = design.snrDb == snrDb;
        for method = 1:numel(methodNames)
            rangeError = range(rows, method) - design.truthRangeM(rows);
            angleError = theta(rows, method) - design.truthThetaDeg(rows);
            xError = range(rows, method).*sind(theta(rows, method)) ...
                - design.truthRangeM(rows).*sind(design.truthThetaDeg(rows));
            yError = range(rows, method).*cosd(theta(rows, method)) ...
                - design.truthRangeM(rows).*cosd(design.truthThetaDeg(rows));
            entry = table(candidates.candidateId(candidateIndex), snrDb, ...
                methodNames(method), nnz(rows), sqrt(mean(angleError.^2)), ...
                sqrt(mean(rangeError.^2)), ...
                sqrt(mean(xError.^2+yError.^2)), ...
                quantile(abs(rangeError), 0.95), mean(abs(rangeError) > 1), ...
                mean(equivalent(rows)), median(equivalent(rows)), ...
                max(fullUpper(rows)), mean(totalSeconds(rows)), ...
                mean(angleBoundary(rows)), mean(profileBoundary(rows)), ...
                'VariableNames', {'candidateId', 'snrDb', 'method', 'n', ...
                'angleRmseDeg', 'rangeRmseM', 'positionRmseM', 'p95RangeM', ...
                'missOver1m', 'meanEquivalentResponses', ...
                'medianEquivalentResponses', 'fullResponseUpperBound', ...
                'meanSeconds', 'angleBoundaryRate', 'profileBoundaryRate'});
            summary = [summary; entry]; %#ok<AGROW>
        end
    end
end
end
