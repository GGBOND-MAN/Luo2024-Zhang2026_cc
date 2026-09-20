# R39 aperture and VPML likelihood factorial ablation protocol

Date: 2026-09-13  
Version: `R39-aperture-vpml-factorial-ablation-development-v1`  
Evidence role: mechanism-only development evidence; not method selection or independent validation

## 1. Objective

Separate two changes introduced together by Scheme F:

1. aperture expansion from one central `L=160` subarray to the full `N=256`
   array;
2. replacement of equal-carrier normalized projection fusion by the raw-array
   conditional VPML likelihood aggregation.

Use a fixed 2-by-2 factorial comparison:

| Variant | Aperture | Aggregation |
|:--|--:|:--|
| `L160_uniform` | 160 | equal carrier normalized projection |
| `L160_vpml` | 160 | raw energy VPML |
| `N256_uniform` | 256 | equal carrier normalized projection |
| `N256_vpml` | 256 | raw energy VPML, frozen Scheme F |

## 2. Data and isolation

- Use only the existing 60 pre-final development users, 20 at each of
  -10/0/20 dB.
- Required frozen Scheme F development result SHA-256:
  `935e9bea7bad14fb66986871d6e344eb777b309b8d9b103da6ebfd4260053d89`.
- Reuse frozen `N256_vpml` per-user results. Execute only the other three cells.
- Do not read calibration-600 for new variant estimation.
- Generate no users, seeds, positions, observations or SNR conditions.
- Do not access R34 final 1400 trials.
- R32 through R38 sources and results are read-only.

## 3. Common estimator controls

All four cells use:

- the exact P_A K=2047 carrier set;
- P_A profile range `r_P` fixed during angle refinement;
- the immediate-neighbor bracket of the actual final P_A grid;
- the frozen Scheme F bounded search and candidate-retention rule;
- one new-angle rerun of the frozen `+/-2 m`, `lambda=1` q-only range profile;
- no gating, learned weight, carrier selection, bracket expansion or parameter
  fitting.

The `L=160` aperture is the fixed central contiguous subarray starting at the
same reference subarray index used by the P_A alignment implementation. It is
not spatial smoothing and does not reuse the P_A EVD signal vector.

## 4. Objectives

For aperture-normalized steering `a_m` and raw aperture snapshot `y_m`:

- uniform projection:
  `S_U(theta)=K^-1 sum_m |a_m^H y_m|^2/||y_m||^2`;
- VPML likelihood:
  `S_ML(theta)=sum_m |a_m^H y_m|^2/sum_m ||y_m||^2`.

`S_ML` is the equal-spatial-noise conditional likelihood after eliminating an
independent complex gain per carrier. `S_U` removes snapshot-energy weighting
and gives every carrier equal influence.

## 5. Attribution

Report per SNR and equal-SNR aggregate angle MSE ratios:

- aperture effect under uniform:
  `MSE(N256_uniform)/MSE(L160_uniform)`;
- aperture effect under VPML:
  `MSE(N256_vpml)/MSE(L160_vpml)`;
- likelihood effect at L160:
  `MSE(L160_vpml)/MSE(L160_uniform)`;
- likelihood effect at N256:
  `MSE(N256_vpml)/MSE(N256_uniform)`;
- interaction ratio:
  `[N256_vpml/L160_vpml]/[N256_uniform/L160_uniform]`.

Also report P_A-relative angle/range/position metrics, win/tie/loss, runtime,
evaluation counts, endpoint saturation and score-truth correlation.

This factorial identifies effects within the raw-snapshot estimator family. It
does not isolate P_A spatial smoothing from central-subarray raw processing.

## 6. Gate and stop rule

No ablation cell is promoted in this round. For diagnostic completeness, apply
the common P_A angle/range/runtime gates separately to each cell, but do not use
their outcome to select or tune a new main method.

Stop after the fixed 60-user factorial result. No calibration execution, F/E
combination, single-profile transport, bracket expansion or post-hoc variant.

The frozen R38 calibration-600 result may be read after the ablation solely to
render the requested E/F/P_A comparison figures. It is not available to any
R39 estimator, factor definition, parameter choice or gate calculation.
