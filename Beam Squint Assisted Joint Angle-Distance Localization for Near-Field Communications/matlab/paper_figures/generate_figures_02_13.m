function generate_figures_02_13(varargin)
%GENERATE_FIGURES_02_13 Generate the organized paper figures 2 through 13.

parser = inputParser;
parser.addParameter("Figures", 2:13, ...
    @(x) isnumeric(x) && all(ismember(x, 2:13)));
parser.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
parser.parse(varargin{:});
figures = unique(round(parser.Results.Figures));

projectDir = fileparts(fileparts(mfilename("fullpath")));
outputDir = string(parser.Results.OutputDir);
if strlength(outputDir) == 0
    outputDir = fullfile(projectDir, "results", "paper_figures");
end

figures02To09 = figures(figures <= 9);
figures10To13 = figures(figures >= 10);
if ~isempty(figures02To09)
    generate_figures_02_09("Figures", figures02To09, "OutputDir", outputDir);
end
if ~isempty(figures10To13)
    generate_figures_10_13("Figures", figures10To13, "OutputDir", outputDir);
end

fprintf("Organized paper figures %s are available in %s\n", ...
    mat2str(figures), outputDir);
end
