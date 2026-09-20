# R40 Scheme G full-aperture range-profiled protocol

Date: 2026-09-14  
Version: `R40-schemeG-full-aperture-range-profiled-v1`  
Evidence role: staged development/calibration evidence; not independent final confirmation

## 1. Objective

Scheme G applies Scheme E's local Schur-complement range-nuisance profiling to
Scheme F's full `N=256` raw-array snapshot model. The primary estimator is:

`frozen P_A -> full-aperture one-step profiled angle -> R37 implicit q-range transport`.

It must preserve the full-aperture angle mechanism without Scheme F's bounded
multi-evaluation optimizer or second complete range profile.

## 2. Frozen evidence boundary

- R34 final 1400 trials are forbidden for development, calibration, comparison,
  tuning, diagnosis or selection.
- No users, seeds, SNR conditions, positions or observations may be generated.
- R34 through R39 sources, results and reports are read-only.
- P_A, C_enhanced, E and F implementations and historical results are frozen.
- Scheme A/B/D, gating, selectors, alpha/shrinkage, learned weighting, bracket
  expansion, carrier selection changes, Gram, new subarrays, new range grids,
  line search, damping and alternating theta-range optimization are forbidden.
- Passing development/calibration does not authorize reuse of R34 final or any
  independent-final claim.

## 3. Frozen system

- `N=256`, `M=2048`, `K=2047`, P_A `L=160`, `P=97`;
- L06 front, q-only response, direct EVD and `UseGram=false`;
- P_A `41/31/21` angle grid and its actual final immediate-neighbor bracket;
- exact conditional q-only range profile centered on the frozen front range,
  half-width `+/-2 m`, `lambda=1`;
- synchronous LoS single-path `z+Y` observation model.

Scheme G starts only from frozen P_A `theta_A,r_A`; Scheme A output is not an
authorized starting point.

## 4. Full-array variable-projection model

For each frozen P_A carrier:

`y_m = alpha_m a_m(theta,r) + n_m`,

where `a_m` is the unit-norm full-`N=256` Fresnel steering vector using the
exact Scheme F convention and `alpha_m` is an independent complex nuisance
gain. At `(theta_A,r_A)`:

`alpha_hat_m = a_m^H y_m`, `e_m=(I-a_m a_m^H)y_m`.

The normalized concentrated cost is

`C(theta,r)=sum_m ||e_m||^2 / sum_m ||y_m||^2`.

It is exactly `1-S_F`, where `S_F` is Scheme F's normalized explained-energy
score.

The reduced Jacobians are

`d_theta,m=alpha_hat_m(I-a_m a_m^H)a_theta,m`,

`d_r,m=alpha_hat_m(I-a_m a_m^H)a_r,m`.

With theta in radians and range in meters:

`g_i=-2 Re sum_m d_i,m^H e_m / E_y`,

`J_ij=2 Re sum_m d_i,m^H d_j,m / E_y`.

Finite-difference tests must confirm the steering derivatives, concentrated
cost gradient and sign convention before any user run.

## 5. Primary and diagnostic angle steps

Primary `G_schur`:

`g_eff=g_theta-J_theta_r/J_rr*g_r`,

`J_eff=J_theta_theta-J_theta_r^2/J_rr`,

`delta_theta_raw=-g_eff/J_eff`.

Diagnostic `G_fixed` uses the same linearization:

`delta_theta_fixed=-g_theta/J_theta_theta`.

Both are clipped to the unchanged final P_A immediate-neighbor bracket. For
each clipped angle step, the local array nuisance range step is

`delta_r_array=-(g_r+J_r_theta*delta_theta)/J_rr`.

The candidate is accepted only if the exact full-array concentrated cost at
`(theta_candidate,r_A+delta_r_array)` decreases beyond a fixed numerical
tolerance. Otherwise theta_A is retained. No line search or step-size parameter
is permitted.

Information and cost tolerances are fixed at `100*eps` times the applicable
unit-or-observed scale. Nonfinite information, nonpositive `J_rr/J_eff`, final
grid endpoints or physically invalid candidate range cause deterministic
fallback to P_A.

## 6. Final range

No second complete range profile is authorized. For each G angle, invoke the
unchanged R37 single-profile implicit transport:

`delta_r_q=-(J_r+J_rtheta*delta_theta_G)/J_rr`.

Only `r_A` and the bounded transported range are evaluated with the same exact
q-only profile score; the higher-score candidate is retained. Invalid negative
curvature or an original profile endpoint retains `r_A`.

`delta_r_array` is diagnostic only and must never be mixed into final `r_G`.

## 7. Stage 1 data and comparisons

Use only the existing 60 development users, 20 each at -10/0/20 dB. Frozen
inputs:

- R38 Scheme F development result SHA-256:
  `935e9bea7bad14fb66986871d6e344eb777b309b8d9b103da6ebfd4260053d89`;
- R37 E single-profile result SHA-256:
  `400443c8131c41a235233efd8d393e55bf3fc9097e138883f1cfb4e0299fe70d`.

P_A and C_enhanced are re-executed with their frozen implementations in the
R40 session solely to obtain same-session timing and must reproduce frozen
theta/r outputs within fixed identity tolerances. Range identity uses the
existing R33 equivalent-implementation tolerance `1e-7 m`; this is an inherited
reproducibility tolerance and is not an estimator or performance parameter.
E single and F are read-only
references paired by seed.

Compare P_A, C_enhanced, E single, F, G_fixed and G_schur. Report all metrics
specified by the request, including per-SNR/equal-SNR angle statistics, paired
comparisons, range misses, position, complete runtime, incremental breakdown,
profile count and mechanism diagnostics.

## 8. Predeclared Stage 1 gates

Primary G_schur must satisfy all:

1. each-SNR angle `MSE_G/MSE_C <= 1.00`;
2. equal-SNR angle `MSE_G/MSE_C <= 0.95`;
3. each-SNR range `MSE_G < MSE_C`;
4. each-SNR range `MSE_G/MSE_P_A <= 1.01`;
5. same-session reconstructed complete runtime `T_G <= T_C`;
6. complete full-range-profile passes exactly `1` for every row.

`T_G/T_P_A <=1.05` is a target, not a hard gate.

If any hard gate fails, stop Scheme G without changing the method.

## 9. Conditional calibration

Only a complete Stage 1 pass authorizes deterministic execution on the existing
calibration-600. Before calibration, the Stage 1 algorithm-source digest and
all protocol fields are frozen and must match exactly. Frozen calibration input:

- R38 Scheme F calibration result SHA-256:
  `20df32a5b235f293e284745bfa6c9ca757dcad13012cb621d7ba17c2c33a5ad3`;
- calibration data digest:
  `39538d66a6724e198d9c569c2f9e24b9185c4d3d979bc4f224724fbf5d50dcc0`.

Calibration uses the same gates and method without any modification. A pass is
only a `calibration candidate PASS`; it does not authorize R34 final or new
independent users.

## 10. Stop rule

- Stage 1 failure: write failure evidence and stop.
- Stage 1 pass followed by calibration failure: write calibration evidence and
  stop.
- Calibration pass: freeze the candidate and stop. Do not launch independent
  confirmation automatically.
