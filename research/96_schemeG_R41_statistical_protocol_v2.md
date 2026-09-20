# Scheme G R41 Statistical Protocol v2

Date: 2026-09-14  
Status: **LOCKED, NOT AUTHORIZED, FORMAL FINAL TRIALS = 0**

## 1. Scope of revision

R41 v2 changes only the final statistical hierarchy. R41 v1 remains permanently archived. The Scheme G algorithm, design, 200 positions, all seeds, shard assignment, methods, observation model, bootstrap seed, 20,000 bootstrap replicates, per-SNR max-statistic implementation, source dependencies, and execution core are unchanged.

- Design hash: `a50ad0b244b5f5dba36f3b6322093f30908c99e34f86e17898557d6b17dfe374`.
- Scheme G digest: `b1b823826a707591f49ada5ff6cb093683e3bcab2e2b8479334c20076aec02a4`.
- Archived v1 statistics: `R41-position-cluster-bootstrap-superiority-v1`.
- New statistics: `R41-position-cluster-bootstrap-superiority-v2`.

## 2. Co-primary global endpoints

The core final statistical endpoints are:

`R_theta_global = mean_s(MSE_G_angle,s) / mean_s(MSE_C_angle,s)`

and

`R_range_global = mean_s(MSE_G_range,s) / mean_s(MSE_C_range,s)`.

The seven SNR values receive weights of exactly `1/7`. Position clusters are resampled with replacement using 20,000 deterministic bootstrap replicates and seed `54300000`. The same cluster-index matrix is used at all SNR values and for both endpoints.

For each bootstrap replicate, the method MSE is first computed within each SNR over the resampled positions, then averaged equally across the seven SNR values, and finally formed into the ratio `G/C`. The one-sided 95% upper bound is the 95th percentile of the bootstrap ratio distribution. There is no studentization of the global ratio and no post-final method change. A nonpositive or nonfinite `C_enhanced` denominator stops the endpoint and permits no claim.

Angle success requires `U95(R_theta_global) < 1`. Range success requires `U95(R_range_global) < 1`. **Core final statistical success requires both co-primary endpoints to pass.** Per-SNR or descriptive results cannot rescue either failed global endpoint.

## 3. Pointwise consistency gate

This is a descriptive engineering gate, not a significance test. At every one of the seven SNR values, both strict inequalities must hold:

- observed `MSE_G_angle,s < MSE_C_angle,s`;
- observed `MSE_G_range,s < MSE_C_range,s`.

If the co-primary global endpoints pass but this gate fails, overall global superiority may be reported, but uniform numerical improvement cannot be claimed.

## 4. Per-SNR simultaneous characterization

The v1 Family A and Family B calculations remain unchanged:

- Family A: seven angle squared-error differences `G-C`.
- Family B: seven range squared-error differences `G-C`.

Each family independently uses the frozen one-sided 95% studentized max-statistic simultaneous upper bounds. A specific SNR is statistically superior only when its corresponding upper bound is below zero. These families are confirmatory per-SNR characterization and are not required for core global success.

## 5. Strong all-SNR endpoint

Strong all-SNR success is predeclared as all seven Family A upper bounds below zero **and** all seven Family B upper bounds below zero. It is a stronger result tier than core final statistical success.

## 6. Frozen interpretation

- **Level 1:** the two co-primary global endpoints do not jointly pass. Final joint angle-and-range superiority is not established. Secondary or per-SNR results cannot rescue this outcome.
- **Core-only pointwise inconsistency:** both global endpoints pass but the pointwise gate fails. Overall global superiority may be reported; uniform numerical improvement may not be claimed.
- **Level 2:** both global endpoints and the pointwise gate pass, but strong all-SNR success does not. Report overall statistically superior angle and range MSE, numerically lower errors at every tested SNR, and list only the SNR subset passing the frozen simultaneous inference.
- **Level 3:** both global endpoints, the pointwise gate, and all 14 simultaneous bounds pass. Report statistically superior angle and range performance at every tested SNR.

No hierarchy, wording, estimand, confidence algorithm, or family role may be changed after final data are observed.
