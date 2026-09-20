# R42 Scheme H PA-free joint pilot results

Date: 2026-09-17  
Protocol: `R42-schemeH-pa-free-joint-development-v1`  
Status: **PILOT FAIL; development-60 not authorized**

## 1. Execution integrity

- New deterministic positions: 10.
- SNR values: `-10/0/20 dB`.
- Paired rows: 30; successes: 30; failures: 0.
- R34/R41 final rows read or executed: 0.
- Scheme H estimator calls P_A: no.
- Unit tests: 5 passed, 0 failed, 0 incomplete.
- Every selected H_joint result had non-increasing exact joint cost.
- Raw results were saved before reporting and all tables were recomputed from
  `result.mat` by a read-only posthoc analysis.

This is development evidence, not calibration or independent final validation.

## 2. Primary H_joint versus P_A

| SNR | angle MSE ratio | angle RMSE change | range MSE ratio | range RMSE change | angle W/L | range W/L |
|---:|---:|---:|---:|---:|---:|---:|
| -10 | 0.45245 | +32.74% | 1.77245 | -33.13% | 8/2 | 6/4 |
| 0 | 1.00915 | -0.46% | 9.21378 | -203.54% | 4/6 | 4/6 |
| 20 | 0.07048 | +73.45% | 1.18069 | -8.66% | 9/1 | 3/7 |
| equal-SNR aggregate | 0.52559 | +27.50% | 1.89374 | -37.61% | 21/9 | 13/17 |

`H_joint` passed the angle and monotonicity gates but failed every predeclared
range gate. The pilot therefore failed and was not expanded.

Mean complete online time was approximately `29.62 s` for P_A and `22.11 s`
for H_joint, a descriptive runtime ratio of about `0.746` on this run.

## 3. PA-free full-aperture ablation H_array

| SNR | angle MSE ratio | angle RMSE change | range MSE ratio |
|---:|---:|---:|---:|
| -10 | 0.47157 | +31.33% | 0.99894 |
| 0 | 1.01334 | -0.66% | 1.00212 |
| 20 | 0.06924 | +73.69% | 1.00246 |
| equal-SNR aggregate | 0.54264 | +26.34% | 0.99899 |

H_array used the L06 front, full N=256 raw-array angle search, and one unchanged
conditional q-only range profile. It did not execute P_A. Its aggregate range
RMSE changed by only about `+0.05%` improvement, while its aggregate angle RMSE
improved by about `26.34%`. The mean complete runtime ratio to P_A was `0.6292`,
or about `37.1%` lower.

The 0 dB angle ratio and the small per-SNR range changes show that this 10-position
pilot is not sufficient to promote H_array or claim uniform improvement.

## 4. Failure mechanism of the joint objective

The primary failure was not unrestricted divergence:

- all final joint costs were no larger than their starting costs;
- 16/30 rows stopped at `no-monotone-step`, 12/30 at the iteration limit, and
  2/30 at the gradient threshold;
- median absolute final range step from the selected start was only
  `0.001246 m`, although the maximum was `0.27304 m`;
- the joint candidate selected before local refinement differed from the z-only
  L06 selected candidate in 15/30 rows.

The largest distance losses were already present at the selected joint start.
Examples had initial range errors of approximately `-0.287 m`, `+0.236 m`, and
`-0.108 m`, while P_A errors on the same rows were much smaller. Local monotone
optimization generally preserved or only partly corrected these wrong modes.

The profile likelihood weights the raw-array block according to its very large
`N*K` observation dimension. That block provides strong angle discrimination,
but independent per-carrier complex gains remove its coherent cross-carrier
range phase. The resulting objective can re-rank z-derived range modes using a
block with strong angle information but weak, model-dependent range curvature.

## 5. Technical conclusion

The experiment separates two statements:

1. **PA-free angle improvement is feasible.** Replacing P_A's L160
   spatial-smoothed MUSIC stage with direct full-aperture raw-array refinement
   produced a large aggregate angle gain and lower runtime in this pilot.
2. **The tested direct joint likelihood does not improve both angle and range.**
   Its mode-selection rule substantially degraded range, despite exact-cost
   descent and good angle performance.

The defensible candidate after R42 is therefore the PA-free full-aperture
sequential architecture represented by H_array, not the tested H_joint
profile-likelihood fusion. A future method that seeks a genuine distance gain
must prevent the Y block from re-ranking coherent z range modes without a valid
cross-carrier gain/acquisition model. Any such change is a new estimator and
requires a new frozen protocol and new development data; it is not authorized
by this failed pilot.
