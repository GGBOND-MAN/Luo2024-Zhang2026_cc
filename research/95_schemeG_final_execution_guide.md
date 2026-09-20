# Scheme G R41 Final Execution Guide

Date: 2026-09-14  
Current state: **pre-authorization; do not run a final shard**

## 1. Locked artifacts

The protocol package is stored under:

`matlab/results/full_spectrum/round41_schemeG_independent_final_protocol_v1/`

It contains `protocol.mat`, `design.csv`, the historical exclusion audit, and source manifests. Do not edit, regenerate, or overwrite this directory. The future execution directory is:

`matlab/results/full_spectrum/round41_schemeG_independent_final_v1/`

It must not exist before first execution on either server.

## 2. Required pre-authorization check

From the MATLAB project directory, add `experiments` to the path and run:

```matlab
preflight_round41_schemeG_final("pre-authorization")
```

Expected state: no authorization file, no final result directory, all tests pass, Code Analyzer is empty, unauthorized execution is rejected, checkpoint/resume identity passes, and final trials remain zero.

## 3. Future explicit authorization

Authorization must come from a new explicit user instruction. Only then run exactly:

```matlab
authorize_round41_schemeG_final( ...
    "I_EXPLICITLY_AUTHORIZE_R41_SCHEME_G_FINAL_1400")
```

Do not call the authorization function during preparation, tests, or routine preflight. After authorization, copy the unchanged source tree, protocol package, and authorization file to both clean servers. Run this before the first shard on each server:

```matlab
preflight_round41_schemeG_final("authorized-execution")
```

If a server already has the future final result directory, stop. Inspect and resolve it manually; do not silently continue, delete rows, or create a new design.

## 4. Two-server execution

Server 1, clean output root:

```matlab
run_round41_schemeG_final_shard(1, ...
    NumWorkers=32, BatchSize=8, PoolType="Threads")
```

Server 2, separate clean output root:

```matlab
run_round41_schemeG_final_shard(2, ...
    NumWorkers=32, BatchSize=8, PoolType="Threads")
```

Server 1 contains positions 1-100 and 700 rows. Server 2 contains positions 101-200 and 700 rows. The runner checks all frozen identities before `prepareScan`, observation replay, pool creation, or estimation.

For an interrupted, incomplete shard only, resume with the same source and authorization:

```matlab
run_round41_schemeG_final_shard(1, Resume=true, ...
    NumWorkers=32, BatchSize=8, PoolType="Threads")
```

Resume executes only empty checkpoint cells. Existing successful or failed rows are retained. A `COMPLETE.mat` shard cannot be resumed or rerun.

## 5. Aggregation

Copy the two complete shard directories into one unchanged aggregation workspace under the future execution directory. Then run:

```matlab
aggregate_round41_schemeG_final
```

Aggregation requires both exact shards, 1400 nonmissing rows, and zero failed trials. Any failure stops primary inference. A successful aggregate writes an identity with `authorized=true`, `trialsExecuted=1400`, algorithm digest, design hash, statistics version/hash, dependency/source digests, authorization digest, and timestamp.

## 6. Matched complexity timing

Only after the complete aggregate, run on one designated machine:

```matlab
run_round41_schemeG_matched_timing
```

This replays 20 already frozen final-design rows only for sequential matched timing; it creates no new users and is not counted as another performance trial set. Report its wall-time ratios and operation counts. Do not use shard throughput for the runtime claim.

## 7. Prohibited actions

Do not stop for significance, add users, drop tails, rerun unfavorable or failed seeds, alter Scheme G or either baseline, change the bootstrap/families, regenerate the design, or select `G_fixed` after seeing final data. The one authorized 1400-row execution is final.
