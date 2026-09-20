# R36 profile mode-switch validation and claims audit

## Fixed sweep result

The unchanged frozen profile was evaluated at 81 fixed offsets from -0.02 to +0.02 degrees in 0.0005-degree steps. An adjacent selected-range jump above 0.02 m was declared a measured switch before execution.

- Conditions with at least one measured switch: **6/36**.
- Positions with a switch in at least one SNR: **6/12**.
- Conditions whose estimated-angle and true-angle endpoints select ranges differing by more than 0.02 m: **0/36**.
- Positions with at least one such endpoint difference: **0/12**.
- Closest measured switch magnitude: **0.00325 degrees**.
- Minimum closest-switch / actual-angle-error ratio: **3.04957917347155**.
- Largest adjacent selected-range jump: **0.571676 m**.

Measured-switch conditions:

| caseId | positionId | snrDb | angleOnlyErrorDeg | switchCount | closestSwitchDeg | switchToAngleErrorRatio | truthEndpointDifferentMode | maximumAdjacentJumpM |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | -10 | -0.00105031 | 1 | -0.01125 | 10.7112 | 0 | 0.21667 |
| 13 | 5 | -10 | 0.00122968 | 1 | 0.00375 | 3.04958 | 0 | 0.158315 |
| 20 | 7 | 0 | -8.936e-05 | 1 | 0.00875 | 97.9185 | 0 | 0.0201966 |
| 22 | 8 | -10 | -0.00118009 | 1 | -0.01125 | 9.5332 | 0 | 0.25519 |
| 29 | 10 | 0 | 0.000113034 | 1 | 0.01725 | 152.609 | 0 | 0.095725 |
| 34 | 12 | -10 | 0.000917433 | 1 | -0.00325 | 3.54249 | 0 | 0.571676 |

Conditions with different estimated-angle and true-angle endpoint modes:

No endpoint difference exceeded 0.02 m.

The closest switch is a grid midpoint, with +/-0.00025-degree discretization uncertainty before considering optimizer tolerance. Endpoint disagreement proves only that the two endpoint optimizations selected ranges separated by more than 0.02 m. It does not prove a unique bifurcation or continuity along the path.

## Decision

The mode-switch mechanism is retained as a real finite-search risk only to the extent shown by the fixed sweep and endpoint results. It does not automatically justify adding a two-dimensional profile, an SNR gate, or an angle marginalization rule. Any new estimator motivated by these rows would be method development after seeing R36 and would require new development data followed by another unseen validation set.

## Claims audit

### Safe

- State exact R36 counts, fixed offsets, jump threshold, and grid resolution.
- State that R36 used 12 new positions and 36 conditions, with clustering by position made explicit.
- State that finite sufficient conditions had 0 observed false certifications on eligible stages.
- Preserve every final angle difference and every condition without post-result replacement.

### Needs qualification

- "Angle is preserved" must be limited to the observed count and frozen finite configuration.
- "Mode switching is relevant" must distinguish a switch somewhere in +/-0.02 degrees from a switch reachable by the actual angle-error endpoint.
- "Independent validation" refers to new positions relative to R35 hypothesis development; it does not extend the R34 statistical family or establish all-channel generality.
- Runtime is parallel experimental throughput under contention, not single-user online latency.

### Remove

- Exact continuous angle-range decoupling, universal angle equality, or globally valid certificate.
- A claim that certificate failure means the selected angles differ.
- A claim that a grid midpoint is the exact mode-switch threshold.
- Any automatic modification of P_A based on R36 outcomes.

[claim_evidence_matrix.csv](../research_extensions/r36_certificate_validation/results/claim_evidence_matrix.csv) stores the structured boundaries. R34 and R35 conclusions remain unchanged.
