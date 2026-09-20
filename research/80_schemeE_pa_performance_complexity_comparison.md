# Scheme E versus P_A: performance and complexity comparison

Date: 2026-09-12  
Evidence: frozen R36 calibration600 outputs  
Population: all 600 rows and fixed holdout 540 rows  
Execution in this analysis: reporting only; no new estimation trials

> Calibration study – not R34 final confirmation

## 1. Comparison definition

The original method is the frozen `P_A`. The new method is Scheme E with the
standalone sequence required by its current mathematical definition:

1. run the complete P_A front end and one-dimensional MUSIC angle search;
2. run the first conditional range profile to obtain the Scheme E
   linearization range `r_P`;
3. apply one range-orthogonal Schur angle update;
4. rerun the unchanged conditional range profile at the corrected angle.

The complexity comparison therefore includes both profile passes. It does not
use the earlier reconstructed runtime that removed the first profile even
though `r_P` was required by the refinement.

## 2. Performance comparison

### All 600 calibration rows

| SNR | P_A angle RMSE | Scheme E angle RMSE | angle RMSE improvement | P_A range RMSE | Scheme E range RMSE | range RMSE change |
|---:|---:|---:|---:|---:|---:|---:|
| -10 dB | 0.001366591 deg | 0.001305112 deg | 4.4987% | 0.2236119 m | 0.2237735 m | +0.0723% |
| 0 dB | 0.000436379 deg | 0.000397737 deg | 8.8551% | 0.0147131 m | 0.0147107 m | -0.0164% |
| 20 dB | 0.000092094 deg | 0.000041325 deg | 55.1272% | 0.00122201 m | 0.00121941 m | -0.2132% |

Equal-SNR aggregate angle RMSE changes from `0.000829956 deg` to
`0.000788082 deg`, an improvement of `5.0453%`. Aggregate angle MSE improves
by `9.8360%`.

Pooled range RMSE changes from `0.1293835 m` to `0.1294765 m`, an increase of
`0.0719%`. Pooled position RMSE increases by `0.0718%`.

### Fixed holdout 540 rows

| SNR | angle RMSE improvement | range RMSE change |
|---:|---:|---:|
| -10 dB | 4.7414% | +0.0752% |
| 0 dB | 8.4187% | -0.0176% |
| 20 dB | 54.7370% | -0.2118% |

Holdout aggregate angle RMSE improves by `5.2029%`, and angle MSE improves by
`10.1351%`. Pooled range and position RMSE increase by only `0.0748%` and
`0.0747%`, respectively.

The all-600 and holdout results are closely aligned. Scheme E provides a clear
angle gain while leaving range and position performance practically unchanged.

## 3. Corrected standalone complexity

### All 600 rows

| Metric | P_A | Scheme E | Change |
|:--|--:|--:|--:|
| complete runtime | 24.3835 s/user | 26.1563 s/user | +7.2706% |
| response evaluations | 2055.51/user | 2198.53/user | +6.9579% |
| angle/subspace evaluations | 93/user | 95/user | +2.1505% |
| direct covariance EVD | 2047/user | 2047/user | 0% |
| conditional range profile passes | 1/user | 2/user | +100% |
| range-profile evaluations | 143.00/user | 286.02/user | +100.02% |

The Schur refinement itself costs `0.0894 s/user` on average. The second frozen
profile costs `1.6834 s/user` on average and accounts for most of the new
runtime. Scheme E therefore has the same leading-order structure as P_A and a
higher constant cost, rather than a new asymptotic complexity order.

Using symbolic component costs, the two methods can be summarized as

`C_PA = C_front + C_state/EVD + 93*C_angle + C_profile`,

`C_E = C_PA + 2*C_residual + C_profile,new`.

The expensive EVD/state construction is reused and does not increase. The main
cost is one additional full-spectrum range profile.

For context, the corrected Scheme E runtime remains about `51.04%` of the
measured `C_enhanced` runtime, corresponding to a `48.96%` reduction relative
to that strengthened two-dimensional joint-search baseline. This contextual
comparison is not a comparison with the unavailable Zhang2026 author code.

## 4. Accuracy-complexity conclusion

Relative to P_A, Scheme E trades approximately `7.27%` more standalone runtime
for approximately `5.05%` aggregate angle-RMSE improvement on all 600 rows and
`5.20%` on the fixed holdout. The improvement is especially large at 20 dB.

The distance penalty is negligible compared with this angle gain: the largest
observed range-RMSE increase is about `0.075%`, while 0 and 20 dB slightly
improve. Direct EVD cost is unchanged.

The engineering interpretation is:

- Scheme E is compatible with the P_A implementation and remains much cheaper
  than the strengthened two-dimensional search;
- it is not free relative to P_A because it requires a second range profile;
- its performance-complexity trade is favorable if the angle improvement is
  worth an approximately 7% online runtime increase;
- eliminating or approximating the second profile would define a different
  estimator and requires a new frozen study, so it is not assumed here.

## 5. Figures and data

Output directory:

`matlab/results/full_spectrum/round36_schemeE_calibration600_v1/pa_comparison_v1/`

- `PA_E_F1_all600_performance.png`
- `PA_E_F2_holdout540_performance.png`
- `PA_E_F3_relative_changes.png`
- `PA_E_F4_complexity.png`
- `performance_comparison.csv`
- `aggregate_performance_comparison.csv`
- `complexity_comparison.csv`
- `comparison_identity.csv`
- `source_hash.csv`
- `comparison_result.mat`

The figure builder is
`matlab/experiments/build_round36_schemeE_pa_comparison.m`. The builder reads
the frozen calibration output and records `estimationExecuted=false`.
