# R36 Scheme E: frozen calibration-600 result

Date: 2026-09-12  
Protocol: `research/76_schemeE_calibration600_protocol.md`  
Implementation: `R36-schemeE-range-orthogonal-one-step-v1`  
Evidence role: pre-final calibration; not independent final validation  
Decision: **PASS on both the frozen all-600 and holdout-540 engineering gates. Stop before independent final validation.**

> Calibration study – not R34 final confirmation

## 1. Scope and identity

The exact development-passed Scheme E estimator was replayed on the existing
`calibration600` design. No estimator, bracket, range profile, baseline, gate,
user, seed or SNR was changed after the 60-user development PASS.

- existing calibration users executed: 600, with 200 at each of -10/0/20 dB;
- fixed development overlap: 60, with 20 per SNR;
- fixed non-development holdout: 540, with 180 per SNR;
- failed rows: 0;
- new users generated: 0;
- R34 final trials read or executed: 0;
- R35 Scheme A/B/D executions: 0;
- other R36 schemes executed: 0.

Frozen identities:

- Scheme E algorithm digest: `27879e532e1ffefa1223a7a2ed56a6845ade09ed97e98f58ed56851436ba5908`;
- calibration data digest: `39538d66a6724e198d9c569c2f9e24b9185c4d3d979bc4f224724fbf5d50dcc0`;
- frozen R34 source digest: `2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`;
- R35 read-only digest: `196bfb59ad1a833ad21542114536c743e0b9dd725982a4d02ea2b0bf9591b4e9`;
- calibration estimation-source digest: `791753137394357a4eca0abbb14acb921815415404eed0278df37a436fe4d8bc`.

The 60 overlapping rows exactly reproduce the frozen development estimates and
diagnostics: zero field mismatches and maximum numerical difference zero. This
checks deterministic replay and excludes a calibration-specific implementation
change.

## 2. Engineering decision

| Population | Gate | Observed | Limit | Decision |
|:--|:--|--:|--:|:--|
| all 600 | -10 dB angle MSE ratio | 0.912049 | 1.01 | PASS |
| all 600 | 0 dB angle MSE ratio | 0.830739 | 1.01 | PASS |
| all 600 | 20 dB angle MSE ratio | 0.201357 | 1.01 | PASS |
| all 600 | equal-SNR angle MSE ratio | 0.901640 | 0.98 | PASS |
| all 600 | -10/0/20 dB range MSE ratio | 1.001446 / 0.999672 / 0.995740 | 1.02 | PASS |
| all 600 | runtime / C_enhanced | 0.467780 | 1.00 | PASS |
| holdout 540 | -10 dB angle MSE ratio | 0.907421 | 1.01 | PASS |
| holdout 540 | 0 dB angle MSE ratio | 0.838713 | 1.01 | PASS |
| holdout 540 | 20 dB angle MSE ratio | 0.204874 | 1.01 | PASS |
| holdout 540 | equal-SNR angle MSE ratio | 0.898649 | 0.98 | PASS |
| holdout 540 | -10/0/20 dB range MSE ratio | 1.001504 / 0.999648 / 0.995769 | 1.02 | PASS |
| holdout 540 | runtime / C_enhanced | 0.468337 | 1.00 | PASS |

Both populations pass every predeclared gate. The holdout result is slightly
stronger than the all-600 result, so the decision is not driven by reusing the
60 development rows.

## 3. Angle performance

### All 600 calibration rows

| SNR | P_A RMSE (deg) | Scheme E RMSE (deg) | RMSE improvement | MSE ratio | win/tie/loss |
|---:|---:|---:|---:|---:|---:|
| -10 dB | 0.001366591 | 0.001305112 | 4.4987% | 0.912049 | 120/0/80 |
| 0 dB | 0.000436379 | 0.000397737 | 8.8551% | 0.830739 | 104/0/96 |
| 20 dB | 0.000092094 | 0.000041325 | 55.1272% | 0.201357 | 157/0/43 |
| equal-SNR | 0.000829956 | 0.000788082 | 5.0453% | 0.901640 | 381/0/219 |

Equal-SNR aggregate angle MSE improves by `9.8360%`.

### Fixed holdout 540 rows

| SNR | P_A RMSE (deg) | Scheme E RMSE (deg) | RMSE improvement | MSE ratio | win/tie/loss |
|---:|---:|---:|---:|---:|---:|
| -10 dB | 0.001396511 | 0.001330297 | 4.7414% | 0.907421 | 112/0/68 |
| 0 dB | 0.000432581 | 0.000396163 | 8.4187% | 0.838713 | 94/0/86 |
| 20 dB | 0.000092155 | 0.000041712 | 54.7370% | 0.204874 | 141/0/39 |
| equal-SNR | 0.000845746 | 0.000801743 | 5.2029% | 0.898649 | 347/0/193 |

Equal-SNR aggregate angle MSE improves by `10.1351%`.

Absolute-error distribution also improves in the fixed holdout:

| SNR | P_A median | E median | P_A P95 | E P95 |
|---:|---:|---:|---:|---:|
| -10 dB | 0.000984677 | 0.000937323 | 0.002625034 | 0.002471166 |
| 0 dB | 0.000280852 | 0.000270614 | 0.000829210 | 0.000800966 |
| 20 dB | 0.000076243 | 0.000028450 | 0.000174481 | 0.000076874 |

The largest gain remains at 20 dB, where the P_A local discretization and
first-order angle-range coupling become visible after random error is small.
Unlike Scheme A continuous MUSIC maximization, Scheme E does not merely move to
a continuous maximum of the same one-dimensional score. It removes the range
nuisance direction from the local full-carrier residual update before changing
angle.

## 4. Objective gain versus truth gain

The actual raw-MUSIC residual cost decreases for all `600/600` rows and all
`540/540` holdout rows. Truth squared-angle error improves for `381/600`
(`63.5%`) and `347/540` (`64.26%`) respectively.

| Population | truth win/tie/loss | cost-truth correlation |
|:--|--:|--:|
| all 600 | 381/0/219 | 0.2989 |
| holdout 540 | 347/0/193 | 0.3028 |

Therefore objective reduction is directionally useful in aggregate but is not
a per-user correctness certificate. These results do not justify H/P gating,
an adaptive selector or post-hoc rejection of adverse rows.

## 5. One-step and bracket diagnostics

All information systems produce valid updates. The mean absolute angle movement
is `1.4797e-4 deg` for all 600 and `1.4830e-4 deg` for holdout 540; the maximum
is the frozen bracket boundary `2.6667e-4 deg`.

| SNR | all-600 clipped | holdout-540 clipped | all-600 mean displacement |
|---:|---:|---:|---:|
| -10 dB | 146/200 | 133/180 | 2.3070e-4 deg |
| 0 dB | 39/200 | 34/180 | 1.4249e-4 deg |
| 20 dB | 0/200 | 0/180 | 7.0736e-5 deg |

Low-SNR clipping is common, but the frozen bracket still passes the angle and
range gates. It must not be expanded or tuned from this calibration result.

The diagnostic range displacement remains negligible: all-600 mean
`6.10e-8 m`, maximum `9.11e-7 m`. The maximum absolute angle-range tangent
coupling coefficient is `0.03030`.

## 6. Range and position preservation

The Scheme E angle reruns the unchanged +/-2 m conditional range profile for
every row.

| Population | SNR | range MSE ratio | position RMSE change |
|:--|---:|---:|---:|
| all 600 | -10 dB | 1.001446 | +0.0722% |
| all 600 | 0 dB | 0.999672 | -0.0193% |
| all 600 | 20 dB | 0.995740 | -0.2926% |
| holdout 540 | -10 dB | 1.001504 | +0.0751% |
| holdout 540 | 0 dB | 0.999648 | -0.0203% |
| holdout 540 | 20 dB | 0.995769 | -0.2952% |

Across all SNR rows, position RMSE changes from `0.129384 m` to `0.129477 m`
for all 600 (`+0.0718%`) and from `0.134153 m` to `0.134253 m` for holdout 540
(`+0.0747%`). This small aggregate increase is caused by the -10 dB range
profile variation and is far below the frozen 2% per-SNR range-MSE allowance.

The correct conclusion is that distance and position are practically preserved,
not that every individual range estimate improves.

## 7. Runtime and evaluation counts

The run used MATLAB R2024b with one 8-worker thread pool and batch size 8.

| Population | mean P_A runtime | mean E runtime | mean C_enhanced runtime | E/P_A | E/C_enhanced |
|:--|---:|---:|---:|---:|---:|
| all 600 | 24.3835 s | 23.9741 s | 51.2508 s | 0.98321 | 0.46778 |
| holdout 540 | 24.4093 s | 24.0000 s | 51.2451 s | 0.98323 | 0.46834 |

The analytic one-step calculation averages `0.0894 s/user`; the refreshed
profile averages `1.6834 s/user`. Complete E runtime is about `1.68%` lower
than paired P_A in this execution because the newly evaluated frozen profile is
slightly cheaper. This is timing variation, not a claim that refinement has
negative computational cost.

P_A uses 93 MUSIC evaluations per row and Scheme E uses 95. Both use 2047
direct EVDs. C_enhanced uses 3083 MUSIC evaluations. Mean response counts for
Scheme E remain effectively identical to P_A and differ only through the
actual frozen range-profile evaluation count.

## 8. Interpretation

The calibration evidence supports the following mechanism:

1. P_A is not mainly limited by the final one-dimensional grid quantization,
   consistent with the failed Scheme A result.
2. A small local correction becomes useful when the angle derivative is made
   first-order orthogonal to the range nuisance direction.
3. The effect is strongest at high SNR, where deterministic local bias dominates
   measurement noise, but remains beneficial at -10 and 0 dB under the frozen
   per-SNR MSE gate.
4. Re-running the frozen conditional range profile prevents the angle update
   from trading angle gain for a material distance loss.

Scheme E is therefore the selected fixed angle-improvement candidate after
development and calibration. It remains a calibration-selected method, not an
independently validated final method.

## 9. Stop rule and delivered artifacts

Per the frozen protocol, this run stops after the 600/540 calibration decision.
PASS does not authorize R34 final reuse or any automatic final experiment. A
future independent validation requires a separately frozen protocol and
explicit authorization, with no Scheme E tuning from these calibration results.

Result directory:

`matlab/results/full_spectrum/round36_schemeE_calibration600_v1/`

Primary artifacts:

- `result.mat` SHA-256: `f998fc2258210c13ef98345ea04b4637c7d93b762795fc575c8da92a200bb446`;
- `per_user_outputs.csv` SHA-256: `1eadbfe162320d548571fce32a7a1c513d173c47aeb4029111866c0ba4451e4e`;
- `engineering_gate.csv` SHA-256: `b9153561b9384e8218eabebe997ab804f5daf8a9685bd60605a7c622d4328ad6`;
- `calibration_decision.csv` SHA-256: `9db71ce3e2dd43d066644c3bb1ca7a961385f922aa5d96faeb38c490e879a168`;
- all-600, holdout-540 and overlap-60 method/comparison/diagnostic CSVs;
- source and R35 read-only hash manifests;
- five rendered calibration figures;
- resumable `checkpoint.mat`.
