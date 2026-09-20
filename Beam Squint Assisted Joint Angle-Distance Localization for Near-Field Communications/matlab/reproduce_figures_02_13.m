function reproduce_figures_02_13(varargin)
%REPRODUCE_FIGURES_02_13 Generate the organized paper figures 2-13.

projectDir = fileparts(mfilename("fullpath"));
addpath(fullfile(projectDir, "paper_figures"));
generate_figures_02_13(varargin{:});
end
