# R40 Scheme G mechanism and complexity summary

Date: 2026-09-14  
Status: frozen calibration candidate; not independent final confirmation

Frozen Scheme G algorithm digest:

`b1b823826a707591f49ada5ff6cb093683e3bcab2e2b8479334c20076aec02a4`

## 1. Method in one sentence

Scheme G starts from frozen P_A `(theta_A,r_A)`, computes one full-`N=256`
raw-snapshot variable-projection Gauss-Newton angle step with range locally
profiled by a Schur complement, clips it to the unchanged P_A neighbor bracket,
checks the exact concentrated array cost, and updates final range with R37's
single-profile exact-q implicit transport.

It is a locally range-profiled sequential estimator, not a two-dimensional
joint ML search.

## 2. Answers to the six research questions

### Q1. Does G preserve the full-aperture angle gain?

Yes. Calibration-600 equal-SNR angle MSE ratios are:

- G/P_A = `0.778312`;
- F/P_A = `0.778371`;
- G/F = `0.999925`.

G improves angle RMSE over P_A/C by `11.7780%` and is effectively identical to
F. The full N=256 aperture gain is retained.

### Q2. Does Schur profiling improve over G_fixed?

No measurable aggregate improvement was found:

- G_schur/G_fixed angle MSE = `1.000121`;
- G_schur RMSE is worse by `0.00604%`;
- paired W/T/L = `192/229/179`.

The per-SNR effect is mixed and tiny: Schur is slightly worse at -10 dB and
slightly better at 0/20 dB. It must not be claimed as an accuracy contribution.

### Q3. Does G approach F while reducing cost?

Yes. Angle and range are numerically equivalent to F, while G removes F's
bounded optimizer and second complete profile.

- G historical-runtime comparison to F: `14.76%` lower;
- response-equivalent count: `6.80%` lower;
- complete profile passes: `1` instead of `2`;
- full-array angle evaluations: `2` instead of F's repeated bounded evaluations.

The operation-count conclusion is stronger than the cross-run seconds.

### Q4. Does single-profile transport preserve P_A range?

Yes. Calibration per-SNR G/P_A range MSE ratios are:

`0.999972 / 0.999294 / 0.993783`.

The pooled ratio is `0.999969`. G slightly improves P_A range while retaining
only the original one complete q-only profile. Transport was selected in
574/600 rows; invalid/no-gain cases retained `r_A`.

### Q5. Does G meet the combined objective?

Yes for the current development/calibration evidence:

- angle is numerically better than C at every SNR;
- range is numerically better than C at every SNR;
- runtime G/C = `0.465713`;
- runtime G/P_A = `1.00571`;
- full profile count = 1.

This is not independent final confirmation.

### Q6. What produces the gain?

The evidence attributes the gain to **full aperture**, not Schur profiling.

R39 had already shown N256 aperture improvements of about `18.6%-19.2%` angle
RMSE within the raw-snapshot family, while VPML carrier weighting contributed
approximately zero. R40 now shows that fixed-range and Schur one-step angles are
also almost identical. There is no evidence of a beneficial aperture-Schur
interaction under the current model.

## 3. Why the Schur term is negligible

Calibration mechanism diagnostics:

| SNR | mean `|rho_G|` | mean `J_eff/J_theta_theta` | mean `|Schur-fixed|` | step correlation |
|---:|---:|---:|---:|---:|
| -10 | 0.002297 | 0.99999256 | 3.699e-7 deg | 0.9999866 |
| 0 | 0.002275 | 0.99999235 | 2.873e-7 deg | 0.9999960 |
| 20 | 0.002343 | 0.99999234 | 5.718e-8 deg | 0.9999994 |
| all | 0.002305 | 0.99999242 | 2.381e-7 deg | 0.9999910 |

The Schur information correction is approximately `rho_G^2`, only several
parts per million. This follows from Scheme G's gain model: each carrier has an
independent complex `alpha_m`, so carrier-common phase is eliminated and range
enters the reduced raw-array likelihood mainly through weak Fresnel curvature.
The local angle and range Jacobians are therefore nearly orthogonal.

Schur changes the floating-point step in 371/600 rows, but most differences are
far below the bracket spacing. Clipping dominates at low SNR:

- -10 dB: 159/200 Schur steps hit the bracket boundary;
- 0 dB: 71/200;
- 20 dB: 0/200.

All 600 candidates reduced the exact concentrated cost. Mean predicted and
actual cost reductions were `9.309e-7` and `9.488e-7`, confirming the local GN
model, but cost reduction is not a truth-error certificate.

## 4. Two different range nuisance directions

The array-model nuisance step and exact q-profile transport are not estimates of
the same statistical direction:

| Quantity, all 600 | Value |
|:--|---:|
| corr(`delta_r_array`,`delta_r_q`) | -0.010995 |
| sign agreement | 49.0% |
| sign disagreements | 306/600 |
| mean `|delta_r_array|` | 0.09893 m |
| mean `|delta_r_q|` | 3.957e-5 m |
| median magnitude ratio | 1476.4 |

`delta_r_array` is the nuisance minimizer of a raw-array likelihood after
per-carrier gain elimination. It is weakly identified and only supports the
local model-consistency safeguard. `delta_r_q` follows the coherent exact
q-profile optimum manifold and is the only authorized final range update.

Mixing or averaging these two steps would be mathematically unjustified and was
not done.

## 5. Incremental complexity

### Theoretical structure

P_A already performs:

- `K=2047` spatial-subspace/EVD operations;
- 93 MUSIC grid scores;
- one complete exact q-only range profile.

Primary G adds:

- one `N x K` full-array steering plus theta/r derivative construction;
- `K` analytic `alpha_hat_m` projections;
- reduced residual/Jacobian inner products;
- one scalar 2-by-2 Schur calculation;
- one candidate full-array cost evaluation;
- one exact-q derivative and two range-candidate score evaluations;
- no EVD, no MUSIC grid and no complete range scan.

With the current vectorized implementation, the main incremental arithmetic is
`O(NK)` for the raw-array stage plus a constant number of `O(NM)` exact-q
evaluations. The scalar solve is `O(1)`. Estimated peak vectorized full-array
working storage is about `50.4 MB` per active row.

### Measured calibration breakdown

| Component | Seconds/user |
|:--|---:|
| Raw full-array context | 0.00644 |
| VP derivative/linearization | 0.04998 |
| Candidate safeguard | 0.01713 |
| Exact q transport | 0.05785 |
| Total G increment | 0.13140 |

Complete same-session runtime:

- P_A: `23.0089 s/user`;
- G: `23.1403 s/user`;
- C_enhanced: `49.6879 s/user`.

G adds five response-equivalent evaluations to P_A: two full-array evaluations
and three exact-q transport evaluations. It leaves MUSIC count `93` and EVD
count `2047` unchanged.

## 6. Final technical interpretation

Scheme G succeeds as a low-cost implementation of the full-aperture Scheme F
angle mechanism:

1. P_A supplies a robust coarse/local bracket and the only complete range
   profile.
2. One full-aperture raw-snapshot derivative step recovers essentially the same
   angle as bounded VPML refinement.
3. R37 implicit q transport removes the need for a second range scan while
   preserving P_A-level range accuracy.
4. Schur profiling is mathematically valid and numerically tested, but the
   current gain model makes its practical correction negligible.

The defensible method claim is therefore:

**single-profile full-aperture raw-snapshot local refinement with an explicit
range-nuisance safeguard**, not a claim that Schur profiling itself produces the
observed angle gain.

Scheme G is frozen as a calibration candidate. A future final claim requires a
new independent confirmation protocol and data that have not been used by
Schemes E/F/G.
