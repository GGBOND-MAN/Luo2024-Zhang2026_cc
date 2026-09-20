function reproduce_figures_10_13_with_cbs(varargin)
%REPRODUCE_FIGURES_10_13_WITH_CBS Compatibility entry for figures 10-13.

projectDir = fileparts(mfilename("fullpath"));
addpath(fullfile(projectDir, "paper_figures"));
generate_figures_10_13(varargin{:});
end
