# Scheme B：conditional full-spectrum angular micro-refinement

日期：2026-09-12  
公共协议：`research/69_angle_improvement_common_protocol.md`  
实现版本：`R35-schemeB-spectral-angle-v1`  
数据角色：已有 60 个 development users，`-10/0/20 dB` 各 20 个  
结论：**Scheme B 未通过 primary angle Gate，停止 B；未执行 range refresh、600 calibration、Scheme D 或任何组合方案。**

## 1. 冻结前提

Scheme A 已完成并冻结为 FAIL，本轮没有修改或调用其 estimator，也没有将 `theta_A_cont` 作为输入。只读比较使用冻结的 `per_user_outputs.csv`，SHA-256 为：

`1f1f950e96e8d61ebe7083c0fd1b49fe0c25763951c48327084341522f16e8ff`

Scheme A 保留结论为：-10/0/20 dB angle RMSE 变化 `+0.981%/+6.370%/-56.616%`；equal-SNR angle MSE ratio `1.032759`；MUSIC score 60/60 提高但 truth error 仅 32 改善、28 恶化；A_cont 与 C_cont 几乎相同，因此它是双方共有的 grid correction。

Scheme B 的起点始终为原冻结 `P_A` 41/31/21 grid 输出 `theta_A` 和冻结 profile 输出 `r_P`，不是 Scheme A 连续结果。`P_A`、`C_enhanced`、R32/R33/R34 源码与 R34 final 数据均未修改或复用。

## 2. Primary 实现

对每个旧用户：

1. 独立执行冻结 `r34.estimate(...,"P_A")` 和 `r34.estimate(...,"C_enhanced")`；
2. 从 P_A 最终实际 21 点 MUSIC grid 读取最佳点及左右相邻点；若最佳点在可行角域边缘，则只使用实际单侧相邻区间；
3. 固定 `r=r_P`，复用 `r33.prepareResponseContext`、`r33.exactSpectralResponse`、`r33.profileScore` 和 `r33.fixedAngleProfileLogScore`；
4. 在该微 bracket 内使用 `fminbnd` 最大化现有 q-only、exact spherical、common-complex-gain-eliminated normalized concentrated log score；
5. 原 `theta_A` 始终保留为候选，最终 score 不得低于 `theta_A` score 超过 `1e-12`；
6. Primary 输出严格为 `(theta_B,r_P)`，没有重新估计 range。

优化器固定为 `TolX=1e-10 deg`、最多 100 次 function evaluation/iteration。没有全角窗搜索、多起点、truth bracket、SNR 调参、频率选择、新权重或新 beta 模型。

C diagnostic 从冻结 `(theta_C,r_C)` 出发，固定 `r_C`，使用相同 full-spectrum objective 和相同 bracket 规则，输出命名为 `C_FS_angle_control`。它不替换 C_enhanced。

## 3. Primary angle 结果

| SNR (dB) | P_A RMSE (deg) | B RMSE (deg) | RMSE变化 | B/P_A MSE ratio | win/tie/loss |
|---:|---:|---:|---:|---:|---:|
| -10 | 0.001059967 | 0.001114000 | +5.0976% | 1.104551 | 9/0/11 |
| 0 | 0.000469182 | 0.000537124 | +14.4809% | 1.310588 | 8/0/12 |
| 20 | 0.000091540 | 0.000264428 | +188.8669% | 8.344410 | 3/0/17 |
| equal-SNR aggregate | 0.000671327 | 0.000730164 | +8.7643% | 1.182968 | 20/0/40 |

三个 SNR 均超过 `MSE_B/MSE_P_A <= 1.01`，equal-SNR aggregate 也未达到 `<=0.98`。B 在高 SNR 的退化最强，与“完整相干频谱提供稳健补充角度信息”的候选结论相反。

绝对角度误差分布：

| SNR (dB) | 方法 | median (deg) | P90 (deg) | P95 (deg) |
|---:|:---|---:|---:|---:|
| -10 | P_A | 0.000671614 | 0.001745259 | 0.002401552 |
| -10 | B | 0.000660173 | 0.001744817 | 0.002458028 |
| 0 | P_A | 0.000259542 | 0.000866748 | 0.001154238 |
| 0 | B | 0.000241946 | 0.000866829 | 0.001233772 |
| 20 | P_A | 0.000074167 | 0.000145446 | 0.000151053 |
| 20 | B | 0.000249120 | 0.000393627 | 0.000403362 |

低 SNR 的 median 可略降，但 MSE/P95 变差；不能用 median 改善覆盖主要 Gate 失败。

## 4. Score gain 与 truth gain

60/60 用户的 full-spectrum score 均提高，最小保留后 score gain 为 `3.589e-15`；60/60 optimizer 收敛并选择 spectral continuous 候选。然而 truth squared angle error 只有 20 个改善，40 个恶化。

| SNR (dB) | mean spectral score gain | truth improve/tie/worse | corr(score gain, truth gain) | corr(|displacement|, truth gain) |
|---:|---:|---:|---:|---:|
| -10 | 7.547e-5 | 9/0/11 | +0.2142 | +0.1281 |
| 0 | 2.192e-5 | 8/0/12 | -0.0416 | +0.1284 |
| 20 | 1.799e-6 | 3/0/17 | +0.1335 | -0.3992 |
| 全部 | 3.306e-5 | 20/0/40 | +0.1043 | -0.0423 |

全部用户的平均 truth squared-error reduction 为 `-8.246e-8 deg^2`，即总体恶化。结果再次验证 objective gain 不等于 truth-error gain；score 60/60 上升不能构成 B 成功证据。

## 5. Bracket 与 displacement

Primary B 的 angle 输出 60/60 发生变化。平均绝对 displacement 为：

- -10 dB：`2.66090e-4 deg`；
- 0 dB：`2.66049e-4 deg`；
- 20 dB：`2.39175e-4 deg`；
- 全部：`2.57105e-4 deg`，最大 `2.66653e-4 deg`。

原 MUSIC grid 的最终相邻点 bracket 宽度约为 `5.33333e-4 deg`，因此许多位移接近半个 bracket。原 `theta_A` 没有可行角域 boundary hit；按 `max(10 TolX,0.1% bracket width)` 判定，B 有 20/60 个解命中微 bracket 边缘，-10/0/20 dB 分别为 7/8/5。这表明现有 full-spectrum score 经常沿局部 bracket 继续单调推动 angle，而不是稳定地产生围绕 `theta_A` 的小型无偏修正。协议禁止据此扩大 bracket。

## 6. 与冻结 Scheme A 的只读比较

| SNR (dB) | displacement correlation B/A | same direction | mean |B|/mean |A| | A低SNR恶化数 | B反向改善数 |
|---:|---:|---:|---:|---:|---:|
| -10 | -0.1932 | 45% | 3.073 | 8 | 4 |
| 0 | +0.0467 | 60% | 3.549 | 14 | 4 |
| 20 | -0.0113 | 55% | 3.161 | 0 | 0 |
| 全部 | -0.0201 | 53.3% | 3.251 | 22 | 8 |

B 与 A displacement 几乎不相关，说明 Scheme B 确实改变了信息来源，并非简单重复 MUSIC continuous correction。低 SNR 下，B 能在 22 个 A 恶化用户中的 8 个反向改善，但同时造成更多其他用户恶化，无法形成总体稳健收益。准确结论是：**B 与 A 不同，但当前证据不支持其信息是有益的 complementary information。**

## 7. C full-spectrum diagnostic

C_FS_angle_control 相对 C_enhanced 的 MSE ratio 为：

- -10 dB：`1.109221`；
- 0 dB：`1.310535`；
- 20 dB：`7.500395`；
- equal-SNR：`1.181609`。

它与 B 呈现相同的跨 SNR 退化。B_primary 与 C_FS 的 equal-SNR MSE ratio 为 `1.001150`；60 个用户中 46 个 angle 完全相同，B/C_FS 的 win/tie/loss 为 `4/46/10`。少数用户因固定 `r_P` 与 `r_C` 不同而产生差异，最大 `|theta_B-theta_C_FS|` 为 `5.3265e-4 deg`。

因此该 full-spectrum 后处理不是 P_A 特有改进；加在 Zhang-style 输出后也同样失败。

## 8. Range 与 position

Primary B 固定 `r_P`，所以 range MSE/RMSE 与 P_A 严格相同，不是新的 range 估计结果：

| SNR (dB) | P_A/B range RMSE (m) | P_A position RMSE (m) | B position RMSE (m) |
|---:|---:|---:|---:|
| -10 | 0.127242018 | 0.127243596 | 0.127243761 |
| 0 | 0.009986689 | 0.009989907 | 0.009991502 |
| 20 | 0.001360354 | 0.001361216 | 0.001369926 |

仅替换 angle 已使 position RMSE 在三档均略增，20 dB 最明显。由于 primary angle Gate 失败，程序按预声明门禁没有执行 `r_B_refresh`，结果目录中不存在任何 `range_refresh*` 文件。不能报告 secondary range Gate，也不能进行 `theta -> r -> theta` 循环。

## 9. Runtime、response 与 memory

本轮同一 session 的配对完整时间：

- P_A：`17.9179 s/user`；
- B_primary reconstructed runtime：`18.0267 s/user`；
- B 相对 P_A：`+0.10875 s/user`，增加 `0.6070%`；
- C_enhanced：`34.4778 s/user`；
- `T_B/T_C_enhanced=0.522848`，通过 runtime Gate。

B 的额外时间由 response context 构建均值 `0.000895 s` 和 spectral refinement 均值 `0.107860 s` 组成。额外 exact spectral response evaluations 平均 `15.033`，范围 `7–23`；它们计入 response count，不计入 MUSIC evaluation count，因此 B 仍保留原 P_A 的 93 次 MUSIC grid evaluations。

平均保存的 response-context 工作集为 `8,443,512 bytes`，约 `8.05 MiB`。这只是 MATLAB struct 的 readily available 内存记录，不是峰值进程内存。

## 10. Frozen engineering Gate

| Gate | observed ratio | limit | result |
|:---|---:|---:|:---|
| -10 dB angle MSE | 1.104551 | 1.01 | FAIL |
| 0 dB angle MSE | 1.310588 | 1.01 | FAIL |
| 20 dB angle MSE | 8.344410 | 1.01 | FAIL |
| equal-SNR aggregate angle MSE | 1.182968 | 0.98 | FAIL |
| mean runtime vs C_enhanced | 0.522848 | 1.00 | PASS |

Primary B 未同时满足 Gate 1 和 Gate 2，最终判定为 **FAIL**。按公共协议不扩大 bracket、不增加搜索点或迭代、不增加 SNR gate、B/A selector、score 修改或参数放宽。

## 11. 理论结论与边界

本轮支持的结论为：

> Under the current conditional model, local coherent-spectrum angular refinement did not provide a robust cross-SNR improvement beyond the frozen MUSIC angle estimate.

更具体地说，完整相干频谱确实给出了与 MUSIC continuous correction 不同的局部方向，但在固定 `r_P` 的 conditional score 上，它系统性地把许多解推向微 bracket 边缘，且在三档 SNR 均增加 angle MSE。当前不能称其为“complementary angular information”，只能称为不同且未校准成功的 conditional information source。

不得据此宣称 full spectrum 普遍差于或优于 MUSIC、angle/range 精确解耦、全局最优或 R34 final 已验证 Scheme B。本轮只是 60-user development evidence。

## 12. 执行、测试与交付

- primary rows：60/60；failed trial：0；
- B/C_FS convergence：60/60；
- range refresh：0；calibration users：0；R34 final trials：0；
- Scheme A estimator calls：0；Scheme D files/runs：0；A+B combinations：0；
- MATLAB Code Analyzer：新增 Scheme B 文件 0 issues；
- tests：`round35SchemeBSpectralAngleTest` 5/5，`round35AngleImprovementIdentityTest` 4/4；
- 5 张开发图已逐张检查，均标注 `Development study - not R34 final confirmation`。

结果目录：`matlab/results/full_spectrum/round35_schemeB_spectral_angle_v1/`

- `per_user_outputs.csv`
- `method_summary.csv`
- `paired_comparisons.csv`
- `refinement_diagnostics.csv`
- `schemeA_readonly_comparison.csv`
- `engineering_gate.csv`
- `failures.csv`
- `source_hashes.csv`
- `checkpoint.mat`
- `result.mat`
- `figures/B_F1...B_F5...png` 与 `figure_manifest.csv`

Scheme B 到此停止。即使 runtime Gate 通过，也不能覆盖 angle Gate 的全面失败。
