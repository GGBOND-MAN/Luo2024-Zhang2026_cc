# Scheme G R41 v2 Execution Guide

Date: 2026-09-14  
Current state: **pre-authorization; formal final trials = 0**

R41 v1 is an immutable archive. R41 v2 uses its byte-identical `design.csv` and unchanged `r41.finalTrial`, partition, checkpoint, estimator, observation, Scheme G, and baseline code.

## Preparation checks

The v2 protocol package is located at:

`matlab/results/full_spectrum/round41_schemeG_independent_final_protocol_v2/`

Before authorization, run:

```matlab
preflight_r41v2_schemeG_final("pre-authorization")
```

Expected state: v1 and v2 authorization files absent, v1 and v2 final result directories absent, all tests passing, Code Analyzer empty, synthetic checkpoint/resume passing, and formal final trials equal to zero.

## Future authorization

Only after a new explicit user instruction may the following be run:

```matlab
authorize_r41v2_schemeG_final( ...
    "I_EXPLICITLY_AUTHORIZE_R41_V2_SCHEME_G_FINAL_1400")
```

This command is not part of preparation or testing.

## Future shards

On one 32-vCPU server, use **two independent clean copies** of the exact authorized workspace. Run shard 1 in copy A and shard 2 in copy B, sequentially unless the server has resources for two explicitly isolated MATLAB jobs. Do not run shard 2 in copy A after shard 1 has created its final result root: the clean-root guard must remain active.

Run the authorized-execution preflight separately in both clean copies before either shard:

```matlab
preflight_r41v2_schemeG_final("authorized-execution")
```

In copy A:

```matlab
run_r41v2_schemeG_final_shard(1, ...
    NumWorkers=32, BatchSize=8, PoolType="Threads")
```

In copy B:

```matlab
run_r41v2_schemeG_final_shard(2, ...
    NumWorkers=32, BatchSize=8, PoolType="Threads")
```

Shard 1 remains positions 1-100 and shard 2 remains positions 101-200. Resume is permitted only for an exact incomplete identity-matching checkpoint. Completed or failed rows are never replaced.

## Future aggregate

After both complete zero-failure shards are assembled, create a third clean aggregation copy with the same source, protocol, and authorization. Copy only `shard_01_of_02` from copy A and `shard_02_of_02` from copy B into its `round41_schemeG_independent_final_v2` result root. Do not merge checkpoint cells or edit result files. Then run:

```matlab
aggregate_r41v2_schemeG_final
```

The aggregate writes the co-primary global endpoints, descriptive pointwise consistency gate, unchanged per-SNR simultaneous characterization, strong all-SNR result, and frozen interpretation level. Any failed trial stops statistical inference.

The unchanged post-aggregate same-machine timing protocol is available as:

```matlab
run_r41v2_schemeG_matched_timing
```

It retains the same 20 frozen positions, 0 dB condition, repetitions, warmups, cyclic order, methods, and runtime interpretation as v1.

## Independent final audit and reports

Only after the aggregate and matched timing both complete successfully, run:

```matlab
audit_r41v2_schemeG_final
generate_r41v2_final_reports
```

The audit verifies row/cluster balance, shard separation, all frozen digests, authorization, observation/snapshot replay hashes, direct-EVD/no-Gram enforcement, Scheme G safeguard fallback membership, exact profile-pass counts, raw metric recomputation, deterministic bootstrap replay, and matched timing identity. It writes failure evidence before stopping if any audit check fails.

The report generator creates `research/98_schemeG_R41_independent_final_results.md`, `research/99_schemeG_R41_independent_final_audit.md`, and `research/100_schemeG_final_paper_results.md`. It uses the predeclared interpretation text verbatim and does not edit either paper.
