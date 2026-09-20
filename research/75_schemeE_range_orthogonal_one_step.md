# R36 Scheme E: range-orthogonal one-step angle estimation

Date: 2026-09-12  
Protocol: `research/74_r36_angle_performance_protocol.md`  
Implementation: `R36-schemeE-range-orthogonal-one-step-v1`  
Data: existing 60 development users, -10/0/20 dB, 20 users each  
Decision: **PASS on the frozen 60-user engineering gate. Stop before calibration or final validation.**

> Development study – not R34 final confirmation

## 1. Isolation and execution audit

R36 was created as a new MATLAB package and result branch. No R32/R33/R34 or R35 source/result/report was overwritten.

- R36 development users executed: 60;
- new users generated: 0;
- existing 600-user calibration executed: 0;
- R34 final trials read or executed: 0;
- R35 Scheme A/B/D executions: 0;
- failed Scheme E rows: 0.

The R35 read-only source digest was recorded before the run and checked again after all 60 users:

`196bfb59ad1a833ad21542114536c743e0b9dd725982a4d02ea2b0bf9591b4e9`

The final Scheme E algorithm digest is:

`27879e532e1ffefa1223a7a2ed56a6845ade09ed97e98f58ed56851436ba5908`

## 2. Frozen estimator

Each user independently runs frozen `P_A` and `C_enhanced`. Scheme E then starts from the P_A grid angle and P_A profile range `(theta_A,r_P)` while reusing the same full-carrier direct-EVD state.

For each of the 2047 carriers, Scheme E forms the phase-invariant spatial residual

`e_m = (I-u_m u_m^H) a_m(theta_A,r_P)`

and analytic Jacobians with respect to angle in radians and range in meters. Uniform all-carrier residual gradient and Gauss-Newton information are constructed without carrier selection or learned weights.

The range nuisance is removed through the fixed Schur complement:

`g_eff = g_theta - J_theta,r J_r,r^-1 g_r`

`J_eff = J_theta,theta - J_theta,r J_r,r^-1 J_r,theta`

and exactly one update is used:

`delta_theta = -g_eff/J_eff`.

The update is bounded only by the two neighboring points of the actual final P_A grid. There is no iterative optimizer, line search, score-based candidate selection, SNR gate, alpha, temperature, top-K or fitted parameter. The diagnostic Newton range is never used as an output. The new angle always reruns the frozen P_A conditional range profile around the original front range.

Before real-user execution, an observed log-MUSIC Hessian formulation was rejected by mathematical unit testing because its local range curvature was not reliably concave. It was replaced before performance evaluation by the positive-semidefinite subspace-residual Gauss-Newton formulation above. No truth metric was used in that change. A subsequent no-truth numerical preflight checked only finite information, bracket behavior and physical range values.

## 3. Angle performance

| SNR | P_A RMSE (deg) | E RMSE (deg) | RMSE improvement | E/P_A MSE ratio | win/tie/loss |
|---:|---:|---:|---:|---:|---:|
| -10 dB | 0.001059967 | 0.001051641 | 0.7854% | 0.984353 | 8/0/12 |
| 0 dB | 0.000469182 | 0.000411634 | 12.2656% | 0.769733 | 10/0/10 |
| 20 dB | 0.000091540 | 0.000037662 | 58.8571% | 0.169274 | 16/0/4 |
| equal-SNR | 0.000671327 | 0.000652383 | 2.8219% | 0.944358 | 34/0/26 |

Equal-SNR aggregate angle MSE decreases by `5.5642%`, exceeding the frozen requirement of at least 2% improvement. All three per-SNR MSE ratios are below `1.01`.

Absolute-error distribution:

| SNR | method | median (deg) | P90 (deg) | P95 (deg) |
|---:|:---|---:|---:|---:|
| -10 | P_A | 0.000671614 | 0.001745259 | 0.002401552 |
| -10 | E | 0.000698495 | 0.001718535 | 0.002165436 |
| 0 | P_A | 0.000259542 | 0.000866748 | 0.001154238 |
| 0 | E | 0.000281091 | 0.000750637 | 0.000887572 |
| 20 | P_A | 0.000074167 | 0.000145446 | 0.000151053 |
| 20 | E | 0.000025149 | 0.000064166 | 0.000078556 |

The -10 dB pass is tail-driven rather than majority-driven: E loses on 12/20 users but reduces P90/P95 enough to lower MSE. At 0 dB the win/loss count is 10/10, while the upper tail falls substantially. The strongest and most consistent improvement occurs at 20 dB.

Therefore the correct claim is not universal per-user dominance. It is a cross-SNR development MSE improvement under the frozen aggregate and per-SNR gates.

## 4. One-step diagnostics

| SNR | valid | bracket clipped | mean |displacement| | max |displacement| | mean |diagnostic dr| | max |coupling| |
|---:|---:|---:|---:|---:|---:|---:|
| -10 | 20/20 | 13/20 | 2.1589e-4 deg | 2.6667e-4 deg | 1.2641e-8 m | 0.02106 |
| 0 | 20/20 | 5/20 | 1.4348e-4 deg | 2.6667e-4 deg | 1.9684e-8 m | 0.03007 |
| 20 | 20/20 | 0/20 | 7.5832e-5 deg | 1.5481e-4 deg | 1.1476e-7 m | 0.01473 |

All 60 information matrices produced valid updates. The angle-range tangent coupling remains small, with global maximum absolute value `0.03007`. The diagnostic nuisance-range displacement is negligible: mean `4.90e-8 m`, maximum `4.10e-7 m`.

Predicted and actual raw-MUSIC residual cost reductions closely agree, and actual cost decreases for 60/60 users. However truth angle improves for only 34/60. The overall correlation between actual cost reduction and truth squared-error gain is `0.218`; by SNR it is `0.236/0.624/0.611`. Objective improvement remains a diagnostic, not a per-user correctness guarantee.

The 18 bracket-clipped users, especially 13 at -10 dB, must be monitored in calibration. The bracket cannot be expanded or tuned after this result.

## 5. Range and position preservation

| SNR | P_A range RMSE (m) | E range RMSE (m) | range MSE ratio | range RMSE change | position RMSE change |
|---:|---:|---:|---:|---:|---:|
| -10 | 0.127242018 | 0.127224642 | 0.999727 | -0.01366% | -0.01373% |
| 0 | 0.009986689 | 0.009987507 | 1.000164 | +0.00819% | +0.00191% |
| 20 | 0.001360354 | 0.001357315 | 0.995537 | -0.22341% | -0.27372% |

All refreshed range MSE ratios are far below the `1.02` limit. Distance is effectively preserved; the largest observed range RMSE increase is `0.0082%` at 0 dB.

## 6. Runtime and evaluation counts

| SNR | P_A runtime | E complete runtime | E/P_A change | E/C_enhanced |
|---:|---:|---:|---:|---:|
| -10 | 18.70281 s | 18.33206 s | -1.982% | 0.5190 |
| 0 | 18.21019 s | 17.99918 s | -1.159% | 0.5117 |
| 20 | 17.48894 s | 17.28363 s | -1.174% | 0.4970 |
| all | — | 17.87162 s | — | 0.509321 |

The analytic refinement itself costs `0.05839 s/user` on average, median `0.05614 s`, maximum `0.10929 s`. The complete E runtime can be slightly lower than the paired P_A runtime because the newly executed frozen profile had lower runtime in this session; this does not mean the one-step calculation is free.

P_A uses 93 MUSIC grid evaluations; E records 95, adding the base and candidate full-carrier residual evaluations. Both use 2047 direct EVDs. C_enhanced uses 3083 MUSIC evaluations. Response counts differ only through the actual frozen profile optimizer calls.

## 7. Frozen engineering gate

| Gate | observed | limit | decision |
|:---|---:|---:|:---|
| -10 dB angle MSE ratio | 0.984353 | 1.01 | PASS |
| 0 dB angle MSE ratio | 0.769733 | 1.01 | PASS |
| 20 dB angle MSE ratio | 0.169274 | 1.01 | PASS |
| equal-SNR angle MSE ratio | 0.944358 | 0.98 | PASS |
| -10/0/20 dB range MSE ratio | 0.999727 / 1.000164 / 0.995537 | 1.02 | PASS |
| mean runtime/C_enhanced | 0.509321 | 1.00 | PASS |

Scheme E is the first angle-improvement candidate in this research sequence to pass every frozen 60-user development gate.

This is still development evidence, not independent final validation. The algorithm, bracket and gate must now remain frozen. No Scheme F, A/B/D combination or post-hoc selector is justified while a single parameter-free Scheme E has passed.

## 8. Tests and delivered files

- MATLAB Code Analyzer: zero issues in final R36 implementation and runner;
- `round36RangeOrthogonalAngleTest`: 6/6 passed;
- derivative tests cover analytic first/second steering derivatives and raw residual gradient;
- noiseless test verifies the one-step moves toward truth inside the frozen bracket;
- five development figures were rendered and visually inspected.

Result directory:

`matlab/results/full_spectrum/round36_schemeE_range_orthogonal_v1/`

- `per_user_outputs.csv`
- `method_summary.csv`
- `paired_comparisons.csv`
- `one_step_diagnostics.csv`
- `engineering_gate.csv`
- `failures.csv`
- `source_hashes.csv`
- `r35_readonly_source_hashes.csv`
- `checkpoint.mat`
- `result.mat`
- `figures/E_F1...E_F5...png`

Per the frozen R36 stop rule, the existing 600-user calibration set was not executed automatically.
