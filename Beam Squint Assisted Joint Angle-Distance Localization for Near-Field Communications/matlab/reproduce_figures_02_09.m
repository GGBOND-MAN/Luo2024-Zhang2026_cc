function reproduce_figures_02_09(varargin)
%REPRODUCE_FIGURES_02_09 Compatibility entry for paper figures 2-9.

projectDir = fileparts(mfilename("fullpath"));
addpath(fullfile(projectDir, "paper_figures"));
generate_figures_02_09(varargin{:});
end
