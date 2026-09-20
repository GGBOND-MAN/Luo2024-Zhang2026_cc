# R36 Scheme E calibration-600 protocol

Date: 2026-09-12  
Version: `R36-schemeE-frozen-calibration600-v1`  
Evidence role: pre-final calibration evidence; not independent final validation

## 1. Authorization basis

Scheme E passed every frozen 60-user development gate in `research/75_schemeE_range_orthogonal_one_step.md`. Calibration is therefore authorized under the existing staged research policy.

The Scheme E estimator is frozen. Calibration cannot change its objective, derivatives, one-step formula, numerical tolerance, bracket, profile, baselines or engineering gates.

Frozen development identities:

- algorithm digest: `27879e532e1ffefa1223a7a2ed56a6845ade09ed97e98f58ed56851436ba5908`;
- development result SHA-256: `3533cf2a643b8297f90cbeac6ef4cda0d28235d7734251870a0fcb34eb264b22`;
- development per-user CSV SHA-256: `cd75f7e46cfa3b6de5b96c83b898e450080bb69b1aff52a8e741ed1688c73fa6`;
- development gate CSV SHA-256: `edbc9b063048d452d6c48872cd10980cd187c86a8acb7363716aa3108bed7cdc`.

## 2. Calibration data

- Reuse the existing Round 27/Round 30 `calibration600` design only.
- Data hash: `39538d66a6724e198d9c569c2f9e24b9185c4d3d979bc4f224724fbf5d50dcc0`.
- Exactly 600 unique saved users: -10/0/20 dB, 200 each.
- No new users, seeds or observations may be generated beyond deterministic replay of these saved rows.
- R34 final 1400 trials remain forbidden.

The 60 development users are a predetermined subset of the 600 rows. Results must be reported for:

1. all 600 calibration rows;
2. the fixed 540-row non-development subset, 180 per SNR.

No alternative subset may be selected after observing performance.

## 3. Frozen estimator and range handling

For every row, independently execute frozen P_A, frozen C_enhanced and the exact frozen Scheme E implementation. The new Scheme E angle always reruns the frozen conditional range profile. The diagnostic nuisance-range displacement is never used as the output range.

## 4. Calibration gates

Apply the unchanged development gates separately to both the all-600 and fixed holdout-540 summaries:

- every SNR angle MSE ratio to P_A `<=1.01`;
- equal-SNR aggregate angle MSE ratio `<=0.98`;
- every SNR refreshed range MSE ratio to P_A `<=1.02`;
- complete runtime ratio to C_enhanced `<=1.00`.

Calibration readiness requires every gate to pass in both summaries. The 600-row result cannot compensate for a 540-row holdout failure or vice versa.

## 5. Required diagnostics

Report angle RMSE/MSE/median/P90/P95, paired squared-error differences, win/tie/loss, range/position RMSE, runtime and evaluation counts. Also report valid updates, bracket clipping, displacement, tangent coupling, diagnostic range displacement and raw-MUSIC cost reduction.

All calibration artifacts must be labeled:

`Calibration study – not R34 final confirmation`

## 6. Prohibited actions

- any Scheme E code or parameter modification;
- R35 A/B/D execution or combination;
- Scheme F execution;
- user/SNR selectors;
- bracket expansion, extra steps or line search;
- alpha, temperature, top-K, threshold or ML weighting;
- removal of adverse rows or SNRs;
- R34 final reuse;
- post-hoc gate relaxation.

## 7. Stop rule

Stop after the frozen 600/540 calibration decision. PASS does not authorize automatic R34 final execution. FAIL does not authorize tuning Scheme E on calibration evidence.
