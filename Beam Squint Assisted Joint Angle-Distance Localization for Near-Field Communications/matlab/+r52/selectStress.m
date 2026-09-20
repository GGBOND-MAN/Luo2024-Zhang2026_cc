function output = selectStress(poolDesign, screening, protocol)
%SELECTSTRESS Select the first fixed-order natural miss rows in each class.

arguments
    poolDesign table
    screening (:, 1) cell
    protocol (1, 1) struct = r52.config()
end

if numel(screening) ~= height(poolDesign) ...
        || any(cellfun(@isempty, screening)) ...
        || any(cellfun(@(item) ~item.success, screening))
    error("r52:IncompleteStressScreening", ...
        "Every fixed-pool screening row must complete successfully.");
end
supportClass = cellfun(@(item) string(item.supportClass), screening);
angleSupportMiss = cellfun(@(item) item.angleSupportMiss, screening);
rangeSupportMiss = cellfun(@(item) item.rangeSupportMiss, screening);
frontThetaDeg = cellfun(@(item) item.frontThetaDeg, screening);
frontRangeM = cellfun(@(item) item.frontRangeM, screening);
audit = poolDesign;
audit.supportClass = supportClass;
audit.angleSupportMiss = angleSupportMiss;
audit.rangeSupportMiss = rangeSupportMiss;
audit.frontThetaDeg = frontThetaDeg;
audit.frontRangeM = frontRangeM;
audit.selectedForStress = false(height(audit), 1);

counts = zeros(numel(protocol.stressPool.classes), 1);
selectedRows = zeros(0, 1);
for classIndex = 1:numel(protocol.stressPool.classes)
    label = protocol.stressPool.classes(classIndex);
    rows = find(supportClass == label);
    counts(classIndex) = numel(rows);
    keep = rows(1:min(protocol.stressPool.targetPerClass, numel(rows)));
    selectedRows = [selectedRows; keep]; %#ok<AGROW>
end
selectedRows = sort(selectedRows);
audit.selectedForStress(selectedRows) = true;
design = poolDesign(selectedRows, :);
design.stressType = supportClass(selectedRows);
design.angleSupportMiss = angleSupportMiss(selectedRows);
design.rangeSupportMiss = rangeSupportMiss(selectedRows);

availableCount = counts;
selectedCount = zeros(size(counts));
for classIndex = 1:numel(protocol.stressPool.classes)
    selectedCount(classIndex) = nnz( ...
        design.stressType == protocol.stressPool.classes(classIndex));
end
classSummary = table(protocol.stressPool.classes(:), availableCount, ...
    selectedCount, repmat(protocol.stressPool.targetPerClass, ...
    numel(counts), 1), selectedCount >= protocol.stressPool.targetPerClass, ...
    'VariableNames', {'stressType', 'availableCount', 'selectedCount', ...
    'targetCount', 'constructionPass'});
output = struct(version="R52-fixed-natural-stress-selection-v1", ...
    design=design, poolAudit=audit, classSummary=classSummary, ...
    constructionPass=all(classSummary.constructionPass));
end
