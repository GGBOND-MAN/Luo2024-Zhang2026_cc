# Scheme G Independent Final Confirmation Protocol (R41)

Date: 2026-09-14  
Status: **LOCKED, NOT AUTHORIZED, FINAL TRIALS = 0**

## 1. Frozen algorithm identity

- Primary candidate: `G_schur`, the frozen R40 Schur-profiled one-step Scheme G.
- Primary reference: `C_enhanced`, described only as the strengthened Zhang-style executable baseline. It is not claimed to be author-supplied Zhang2026 code.
- Secondary descriptive method: `P_A`.
- `G_fixed`, `C_public`, Scheme E, and Scheme F are excluded from the primary final execution.
- Frozen Scheme G digest: `b1b823826a707591f49ada5ff6cb093683e3bcab2e2b8479334c20076aec02a4`.
- R40 mathematics, Schur step, bracket, full-array model, q transport, range profile, carrier/subarray selection, grids, fallback, and tolerances are read-only.

## 2. Independent design

- 200 new positions and seven SNR values: `[-10,-5,0,5,10,15,20] dB`.
- Total: 1400 paired rows.
- The same 200 positions are reused at all seven SNR values. `positionId` is the bootstrap cluster.
- User law: independent uniform angle over `[-60,60] deg` and uniform range over `[15,50] m`.
- Per-position seed: `54100000 + positionId`, giving `54100001..54100200`.
- Per-trial seed: `54200000 + 1000*snrIndex + positionId`, with one-based ascending `snrIndex`.
- Ordering is position-major, then ascending SNR.
- Server 1 receives positions 1-100; server 2 receives positions 101-200. A position cluster is never split.
- The generated design is checked against the inherited R29-R40 development/calibration population and the R34 final design for both seed and exact truth-position collisions.
- `protocol.mat` and `design.csv` are immutable. There is no redraw mechanism.

## 3. Primary inference

Bootstrap unit: `positionId`. Replicates: 20,000. Bootstrap seed: `54300000`. The exact same cluster resample indices are used across all seven SNR values.

Family A is the seven-SNR family of angle squared-error differences:

`delta_theta = angleError_G^2 - angleError_C^2`.

Family B is the separate seven-SNR family of range squared-error differences:

`delta_r = rangeError_G^2 - rangeError_C^2`.

Each family uses a one-sided 95% studentized max-statistic simultaneous upper bound. An SNR is statistically superior only when its upper bound is below zero. Overall primary success requires all seven angle bounds and all seven range bounds to be below zero. The two families are controlled separately and are never combined into a 14-comparison family.

## 4. Global endpoints and hierarchy

The equal-SNR global endpoints are frozen as **secondary confirmatory** endpoints:

- `R_theta_global = mean_7SNR(MSE_G_angle) / mean_7SNR(MSE_C_angle)`.
- `R_range_global = mean_7SNR(MSE_G_range) / mean_7SNR(MSE_C_range)`.

Each uses the one-sided 95th percentile of the position-cluster bootstrap ratio. An upper ratio below one supports an overall claim across the tested SNR set. These endpoints cannot rescue a failed primary family and cannot be promoted after results are observed.

## 5. Descriptive outputs

Per SNR and method:

- Angle: MSE, RMSE, median absolute error, P90, P95.
- Range: MSE, RMSE, median absolute error, P90, P95, and `>1 m` miss rate.
- Position: RMSE, secondary descriptive only.
- Paired `G_schur` versus `C_enhanced`: squared-error difference and win/tie/loss counts and rates for angle and range.

## 6. Complexity evidence

Performance-shard throughput is not algorithm runtime evidence. After the complete final aggregate, a separate same-machine matched timing run uses final-design positions 1-20 at 0 dB, three repetitions, one warmup, and deterministic cyclic method order for `G_schur`, `P_A`, and `C_enhanced`.

Report complete online wall time, runtime ratios, EVD count, MUSIC evaluations, full-array evaluations, profile passes, profile evaluations, and response-equivalent counts. The engineering runtime target is `T_G <= T_C`. No comparison is made to milliseconds estimated in the Zhang paper.

## 7. Integrity and stopping rules

Before any observation generation, the runner must validate explicit authorization, Scheme G digest, R33 digest, R34 digest, transitive frozen dependency digest, complete source digest, design hash, statistics hash, and shard identity.

An existing final result directory causes a clear failure before authorization checking or trial execution, unless the exact shard is explicitly resumed from an identity-matching checkpoint. Completed or failed rows are never rerun or replaced. Any failed row stops primary inference. There is no significance-driven stopping, extra users, tail deletion, unfavorable-seed rerun, design regeneration, method change, bootstrap change, family change, or post-final selection of `G_fixed`.

Exactly one explicitly authorized 1400-row performance execution is permitted. At protocol creation, authorization is absent and the formal final trial count is zero.
