# R38 Scheme F raw-array variable-projection ML protocol

Date: 2026-09-13  
Version: `R38-schemeF-raw-array-conditional-vpml-development-v1`  
Evidence role: existing 60-user development evidence only; not independent validation

## 1. Question

Test whether the full raw array snapshots contain useful angle information that
is lost by P_A's per-carrier subarray MUSIC construction and uniform carrier
fusion. Scheme F replaces only the post-P_A local angle objective with a
conditional raw-array variable-projection maximum-likelihood objective.

This is a new isolated R38 branch. R32 through R37 source, results and reports
remain read-only.

## 2. Data and stop boundary

- Use exactly the existing 60 pre-final development users from the frozen R36
  development result, 20 at each of -10, 0 and 20 dB.
- Required input result SHA-256:
  `3533cf2a643b8297f90cbeac6ef4cda0d28235d7734251870a0fcb34eb264b22`.
- Generate no users, seeds, positions, observations or SNR conditions.
- Do not read or execute calibration-600 during Scheme F development.
- R34 final 1400 trials remain forbidden.
- If the 60-user engineering gate fails, freeze the failure and stop. Do not
  alter the likelihood, bracket, gain model or optimizer.
- A development PASS does not automatically authorize calibration or final use.

## 3. Frozen baseline and system

P_A and C_enhanced outputs are the frozen paired references. Scheme F retains:

- `N=256, M=2048, K=2047, L=160, P=97`;
- L06 front, P_A 41/31/21 grids, direct EVD and `UseGram=false`;
- the exact P_A carrier set and actual final P_A angle grid;
- the P_A profile range `r_P` as the fixed conditional range during angle ML;
- the original `+/-2 m`, `lambda=1` q-only conditional range profile after the
  new angle is selected.

## 4. Raw-array conditional VPML objective

For every retained P_A carrier `m`, use the full raw snapshot `y_m` in
`C^N`, not the P_A subarray signal vector. The conditional model is

`y_m = alpha_m a_m(theta,r_P) + n_m`,

with equal spatial noise variance and an independent deterministic complex
nuisance gain `alpha_m`. The gain is eliminated analytically:

`alpha_hat_m(theta) = a_m(theta,r_P)^H y_m`,

because the steering vector has unit norm. Scheme F minimizes

`sum_m ||y_m-alpha_hat_m a_m||^2`,

or equivalently maximizes the globally normalized explained energy

`S_VPML(theta) = sum_m |a_m^H y_m|^2 / sum_m ||y_m||^2`.

No gain, carrier weight, SNR weight or hyperparameter is fitted. With one raw
snapshot per carrier, this likelihood is mathematically equivalent to a
snapshot-energy-weighted rank-one projection residual. That equivalence must be
reported explicitly; Scheme F must not be described as uniform MUSIC or as an
arbitrary learned weighting method.

## 5. Frozen local search

1. Locate `theta_A` on the actual final P_A grid.
2. Use only its immediate left and right grid neighbors as the closed bracket.
3. Hold `r_P`, raw snapshots, P_A carrier set and signal model fixed.
4. Evaluate the two bracket endpoints and `theta_A`.
5. Run one bounded `fminbnd` search with `TolX=1e-10 deg` and no other tuned
   parameter.
6. Retain every evaluated fixed candidate and the converged continuous
   candidate. Select the largest VPML score.
7. The selected score may not be below the score at `theta_A` beyond
   `100*eps*max(1,|score|)`.
8. If the P_A optimum is a final-grid endpoint or the optimizer fails, retain
   the best already evaluated legal candidate; do not expand the bracket.

## 6. Range refresh and output

After selecting `theta_F`, rerun the completely frozen q-only conditional range
profile around the original L06 front range. Do not reuse `r_P` as the final
range for a changed angle.

Report for P_A, C_enhanced and Scheme F:

- angle RMSE/MSE/median/P90/P95;
- paired angle squared-error difference and win/tie/loss;
- refreshed range RMSE/MSE and position RMSE;
- complete standalone runtime;
- q-only response, raw-array VPML, MUSIC and EVD evaluation counts;
- bracket, angle displacement, score before/after, function evaluations,
  convergence and endpoint selection;
- correlation between VPML score gain and truth squared-error gain.

## 7. Engineering gate

Scheme F passes only if all conditions hold on the 60 fixed users:

- every-SNR angle MSE ratio to P_A `<=1.01`;
- equal-SNR aggregate angle MSE ratio to P_A `<=0.98`;
- every-SNR refreshed range MSE ratio to P_A `<=1.02`;
- complete standalone runtime `<= C_enhanced`;
- zero new users, zero calibration reads/executions and zero R34 final access.

## 8. Prohibited actions

No shared-gain alternative, gain-slope model, noise-variance fitting, carrier
subset, carrier normalization variant, score mixture, temperature, alpha
regularizer, SNR/user gate, ML-trained weight, bracket expansion, new angle grid,
additional optimizer, new users, calibration inspection, R34 final reuse or
post-hoc gate relaxation.

Stop immediately after the 60-user Scheme F development decision.
