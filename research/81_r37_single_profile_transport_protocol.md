# R37 single-profile implicit transport protocol

Date: 2026-09-13  
Version: `R37-schemeE-single-profile-implicit-transport-v1`  
Evidence role: retrospective post-calibration engineering evidence; not independent final validation

## 1. Objective

Test whether frozen Scheme E can retain its angle improvement and range safety
while eliminating its second complete conditional range profile. The candidate is
called `E_single_profile`. This round evaluates only the range-output
implementation and does not tune or replace the frozen R36 angle update.

## 2. Frozen inputs and isolation

- Read-only R36 result: `matlab/results/full_spectrum/round36_schemeE_calibration600_v1/result.mat`.
- Required result SHA-256: `f998fc2258210c13ef98345ea04b4637c7d93b762795fc575c8da92a200bb446`.
- Required Scheme E digest: `27879e532e1ffefa1223a7a2ed56a6845ade09ed97e98f58ed56851436ba5908`.
- Required calibration-data digest: `39538d66a6724e198d9c569c2f9e24b9185c4d3d979bc4f224724fbf5d50dcc0`.
- Use exactly the existing 600 rows: 200 at each of -10, 0 and 20 dB.
  Report all 600 and the already fixed 540-row non-development subset.
- Generate no user, seed, observation identity or SNR condition. Observation
  construction is deterministic replay of saved rows only.
- R34 final 1400 trials are forbidden and must not be read or executed.
- R32, R33, R34, R35 and R36 source and result artifacts are read-only.

This evidence is retrospective because this calibration population previously
assessed Scheme E. It cannot be called independent validation.

## 3. Frozen estimator components

- `N=256, M=2048, K=2047, L=160, P=97`;
- L06 front, q-only response, direct covariance EVD and `UseGram=false`;
- 41/31/21 angle grids and the actual final P_A angle bracket;
- frozen Scheme E one-step angle and Schur range-nuisance elimination;
- `lambda=1`, original physical range limits and first P_A profile;
- original `+/-2 m` profile bounds and all profile settings.

For every row, `theta_E_single` must equal frozen R36 `theta_E` within
`1e-12 deg`.

## 4. Single-profile implicit transport

Let `J(theta,r)` be the unchanged exact q-only log profile score. The first P_A
profile returns `r_P` at `theta_A`. For frozen displacement
`delta_theta=theta_E-theta_A`, locally solve `J_r=0` using

`delta_r = -(J_r + J_rtheta*delta_theta)/J_rr`.

Theta derivatives use radians and range derivatives use meters. Derivatives are
analytic derivatives of the exact spherical-wave q-only score at
`(theta_A,r_P)`.

Fixed safeguards:

1. require finite derivatives and negative local range curvature;
2. clip transport to the original frozen profile/physical bounds;
3. always retain `r_P` as a candidate;
4. at `theta_E`, score only `r_P` and the transported candidate, selecting the
   higher score within frozen numerical tolerance;
5. retain `r_P` for invalid information or an original profile endpoint;
6. no grid, Brent search, `fminbnd`, line search, bracket expansion or second
   complete profile.

The method has exactly one complete conditional profile per user. Transport adds
one analytic response/derivative evaluation and two q-only candidate evaluations.

## 5. Required outputs

Compare `P_A`, corrected standalone full Scheme E and `E_single_profile`:

- angle RMSE/MSE/median/P90/P95 and paired win/tie/loss;
- range RMSE/MSE, position RMSE and range MSE ratio to P_A;
- standalone runtime and ratios to P_A, full Scheme E and C_enhanced;
- response, MUSIC/subspace, direct-EVD, profile-pass and profile-evaluation counts;
- transport displacement, clipping, fallback, curvature and score diagnostics;
- difference from full Scheme E refreshed range.

## 6. Gates

Apply on both all-600 and holdout-540:

- every-SNR angle MSE ratio to P_A `<=1.01`;
- equal-SNR angle MSE ratio to P_A `<=0.98`;
- every-SNR range MSE ratio to P_A `<=1.02`;
- standalone runtime `<= C_enhanced`;
- exact frozen Scheme E angle identity within `1e-12 deg`;
- exactly one complete profile per user;
- mean standalone runtime ratio to P_A `<=1.02`;
- mean standalone runtime strictly below corrected full Scheme E;
- zero new users and zero R34 final reads/executions.

## 7. Prohibitions and stop rule

Prohibited: second full profile, enlarged bracket, denser grid, outcome-selected
parameters, alpha, Gram, carrier reduction, H/P gating, ML weighting, new users,
R34 final reuse, R36 changes or post-hoc gate relaxation.

Stop after the R37 all-600/holdout-540 decision. PASS does not authorize final
validation. FAIL does not authorize tuning on these 600 rows.
