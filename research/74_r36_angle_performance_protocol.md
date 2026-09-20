# R36 angle-performance research protocol

Date: 2026-09-12  
Version: `R36-range-orthogonal-angle-protocol-v1`  
Evidence role: development evidence only; not independent final validation

## 1. Isolation and read-only boundary

- R32/R33/R34 frozen source remains read-only and is not overwritten.
- R35 common, Scheme A, Scheme B, Scheme D, their reports, checkpoints and results remain read-only.
- R34 final 1400 trials are forbidden for development, parameter selection, gating or diagnosis.
- R36 code is isolated under `matlab/+r36/`; R36 outputs use a new result directory.

## 2. Development data

- Use only the existing 60 pre-final development users used by R35: -10/0/20 dB, 20 users each.
- Do not generate new users or seeds.
- Do not execute the existing 600-user calibration set in this stage.
- A Scheme E failure stops Scheme E. No post-hoc parameter relaxation or combination with R35 schemes is allowed.

## 3. Frozen system and baselines

- `N=256`, `M=2048`, `K=2047`, `L=160`, `P=97`.
- L06 front, q-only response, direct covariance EVD, `UseGram=false`.
- Frozen P_A angle search: current angle window and `41/31/21` grid.
- Frozen conditional range profile: front-range centered, physical `+/-2 m`, `lambda=1`.
- P_A and C_enhanced remain frozen baselines.

## 4. Scheme E: range-nuisance-orthogonal one-step angle

Scheme E starts from the independently executed frozen P_A output `(theta_A,r_P)` and its frozen spatial MUSIC state.

For each carrier, form the phase-invariant spatial subspace residual `e_m=(I-u_m u_m^H)a_m` and analytic residual Jacobians with respect to angle in radians and range in meters. Build the uniform all-carrier Gauss-Newton gradient and information matrix at `(theta_A,r_P)`.

Remove the local range nuisance through the fixed Schur complement:

`g_eff = g_theta - J_theta,r * J_r,r^-1 * g_r`

`J_eff = J_theta,theta - J_theta,r * J_r,r^-1 * J_r,theta`

Use exactly one Newton/Fisher-style update:

`delta_theta = -g_eff/J_eff`

The update is clipped only to the two neighboring points of the actual final P_A angle grid. If a two-sided bracket is unavailable, the derivatives are nonfinite, or the range/effective information is not positive, retain `theta_A`. There is no iterative optimizer, line search, learned shrinkage, SNR selector, threshold tuning or truth input.

The corresponding nuisance range displacement is diagnostic only. It is never used as the final range output.

## 5. Distance preservation

Every new Scheme E angle must rerun the completely frozen P_A conditional range profile centered on the original frozen front range. The old P_A range and the diagnostic Newton nuisance-range displacement cannot be reused as the final Scheme E range.

## 6. Outputs

Per user and per SNR report:

- angle RMSE/MSE/median/P90/P95;
- paired squared-error difference and win/tie/loss;
- angle displacement and changed fraction;
- local residual gradient, Gauss-Newton information, Schur complement, coupling coefficient and predicted/actual raw-MUSIC cost changes;
- refreshed range RMSE and position RMSE;
- complete runtime, refinement runtime, response/MUSIC evaluation counts and direct-EVD count.

All outputs and figures must be labeled `Development study – not R34 final confirmation`.

## 7. Frozen engineering gate

Scheme E passes only if all conditions hold:

1. Every SNR angle MSE is `<=1.01 * P_A`.
2. Equal-SNR aggregate angle MSE is `<=0.98 * P_A`.
3. Every SNR refreshed range MSE is `<=1.02 * P_A`.
4. Complete runtime is `<=C_enhanced`.

## 8. Prohibited actions

- R34 final reuse;
- new development users;
- R35 A/B/D execution or combination;
- continuous maximization, fminbnd or coordinate ascent;
- new angular grids or expanded brackets;
- alpha/temperature/top-K/threshold searches;
- SNR/user adaptive selection;
- ML weighting;
- reusing the old P_A range for a new angle;
- post-hoc gate relaxation.

## 9. Stop rule

Run exactly the existing 60 development users. Stop after the Scheme E gate decision regardless of PASS or FAIL. Do not automatically execute calibration or final validation.
