# R40 Scheme G calibration-600 results

Date: 2026-09-14  
Protocol: `research/90_schemeG_full_aperture_range_profiled_protocol.md`  
Development evidence: `research/91_schemeG_development60_results.md`  
Evidence role: existing calibration evidence; not independent final confirmation  
Decision: **calibration candidate PASS**

## 1. Execution identity

- Existing calibration users: 600, with 200 at each of -10/0/20 dB.
- Successful rows: 600/600.
- Frozen development algorithm digest was required before calibration.
- P_A/C frozen-output identity failures: 0/600.
- New users: 0.
- R34 final reads/executions: 0.
- Scheme A/B/D, selector, gating, damping, line search, bracket expansion and
  parameter changes: 0.
- G complete range profiles: exactly 1/user.
- G fixed and Schur concentrated-cost safeguards accepted: 600/600 each.
- Exact q implicit transport selected: 574/600.

Result folder:

`matlab/results/full_spectrum/round40_schemeG_full_aperture_profiled_v1/calibration600/`

Final calibration `result.mat` SHA-256:

`be05c4beb167e9652711ad5bf85ad5528aea4c1e39b713f31dbf32cabb4d2c3f`

## 2. Angle performance

### Primary G_schur

| SNR | angle MSE | RMSE | median abs. | P90 abs. | P95 abs. | G/C MSE | W/T/L vs C |
|---:|---:|---:|---:|---:|---:|---:|:--|
| -10 | 1.499075e-6 | 0.001224367 deg | 0.000785974 | 0.002021204 | 0.002405218 | 0.802687 | 142/0/58 |
| 0 | 1.083435e-7 | 0.000329156 deg | 0.000187119 | 0.000545261 | 0.000632856 | 0.568951 | 138/0/62 |
| 20 | 9.482098e-10 | 0.000030793 deg | 0.000022179 | 0.000049414 | 0.000059116 | 0.111801 | 167/0/33 |

Because frozen C_enhanced and P_A have the same angle output in this experiment,
the G/C and G/P_A angle ratios are identical.

Equal-SNR aggregate:

- G/C angle MSE ratio: `0.778312`;
- angle MSE improvement: `22.1688%`;
- angle RMSE improvement: `11.7780%`;
- G versus C/P_A W/T/L: `447/0/153`.

This passes the predeclared `<=0.95` aggregate gate by a wide margin.

### Comparison with E, F and G_fixed

| Method | equal-SNR angle MSE | RMSE | ratio G_schur/method | G_schur W/T/L |
|:--|---:|---:|---:|:--|
| P_A/C | 6.888263e-7 | 0.000829956 deg | 0.778312 | 447/0/153 |
| E single | 6.210730e-7 | 0.000788082 deg | 0.863222 | not a predeclared paired Gate |
| F | 5.361624e-7 | 0.000732231 deg | 0.999925 | 182/229/189 |
| G_fixed | 5.360573e-7 | 0.000732159 deg | 1.000121 | 192/229/179 |
| G_schur | 5.361221e-7 | 0.000732204 deg | 1 | - |

G_schur reproduces Scheme F's angle performance to within `0.00376%` RMSE and
is numerically slightly better than F. It is slightly worse than G_fixed by
`0.00604%` RMSE. Both differences are negligible compared with the full-aperture
gain over P_A/C.

Per-SNR G/F MSE ratios are `0.999924 / 0.999934 / 0.999737`; the methods are
effectively identical within the fixed bracket.

## 3. Range and position

| SNR | G range MSE | G range RMSE | G/C MSE | G/P_A MSE | G position RMSE | >1 m misses |
|---:|---:|---:|---:|---:|---:|---:|
| -10 | 0.050000883 | 0.223608772 m | 0.327170 | 0.999972 | 0.223609901 m | 1 |
| 0 | 2.163233e-4 | 0.014707933 m | 0.474032 | 0.999294 | 0.014709242 m | 0 |
| 20 | 1.484035e-6 | 0.001218210 m | 0.253044 | 0.993783 | 0.001218362 m | 0 |

G is numerically better than strengthened Zhang-style C_enhanced at every SNR
and also slightly better than P_A at every SNR. Equal-SNR/pooled values are:

- P_A range RMSE: `0.129383455 m`;
- G_schur range RMSE: `0.129381465 m`;
- G/P_A range MSE ratio: `0.99996923`;
- F range RMSE: `0.129381452 m`;
- G/F range MSE ratio: `1.00000019`.

Thus G preserves P_A's range advantage and is range-equivalent to F while using
one rather than two complete profiles. The one `>1 m` miss at -10 dB is shared
with P_A/F; C has two such misses.

## 4. Runtime and operation counts

Same-session R40 calibration timing:

| Method | runtime/user | runtime/P_A | runtime/C | response count | MUSIC | EVD | profiles |
|:--|---:|---:|---:|---:|---:|---:|---:|
| P_A | 23.0089 s | 1 | 0.46306 | 2055.512 | 93 | 2047 | 1 |
| G_schur | 23.1403 s | 1.00571 | 0.46571 | 2060.512 | 93 | 2047 | 1 |
| C_enhanced | 49.6879 s | 2.1595 | 1 | 1912.515 | 3083 | 2047 | n/a |

G incremental runtime is `0.13140 s/user`:

- full-array raw context: `0.00644 s`;
- full-array VP derivative/linearization: `0.04998 s`;
- one exact candidate safeguard: `0.01713 s`;
- exact q implicit transport: `0.05785 s`.

Relative to historical frozen F calibration timing, G is `14.76%` faster
(`23.1403` versus `27.1478 s/user`) and has `6.80%` fewer response-equivalent
evaluations. Cross-run seconds include load variation, so profile/evaluation
counts are the more stable comparison: G uses two full-array evaluations and
one complete profile; F uses repeated bounded VPML evaluations and two profiles.

## 5. Gate decision

All predeclared hard gates passed:

| Gate | Observed |
|:--|:--|
| A1 per-SNR G/C angle MSE | `0.802687 / 0.568951 / 0.111801 <= 1` |
| A2 equal-SNR G/C angle MSE | `0.778312 <= 0.95` |
| R1 per-SNR G/C range MSE | `0.327170 / 0.474032 / 0.253044 < 1` |
| R2 per-SNR G/P_A range MSE | `0.999972 / 0.999294 / 0.993783 <= 1.01` |
| C1 runtime G/C | `0.465713 <= 1` |
| Profile | exactly 1 complete profile/user |

The non-hard runtime target also passed: `T_G/T_P_A=1.00571 <=1.05`.

Scheme G therefore obtains **calibration candidate PASS**. C_enhanced is a
strengthened Zhang-style internal baseline, not the authors' original code;
this result must not be described as having surpassed an independently verified
Zhang2026 implementation.

## 6. Evidence boundary and stop

- Calibration-600 has already been used for E/F and is not an independent final
  set.
- R34 final 1400 trials were not read or executed.
- No new final users were generated.
- No independent confirmation was started.
- Scheme G is frozen at the calibration-candidate stage and stops here pending a
  separately designed independent confirmation protocol.
