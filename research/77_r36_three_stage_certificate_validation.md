# R36 three-stage angle-preservation validation

## Question

Under the frozen K2047/L160/P97 configuration, does replacing the fixed-range angle search with a +/-1 m joint angle-range MUSIC search change the selected angle, and when do the finite-grid sufficient conditions certify preservation?

The comparison reuses the same generated observation, front, carrier set, compensation state, and subspace. Only the MUSIC search dimension differs. This is not a comparison with Zhang2026 author code.

## Final-angle result

- Exact final equality: **35/36 conditions**.
- Within one final P_A grid step: **36/36 conditions**.
- Positions with exact equality at all three SNRs: **11/12 positions**.
- Maximum absolute final angle difference: **0.000266666667 degrees**.

Descriptive exact-binomial intervals by condition are included only to show finite-sample uncertainty; condition rows share positions and do not define a broad population sample:

| group | metric | count | n | fraction | exact95Lower | exact95Upper |
| --- | --- | --- | --- | --- | --- | --- |
| all | exactFinalAngleEqual | 35 | 36 | 0.972222 | 0.854711 | 0.999297 |
| all | withinOneFinalGridStep | 36 | 36 | 1 | 0.902606 | 1 |
| -10 dB | exactFinalAngleEqual | 12 | 12 | 1 | 0.735352 | 1 |
| -10 dB | withinOneFinalGridStep | 12 | 12 | 1 | 0.735352 | 1 |
| 0 dB | exactFinalAngleEqual | 11 | 12 | 0.916667 | 0.615204 | 0.997892 |
| 0 dB | withinOneFinalGridStep | 12 | 12 | 1 | 0.735352 | 1 |
| 20 dB | exactFinalAngleEqual | 12 | 12 | 1 | 0.735352 | 1 |
| 20 dB | withinOneFinalGridStep | 12 | 12 | 1 | 0.735352 | 1 |

Differing conditions:

| caseId | positionId | snrDb | truthThetaDeg | truthRangeM | angleOnlyThetaDeg | jointThetaDeg | finalDifferenceDeg | finalAngleGridStepDeg |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | 1 | 0 | 43.0363 | 47.9825 | 43.0363 | 43.036 | 0.000266667 | 0.000266667 |

## Stage-level result

| level | rows | eligible | sameSelected | symmetricPass | conservativePass | falseSymmetric | falseConservative | fixedRangeIncluded |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 36 | 36 | 36 | 26 | 36 | 0 | 0 | 36 |
| 2 | 36 | 36 | 36 | 23 | 33 | 0 | 0 | 20 |
| 3 | 36 | 36 | 35 | 18 | 33 | 0 | 0 | 14 |

`eligible` means every preceding selected angle remained common and the current angle grid was the same. A later stage after divergence is not counted by the recursive theorem. `sameSelected` is reported for the saved actual finite grids. `fixedRangeIncluded` shows why the first-stage zero-gain lower bound cannot silently be applied at every later stage.

The symmetric condition uses gap > 2 epsilon. The conservative one-sided condition uses zero selected-angle gain only when rF lies on the actual range grid; otherwise it uses the minimum measured gain over that stage. The realized finite margin uses the maximum measured gain on both sides and is diagnostic, because computing it already evaluates the finite joint surface.

False certificate count across both sufficient-condition columns: **0**. A zero count supports the implementation of the finite implication on this set; it is not proof over untested models or continuous parameter domains.

## Interpretation

The experiment does not support an unconditional statement that one-dimensional and joint MUSIC always select the same angle. It identifies the stage and finite score geometry at which differences occur. Where a sufficient condition passes on an eligible stage, the saved selected angle is consistent with that condition. Where it fails, no opposite conclusion follows: the methods may still agree.

The current certificate is an explanatory mechanism. It recomputes the actual finite joint score surface and therefore does not yet provide online acceleration. A useful next method-development step would require a cheaper rigorous upper bound for competitor range gain, followed by a separately frozen validation; R36 itself does not select such a bound.

Sources: [conditions.csv](../research_extensions/r36_certificate_validation/results/conditions.csv), [stage_certificates.csv](../research_extensions/r36_certificate_validation/results/stage_certificates.csv), and all `results/case_XX.mat` files.
