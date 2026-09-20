# Scheme A：MUSIC angle continuous local refinement

日期：2026-09-12  
协议：`research/69_angle_improvement_common_protocol.md`  
实现版本：`R35-schemeA-continuous-MUSIC-angle-v1`  
数据角色：已有 60 个 development users，`-10/0/20 dB` 各 20 个  
结论：**Scheme A 未通过公共工程 Gate，停止 A，不进入 600 calibration。B/D 未运行。**

## 1. 主要结论

当前 `P_A` 的角度误差不能总体解释为最终离散网格量化限制。连续 refinement 在 20 dB 明显降低 angle RMSE，但在 -10 dB 和 0 dB 反而增大 angle MSE，equal-SNR aggregate angle MSE 增加 3.276%。

该变化几乎完全是 `P_A` 与 `C_enhanced` 共有的 grid quantization correction：两者在 60/60 个旧用户上的冻结 grid angle 完全相同；分别固定 `r_F` 和 `r_C` 连续优化后，A/C continuous angle 的最大差仅 `3.619e-7 deg`，两组 displacement 的相关系数为 `0.9999995`。

MUSIC score gain 不等于 truth error gain。A 的 60 个 continuous 解全部提高了观测 MUSIC score，但只有 32 个用户降低 truth squared angle error，28 个用户恶化。特别在 0 dB，只有 6/20 改善、14/20 恶化。

## 2. 冻结实现

每个用户分别执行完整冻结入口：

- `r34.estimate(...,"P_A")`：L06 front、q-only、direct covariance EVD、`UseGram=false`、`K=2047/L=160/P=97`、`41/31/21` 一维 angle grid 和冻结 profile；
- `r34.estimate(...,"C_enhanced")`：相同冻结 front、carrier、subspace 与 compensation，执行冻结二维 MUSIC；
- A refinement：取 P_A 最终实际 21 点 angle grid 的最佳点及其左右相邻点，固定 `r_F` 和原 state，直接对同一 `jad.localMusicLogScore` 调用 `fminbnd`；
- C diagnostic：取 C 最终 grid angle 的左右相邻点，固定 `r_C`，使用相同 refinement；
- A 的 `theta_cont` 产生后，始终重新调用冻结 `r33.profileAtAngle`，保持 `+/-2 m`、`lambda=1` 和全部 profile 参数不变。

优化器固定为 `TolX=1e-10 deg`、最多 100 次 function evaluation/iteration。原 grid optimum 始终保留为候选；若无双侧相邻点则不扩大 bracket，直接保留 grid 解。本轮 60/60 均有合法双侧 bracket，60/60 收敛并选择 continuous 候选。

最终 bracket 宽度全部为 `0.0005333333 deg`，即左右相邻点之间的宽度；A 平均绝对 displacement 为 `7.907e-5 deg`，最大为 `1.308e-4 deg`。平均新增 MUSIC function evaluations 为 `5.967`。全部 score gain 为正，最小 final score gain 为 `7.376e-9`，没有发生低于 grid best 的 retention 违规。

## 3. Angle 结果

| SNR (dB) | P_A RMSE (deg) | A_cont RMSE | RMSE变化 | A/P_A MSE ratio | win/tie/loss |
|---:|---:|---:|---:|---:|---:|
| -10 | 0.001059967 | 0.001070366 | +0.9811% | 1.019719 | 12/0/8 |
| 0 | 0.000469182 | 0.000499070 | +6.3702% | 1.131462 | 6/0/14 |
| 20 | 0.000091540 | 0.000039714 | -56.6159% | 0.188218 | 14/0/6 |
| equal-SNR aggregate | 0.000671327 | 0.000682235 | +1.6247% | 1.032759 | 32/0/28 |

表中 aggregate RMSE 是 equal-SNR aggregate MSE 的平方根。A_cont 在 20 dB 的结果支持高 SNR 下存在明显 grid quantization；-10/0 dB 的退化说明有限噪声下连续提高样本 MUSIC score 会进一步追随随机谱峰偏移，不能把离散误差视为当前角度误差的主要统一来源。

角度绝对误差 median/P95：

| SNR (dB) | P_A median | A_cont median | P_A P95 | A_cont P95 |
|---:|---:|---:|---:|---:|
| -10 | 0.000671614 | 0.000594394 | 0.002401552 | 0.002437442 |
| 0 | 0.000259542 | 0.000316455 | 0.001154238 | 0.001167543 |
| 20 | 0.000074167 | 0.000032521 | 0.000151053 | 0.000074659 |

## 4. 公平 C diagnostic

`C_enhanced` 的冻结 grid angle 与 P_A 在 60/60 用户上完全相同。C_cont 相对 C_enhanced 的 angle RMSE 变化为：

- -10 dB：`+0.9811%`，MSE ratio `1.019718`；
- 0 dB：`+6.3736%`，MSE ratio `1.131534`；
- 20 dB：`-56.6128%`，MSE ratio `0.188245`；
- equal-SNR：RMSE `+1.6253%`，MSE ratio `1.032770`。

A_cont 对 C_cont 的 equal-SNR MSE ratio 为 `0.9999888`，RMSE差仅 `0.000562%`。逐用户 continuous angle 平均绝对差为 `5.420e-8 deg`，最大为 `3.619e-7 deg`。因此本轮没有证据表明 continuous correction 是 P_A 特有收益；它是双方共有的最终 angle grid correction。

## 5. Score gain 与 truth gain

| SNR (dB) | mean score gain | truth improve/tie/worse | score-truth correlation |
|---:|---:|---:|---:|
| -10 | 6.484e-7 | 12/0/8 | -0.4053 |
| 0 | 5.332e-6 | 6/0/14 | -0.0596 |
| 20 | 5.266e-4 | 14/0/6 | +0.4715 |
| 全部 | 1.775e-4 | 32/0/28 | +0.1060 |

score gain 在全部用户上为正，但总体 truth squared-error reduction 的均值为 `-1.476e-8 deg^2`。观测目标提高只保证对当前样本 MUSIC statistic 更优，不保证更接近真实 angle。

## 6. Range 与 position

A_cont 使用新 angle 重新运行冻结 conditional profile 后：

| SNR (dB) | P_A range RMSE (m) | A_cont range RMSE | 变化 | P_A position RMSE (m) | A_cont position RMSE | 变化 |
|---:|---:|---:|---:|---:|---:|---:|
| -10 | 0.1272420 | 0.1272487 | +0.00522% | 0.1272436 | 0.1272503 | +0.00526% |
| 0 | 0.00998669 | 0.00998555 | -0.01138% | 0.00998991 | 0.00998932 | -0.00592% |
| 20 | 0.00136035 | 0.00135812 | -0.16425% | 0.00136122 | 0.00135834 | -0.21129% |

三个 SNR 的 range MSE ratios 为 `1.000104/0.999772/0.996718`，全部通过 `<=1.02`。连续角度对 range/position 的影响很小，没有抵消 -10/0 dB 的 angle Gate 失败。

## 7. Runtime 与 evaluation counts

- P_A 平均完整在线时间：`18.0534 s/user`；
- A_cont 重构后的完整在线时间：`17.8388 s/user`；
- 配对均值变化：`-0.2147 s`，即 `-1.189%`；
- C_enhanced 平均完整在线时间：`34.9416 s/user`；
- A_cont/C_enhanced runtime ratio：`0.510531`，通过 runtime Gate；
- A continuous refinement 本身平均增加 `0.11234 s/user`，约为 P_A 完整时间的 `0.622%`；
- C diagnostic refinement 平均为 `0.10569 s/user`。

A_cont 完整时间略低于本次 P_A 计时，不表示 continuous refinement 免费。其原因是新 angle 上重新运行的冻结 profile 本次平均耗时 `1.0966 s`，低于原 P_A profile 的推算均值 `1.4236 s`，该 profile 运行波动超过 `0.1123 s` refinement 增量。工程 Gate 使用实际完整入口时间，机制成本应同时报告 refinement 的独立增量。

P_A 原 angle MUSIC 固定为 93 次评分；A_cont 平均为 `98.967` 次，即增加 `5.967` 次。response evaluation count 基本不变，三个 SNR 的均值变化分别为 `+0.4/0/0`，差异只来自冻结 profile 的实际优化调用数。C 从 3083 次 MUSIC 评分增加到平均 `3088.967` 次。

## 8. 公共工程 Gate

| Gate | 观测 ratio | 上限 | 结果 |
|:---|---:|---:|:---|
| -10 dB angle MSE | 1.019719 | 1.01 | FAIL |
| 0 dB angle MSE | 1.131462 | 1.01 | FAIL |
| 20 dB angle MSE | 0.188218 | 1.01 | PASS |
| equal-SNR aggregate angle MSE | 1.032759 | 0.98 | FAIL |
| -10/0/20 dB range MSE | 1.000104/0.999772/0.996718 | 1.02 | PASS |
| mean runtime vs C_enhanced | 0.510531 | 1.00 | PASS |

Scheme A 因两个 per-SNR angle Gate 和 aggregate angle Gate 失败，最终判定为 **FAIL**。按公共协议立即停止 A：不扩大 bracket、不加密网格、不修改 fminbnd 参数、不增加 gating、不追加开发用户、不进入已有 600 calibration。

## 9. 执行与审计

- development rows：60/60；failed trial：0；
- refinement convergence：A 60/60，C diagnostic 60/60；
- R34 frozen source digest：`2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`；
- calibration users executed：0；R34 final trials reused/executed：0；
- Scheme B/D 文件与执行数：0；
- MATLAB Code Analyzer：新增 Scheme A 文件 0 issues；
- tests：`round35SchemeAContinuousMusicTest` 4/4，`round35AngleImprovementIdentityTest` 4/4。

60 用户估计完成后的首次汇总暴露两个纯表格问题：aggregate 标量维度和方括号内减法解析。两项均在保留 60/60 checkpoint 的情况下修复，并通过 summary-only resume 重新生成表格；没有重跑用户或改变任何估计结果。

## 10. 结果文件

结果目录：`matlab/results/full_spectrum/round35_schemeA_continuous_angle_v1/`

- `per_user_outputs.csv`：theta grid/continuous、bracket、score、displacement、function evaluations、convergence、range、runtime 和 counts；
- `method_summary.csv`：统一 angle/range/position/runtime/count 指标；
- `paired_comparisons.csv`：A/P_A、C_cont/C_enhanced、A_cont/C_cont 配对结果；
- `refinement_diagnostics.csv`：score gain、truth gain、相关性和 displacement；
- `engineering_gate.csv`：冻结公共 Gate；
- `result.mat`：逐用户完整轻量结果、实际最终 angle grids、profile 与身份；
- `source_hashes.csv`、`failures.csv`、`checkpoint.mat`：源码、失败和恢复审计。
