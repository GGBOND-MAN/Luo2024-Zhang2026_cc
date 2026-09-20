# R42 Scheme H: PA-free full-aperture joint development protocol

Date: 2026-09-17  
Version: `R42-schemeH-pa-free-joint-development-v1`  
Evidence role: new development experiment; not calibration or independent final evidence

## 1. Objective

Test whether a standalone estimator can improve both angle and range relative to
the frozen `P_A` without executing `P_A` or consuming its final angle, range,
grid, bracket, subspace, or range-profile output.

The target estimator is Scheme H:

`L06 multi-candidate front -> joint z+Y variable projection -> direct theta/r output`.

`P_A` is executed only as a paired baseline outside the Scheme H estimator.

## 2. Frozen evidence boundary

- R34 and R41 final observations, estimates, statistics, and reports are read-only.
- No R34/R41 position, observation, or result may be used for selection, tuning,
  debugging, fallback, or stopping decisions.
- The existing `P_A`, Scheme G, and all R29-R41 sources are read-only.
- R42 uses new deterministic position and trial seeds.
- The pilot contains 10 positions reused at `-10/0/20 dB`, for 30 paired rows.
- Passing the pilot may authorize a separate development-60 run. It does not
  authorize calibration or an independent final claim.

## 3. Observation model and concentrated objective

The scalar scan observation is `z = beta q(theta,r) + n_z`, with exact spherical
`q` and one cross-carrier complex nuisance gain. The full-array snapshots are
`y_m = alpha_m a_m(theta,r) + n_y,m`, with the current Fresnel `N=256` steering
convention and one independent complex nuisance gain per carrier.

Define `E_z = min_beta ||z-beta q||^2` and
`E_Y = sum_m min_alpha_m ||y_m-alpha_m a_m||^2`. To avoid an empirically tuned
fusion coefficient, Scheme H profiles one noise scale per observation block and
minimizes

`C_H = [M log(E_z/M) + NK log(E_Y/(NK))] / (M+NK)`.

This is not an arbitrary sum of a MUSIC score and a spectral score. It is the
blockwise concentrated Gaussian objective under the stated conditional model.

## 4. Candidate generation and optimization

1. Run the unchanged L06 sparse full-band front from current `z` only.
2. Retain its eight refined full-spectrum candidates.
3. Evaluate the exact Scheme H objective at all valid candidates.
4. Select the three lowest-cost candidates as starts.
5. Run bounded damped Gauss-Newton with analytic variable-projection
   derivatives, physical-domain clipping, Armijo backtracking, and exact-cost
   monotonicity safeguarding.
6. Return the valid refined candidate with the lowest exact joint cost.

There is no P_A neighbor bracket and no final conditional range scan in primary
`H_joint`.

## 5. Full-aperture sequential ablation

`H_array` shares L06 but replaces P_A's `L=160` spatial-smoothed MUSIC angle
stage with a full-`N=256` raw-array conditional variable-projection angle search.
It then runs one unchanged conditional q-only range profile. This PA-free
ablation separates the full-aperture mechanism from the joint objective.

## 6. Pilot metrics and gates

Compare frozen `P_A`, `H_array`, primary `H_joint`, and the L06 front. Report
angle/range/position RMSE, median/P90/P95, range misses above 1 m, paired
win/tie/loss, MSE ratios, convergence diagnostics, and complete online time.

The 30-row pilot passes only if `H_joint` satisfies all:

1. each-SNR angle MSE ratio `H_joint/P_A <= 1.05`;
2. equal-SNR angle MSE ratio `<= 0.98`;
3. each-SNR range MSE ratio `<= 1.05`;
4. equal-SNR range MSE ratio `<= 0.99`;
5. zero failures and finite outputs;
6. every accepted refinement has non-increasing exact joint cost;
7. no R34/R41 final data are read or executed.

These are development engineering gates, not statistical superiority claims. A
failure stops expansion without changing Scheme H from the pilot outcomes.
