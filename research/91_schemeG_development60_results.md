# R40 Scheme G development-60 results

Date: 2026-09-14  
Protocol: `research/90_schemeG_full_aperture_range_profiled_protocol.md`  
Evidence role: existing-60 development evidence; not independent final confirmation  
Decision: **all predeclared hard gates PASS; automatic frozen calibration-600 authorized**

## 1. Execution identity

- Existing development users: 60, with 20 at each of -10/0/20 dB.
- Successful rows: 60/60.
- New users: 0.
- R34 final reads/executions: 0.
- Scheme A/B/D executions: 0.
- Parameter tuning, gating, selector, damping, line search and bracket expansion: 0.
- Complete range profiles for G: exactly 1/user.
- P_A and C_enhanced were re-executed in the R40 session for timing and reproduced
  their frozen theta/r outputs within the inherited R33 identity tolerance.
- E single and F were paired read-only references.

Result folder:

`matlab/results/full_spectrum/round40_schemeG_full_aperture_profiled_v1/`

Final development `result.mat` SHA-256:

`1590733a7c4612774c14e2cae6a6e987edf58eceaede82ea76f1a936aad31573`

## 2. Performance

### Per-SNR angle

| SNR | P_A/C RMSE | F RMSE | G_fixed RMSE | G_schur RMSE | G_schur/C MSE |
|---:|---:|---:|---:|---:|---:|
| -10 | 0.001059967 deg | 0.000972951 | 0.000972575 | 0.000972630 | 0.841998 |
| 0 | 0.000469182 deg | 0.000365647 | 0.000365708 | 0.000365801 | 0.607864 |
| 20 | 0.000091540 deg | 0.000025588 | 0.000025588 | 0.000025548 | 0.077890 |

Equal-SNR aggregate:

| Comparison | angle MSE ratio | angle RMSE improvement | W/T/L |
|:--|---:|---:|:--|
| G_schur / P_A | 0.799141 | 10.6053% | 43/0/17 |
| G_schur / C_enhanced | 0.799141 | 10.6053% | 43/0/17 |
| G_schur / F | 0.999524 | 0.02382% | 17/23/20 |
| G_schur / G_fixed | 1.000160 | -0.00799% | 18/23/19 |

G_schur preserves essentially all frozen Scheme F angle performance. It does
not outperform G_fixed in aggregate; the difference is numerically negligible
and slightly unfavorable to Schur on this development set.

### Range and position

| SNR | G range RMSE | G/C range MSE | G/P_A range MSE | G position RMSE |
|---:|---:|---:|---:|---:|
| -10 | 0.127255545 m | 0.790449 | 1.000213 | 0.127256887 m |
| 0 | 0.009991731 m | 0.114203 | 1.001010 | 0.009993774 m |
| 20 | 0.001354823 m | 0.262977 | 0.991885 | 0.001354906 m |

There were no `>1 m` range misses. G is numerically better than C at every SNR
and remains within 1.01 times P_A at every SNR. Relative to P_A, the -10/0 dB
changes are tiny degradations while 20 dB improves; this is the same small
angle-conditioned range movement observed in F, not a loss of the strong P_A
range baseline.

## 3. Fixed-range versus Schur mechanism

| SNR | mean `|rho_G|` | mean `J_eff/J_theta_theta` | mean `|G_schur-G_fixed|` | fixed/Schur clipped |
|---:|---:|---:|---:|:--|
| -10 | 0.002480 | 0.99999245 | 2.384e-7 deg | 16/16 of 20 |
| 0 | 0.002572 | 0.99999025 | 3.411e-7 deg | 7/7 of 20 |
| 20 | 0.002625 | 0.99998849 | 5.414e-8 deg | 0/0 of 20 |
| all | 0.002559 | 0.99999040 | 2.112e-7 deg | 23/23 of 60 |

The selected fixed and Schur steps have correlation `0.9999968`. Schur changes
37/60 numerical steps, but the change is far below the frozen bracket spacing
and produces no aggregate accuracy gain. The correct mechanism conclusion is:

**full N=256 aperture explains the angle gain; range-nuisance profiling adds
negligible correction under the current independent-per-carrier-gain model.**

All 60 fixed and Schur candidates passed the full-array concentrated-cost
safeguard. Mean predicted and actual Schur cost reductions were
`7.813e-7` and `7.957e-7`, respectively.

## 4. Array nuisance range versus exact q transport

For G_schur over all 60 rows:

- correlation between raw `delta_r_array` and raw `delta_r_q`: `-0.04439`;
- sign agreement: `48.33%`;
- sign disagreements: 31/60;
- mean `|delta_r_array|`: `0.09404 m`;
- mean `|delta_r_q|`: `2.853e-5 m`;
- median `|delta_r_array|/|delta_r_q|`: `1981.94`.

The full-array VP model with independent `alpha_m` uses only the weak
within-array Fresnel curvature for its range nuisance direction. The exact
q-profile uses coherent spectral structure. Their range directions are neither
equivalent nor interchangeable. Primary G correctly uses `delta_r_array` only
for the array-model safeguard and `delta_r_q` only for final range.

## 5. Complexity

Same-session development means:

| Method | runtime/user | runtime/P_A | runtime/C | response count | EVD | profiles |
|:--|---:|---:|---:|---:|---:|---:|
| P_A | 18.0794 s | 1 | 0.51725 | 2056.12 | 2047 | 1 |
| G_schur | 18.1766 s | 1.00538 | 0.52004 | 2061.12 | 2047 | 1 |
| C_enhanced | 34.9524 s | 1.93328 | 1 | 1911.80 | 2047 | n/a |

G_schur incremental runtime is `0.09721 s/user`:

- raw context preparation: `0.00561 s`;
- full-array derivative/linearization: `0.03701 s`;
- one candidate safeguard: `0.01175 s`;
- exact q implicit transport: `0.04283 s`.

Incremental theoretical work is `O(NK)` for one full-array steering/derivative
linearization plus one candidate cost, followed by three q-profile candidate
evaluations and a scalar 2-by-2 Schur solve. It adds no EVD, no MUSIC grid and
no complete range scan.

Historical F runtime is not directly comparable to the same-session R40 seconds,
but its stable operation counts are: multiple bounded VPML score evaluations
and two complete profiles. G uses 2 full-array evaluations and one profile,
which explains the large structural cost reduction.

## 6. Gate

All hard gates passed:

- A1 per-SNR G/C angle MSE: `0.841998 / 0.607864 / 0.077890 <= 1`;
- A2 equal-SNR G/C angle MSE: `0.799141 <= 0.95`;
- R1 per-SNR G/C range MSE: `0.790449 / 0.114203 / 0.262977 < 1`;
- R2 per-SNR G/P_A range MSE: `1.000213 / 1.001010 / 0.991885 <= 1.01`;
- C1 runtime G/C: `0.520037 <= 1`;
- Profile: exactly 1 complete profile/user.

The non-hard runtime target also passed: `T_G/T_P_A=1.00538 <=1.05`.

The fixed source/parameter identity was therefore authorized for automatic use
on the existing calibration-600. This Stage 1 result is not independent final
confirmation.
