# R38 Scheme F frozen calibration-600 protocol

Date: 2026-09-13  
Version: `R38-schemeF-frozen-calibration600-v1`  
Evidence role: pre-final calibration evidence; not independent final validation

## 1. Authorization and frozen estimator

Scheme F passed every predeclared 60-user development gate. This protocol
authorizes only the next staged evaluation on the existing calibration-600
design. The Scheme F estimator is frozen at algorithm digest

`67bc633f6d58b2fc410bd47dbd304e915d40a8999b682bc3339ca5f03db1b38d`.

No raw-array objective, gain model, carrier rule, bracket, optimizer tolerance,
candidate retention rule or refreshed range profile may change.

Required development artifacts:

- `result.mat`: `935e9bea7bad14fb66986871d6e344eb777b309b8d9b103da6ebfd4260053d89`;
- `per_user_outputs.csv`: `60675b64a643e5132ffd493ba865740c51d6b1ada0c47d3d501eb3f27be3c1f2`;
- `engineering_gate.csv`: `e9bc986a9c15df07713d71da9f554065536b3fec1ec0877fc068ee715b2f1cdd`.

## 2. Existing calibration data

- Use exactly the existing `calibration600` design with digest
  `39538d66a6724e198d9c569c2f9e24b9185c4d3d979bc4f224724fbf5d50dcc0`.
- Exactly 600 unique rows: -10/0/20 dB, 200 each.
- The original 60 development users form a fixed overlap subset.
- Report all 600 and the fixed 540-row non-development subset, 180 per SNR.
- Generate no new user, seed, position, observation or SNR condition.
- R34 final 1400 trials remain forbidden.

Frozen read-only calibration references:

- R36 calibration result SHA-256:
  `f998fc2258210c13ef98345ea04b4637c7d93b762795fc575c8da92a200bb446`;
- R37 E single-profile result SHA-256:
  `400443c8131c41a235233efd8d393e55bf3fc9097e138883f1cfb4e0299fe70d`.

P_A and C_enhanced are read from the frozen R36 paired results. E
single-profile is a read-only diagnostic comparator. None is re-estimated.

## 3. Required execution

For every existing row, replay the identical raw spectral observation and
N-by-M array snapshots. Run the exact development-passed Scheme F:

1. frozen P_A `theta_A,r_P` and exact K=2047 carrier identity;
2. full N=256 raw-array independent-gain conditional VPML within the immediate
   neighbor bracket of the actual final P_A grid;
3. one bounded `fminbnd` with `TolX=1e-10 deg`;
4. retain legal fixed candidates and the converged continuous candidate;
5. rerun the unchanged `+/-2 m`, `lambda=1` q-only conditional range profile.

The 60 overlap rows must reproduce the development Scheme F angle, range and
non-timing diagnostics within frozen numerical tolerances.

## 4. Comparisons and outputs

Report P_A, E single-profile, Scheme F and C_enhanced for all-600,
holdout-540 and overlap-60:

- angle RMSE/MSE/median/P90/P95;
- paired squared-error differences and win/tie/loss for F vs P_A and F vs E;
- range and position RMSE;
- standalone runtime and response/MUSIC/EVD/profile counts;
- VPML displacement, function evaluations, convergence, endpoint saturation,
  score gain and score-truth correlation;
- F/E angle, range, position and runtime ratios.

## 5. Calibration gate

Apply the unchanged public gates separately to all-600 and holdout-540:

- every-SNR F/P_A angle MSE ratio `<=1.01`;
- equal-SNR F/P_A angle MSE ratio `<=0.98`;
- every-SNR refreshed F/P_A range MSE ratio `<=1.02`;
- F standalone runtime/C_enhanced `<=1.00`.

Calibration readiness requires every gate in both populations and exact overlap
reproduction. F/E comparisons are diagnostic and cannot replace a failed P_A
gate.

## 6. Prohibited actions and stop rule

No parameter change, bracket expansion, shared-gain variant, gain-slope model,
noise fitting, carrier subset, score mixture, gating, learned weighting,
single-profile combination, new users, R34 final reuse, adverse-row removal or
post-hoc gate relaxation.

Stop after the fixed all-600/holdout-540 decision. PASS does not authorize R34
final execution. FAIL does not authorize tuning on calibration evidence.
