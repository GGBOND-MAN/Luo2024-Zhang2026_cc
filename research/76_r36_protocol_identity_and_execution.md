# R36 targeted validation: protocol, identity, and execution

Date: 2026-09-12. This round implements the user's instruction to continue validation experiments while preserving the current method.

## Frozen before execution

The complete protocol is stored at [../research_extensions/r36_certificate_validation/PROTOCOL.md](../research_extensions/r36_certificate_validation/PROTOCOL.md), SHA256 `2898f99ece2ffd338d8d04873437b607aa863ecf50f4e3497e1bfa14e0958dfc`. Twelve positions were generated once by a scrambled Latin hypercube using NumPy PCG64 seed 63601236, then saved before MATLAB observations or outputs were generated. The 12 positions span angles [-55,55] degrees and ranges [16,49] m. Each was evaluated at -10, 0, and 20 dB, for 36 conditions.

The experiment calls the preserved source copy at `research_extensions/r35_five_directions/baseline/frozen_matlab`. It retains L06, K=2047, L=160, P=97, the 41/31/21 angle search, the unchanged +/-2 m conditional profile, direct covariance EVD, and `UseGram=false`. The validation joint control uses the same state with angle half-width 0.2 degrees and range half-width 1 m. It is a control, not a replacement estimator.

## Preservation

Before output generation, [baseline_inventory.csv](../research_extensions/r36_certificate_validation/baseline_inventory.csv) recorded 994 prior files and 748,275,187 bytes, including research/01-75, the complete R35 extension, the frozen source copy, and the original R34 package. [preservation_check.csv](../research_extensions/r36_certificate_validation/results/preservation_check.csv) confirms the same bytes remained at delivery.

Each R36 input MAT stores the actual z, Y, RNG state, beta, noise variance, design row, and array hashes. Each result MAT stores the front candidate record, P_A output, joint control, three stage score surfaces, 81-point profile sweep, true-angle profile, and runtime. No failed or unfavorable condition was replaced.

## Execution result

- 36/36 declared conditions completed successfully on 12 positions.
- Parallel execution used four MATLAB R2024b process workers. Per-condition seconds are recorded, but process contention means they are not deployment latency measurements.
- Every condition used 2047 direct EVD operations and zero Gram successes.
- R36 MATLAB unit tests: 5 passed, 0 failed, 0 incomplete. Static analysis found no issues in the certificate, stage, or switch modules; `fileSha256.m` retained one non-behavioral Code Analyzer informational message.

The 36 conditions are new targeted validation evidence relative to R35. They are not appended to R34's predeclared inferential family, and three SNR rows at one position are not called three independent positions.
