# Paper figure scripts

The paper-figure implementations are organized here:

- `generate_figures_02_09.m`: figures 2-9.
- `generate_figures_10_13.m`: corrected published Proposed and CBS-Low
  curves for figures 10-13.
- `generate_figures_02_13.m`: unified dispatcher for figures 2-13.

Run `reproduce_figures_02_13` from the MATLAB project root to generate the
complete set. All outputs are written to `results/paper_figures/` by default.
The root-level `reproduce_*` functions are compatibility entries so existing
commands continue to work.
