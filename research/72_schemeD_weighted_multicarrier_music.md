# Scheme D：all-carrier information-weighted multicarrier MUSIC

日期：2026-09-12  
公共协议：`research/69_angle_improvement_common_protocol.md`  
实现版本：`R35-schemeD-weighted-all-carrier-MUSIC-v1`  
数据角色：已有 60 个 development users，`-10/0/20 dB` 各 20 个  
结论：**D1、D2、D3 均未通过冻结工程 Gate。Scheme D 停止，不进入 600 calibration，不新增 D4。**

> Development study – not R34 final confirmation

## 1. 执行边界

本轮只执行 Scheme D。Scheme A/B 的源码、checkpoint、结果与报告保持冻结，未调用其 estimator，也未组合任何方案。

系统和算法身份保持：`N=256`、`M=2048`、`K=2047`、`L=160`、`P=97`、L06 front、q-only、direct covariance EVD、`UseGram=false`、冻结 `r=r_F`、三级 `41/31/21` 离散角度网格、当前角窗、冻结 compensation/subspace、`+/-2 m` conditional range profile、`lambda=1`。

执行数：development 60；calibration 0；R34 final reuse/execution 0；新用户 0；A/B execution 0。

## 2. 实现

对冻结 state 的每个 carrier 计算原单载波 log-MUSIC statistic：

`ell_m(theta) = -log(max(1-|u_m^H a_m(theta,r_F)|^2, eps))`。

四个融合规则均使用全部 2047 carriers：

- `D0_uniform`：`w_m=1/K`；
- `D1_gap`：直接复用同次 frozen direct EVD 已保存的 `rho_gap=max(lambda1-lambda2,0)/max(lambda1,eps)`，只做和为 1 的归一化；
- `D2_information`：在 frozen `(theta_F,r_F)` 使用解析 `da/dtheta`，按 radian 单位计算 `rho_info=||(I-aa^H/(a^Ha))a_theta||^2`，只做和为 1 的归一化；
- `D3_mix`：`rho_mix=sqrt(rho_gap*rho_info)`，只做和为 1 的归一化。

没有 exponent、temperature、top-K、threshold、clipping、Keff 下限、continuous refinement、新 grid、新 angle window 或 truth/SNR 输入。D1-D3 的每个新角度均独立重跑冻结 range profile。

解析导数有限差分单测的相对 Frobenius 误差为 `1.0784e-7`。

## 3. D0 identity

D0 在任何 D1-D3 执行前，独立重放 uniform weighted `41/31/21` 搜索，并逐用户比较冻结 P_A：

- 60/60 grid 序列完全一致；
- 60/60 每级 selected index 完全一致；
- 60/60 最终 angle 完全一致，最大差 `0 deg`；
- 全部 stage score 的全局最大绝对差为 `2.8066e-13`，小于冻结容差 `1e-10`；
- D0 identity failures：0。

因此以下 `D0_uniform` 即冻结 `P_A` angle/range baseline。

## 4. Angle 指标

| 方法 | SNR | MSE (deg^2) | RMSE (deg) | median | P90 | P95 |
|:---|---:|---:|---:|---:|---:|---:|
| D0 | -10 | 1.123529e-6 | 0.001059967 | 0.000671614 | 0.001745259 | 0.002401552 |
| D0 | 0 | 2.201319e-7 | 0.000469182 | 0.000259542 | 0.000866748 | 0.001154238 |
| D0 | 20 | 8.379532e-9 | 0.000091540 | 0.000074167 | 0.000145446 | 0.000151053 |
| D1 gap | -10 | 1.256660e-6 | 0.001121008 | 0.000744329 | 0.001796433 | 0.002534885 |
| D1 gap | 0 | 2.201319e-7 | 0.000469182 | 0.000259542 | 0.000866748 | 0.001154238 |
| D1 gap | 20 | 8.379532e-9 | 0.000091540 | 0.000074167 | 0.000145446 | 0.000151053 |
| D2 information | -10 | 1.115157e-6 | 0.001056010 | 0.000671614 | 0.001745259 | 0.002401552 |
| D2 information | 0 | 2.349173e-7 | 0.000484683 | 0.000334007 | 0.000866748 | 0.001154238 |
| D2 information | 20 | 8.379532e-9 | 0.000091540 | 0.000074167 | 0.000145446 | 0.000151053 |
| D3 mix | -10 | 1.140099e-6 | 0.001067754 | 0.000744329 | 0.001663099 | 0.002401552 |
| D3 mix | 0 | 2.298167e-7 | 0.000479392 | 0.000316322 | 0.000866748 | 0.001154238 |
| D3 mix | 20 | 8.379532e-9 | 0.000091540 | 0.000074167 | 0.000145446 | 0.000151053 |
| C_enhanced | -10 | 1.123529e-6 | 0.001059967 | 0.000671614 | 0.001745259 | 0.002401552 |
| C_enhanced | 0 | 2.201319e-7 | 0.000469182 | 0.000259542 | 0.000866748 | 0.001154238 |
| C_enhanced | 20 | 8.379532e-9 | 0.000091540 | 0.000074167 | 0.000145446 | 0.000151053 |

冻结 C_enhanced 的 angle 在这 60 个用户上仍与 P_A/D0 完全相同；其 range 是原冻结 joint MUSIC 输出，不作为 D 的 range baseline。

## 5. Paired angle 结果

正的 RMSE 改善表示优于 D0；truth gain 定义为 `error_D0^2-error_D^2`。

| 方法 | SNR | MSE ratio vs D0 | RMSE改善 | win/tie/loss | angle changed |
|:---|---:|---:|---:|---:|---:|
| D1 | -10 | 1.118494 | -5.7589% | 6/4/10 | 80% |
| D1 | 0 | 1.000000 | 0% | 0/20/0 | 0% |
| D1 | 20 | 1.000000 | 0% | 0/20/0 | 0% |
| D1 | equal-SNR | 1.098467 | -4.8078% | 6/44/10 | 26.7% |
| D2 | -10 | 0.992549 | +0.3733% | 3/16/1 | 20% |
| D2 | 0 | 1.067166 | -3.3037% | 0/18/2 | 10% |
| D2 | 20 | 1.000000 | 0% | 0/20/0 | 0% |
| D2 | equal-SNR | 1.004744 | -0.2369% | 3/54/3 | 10% |
| D3 | -10 | 1.014748 | -0.7347% | 5/9/6 | 55% |
| D3 | 0 | 1.043995 | -2.1761% | 0/19/1 | 5% |
| D3 | 20 | 1.000000 | 0% | 0/20/0 | 0% |
| D3 | equal-SNR | 1.019419 | -0.9663% | 5/48/7 | 20% |

D1 只在 -10 dB 产生明显非均匀性，并改变 16/20 个角度，但 truth 结果为 6 improve、4 tie、10 worse。D2 在 -10 dB 有极小平均收益，却在 0 dB 的两个临界用户上都向错误方向改变离散选点。D3 没有修复这种跨 SNR 不一致。

20 dB 下三种权重均未改变任何最终 grid point；因此它们没有重复 Scheme A 在高 SNR 上观察到的 continuous grid-quantization correction。

## 6. Weight diagnostics

下表给出每 SNR 的 `K_eff` 范围/中位数、normalized entropy 中位数、top-100 累积权重、加权平均频率、edge/center 累积权重。频率按每用户实际冻结的 2047-carrier 集合保存。

| 方法 | SNR | K_eff min / median / max | H_norm median | top100 median | weighted mean freq median | edge median | center median |
|:---|---:|---:|---:|---:|---:|---:|---:|
| D1 | -10 | 1945.17 / 1955.21 / 1962.26 | 0.996421 | 0.063849 | 60.000658 GHz | 0.201407 | 0.199616 |
| D1 | 0 | 2046.84 / 2046.86 / 2046.87 | 0.999995 | 0.049499 | 59.998630 GHz | 0.200308 | 0.199785 |
| D1 | 20 | 2046.999989 / 2046.999990 / 2046.999991 | 1.000000 | 0.048857 | 59.998537 GHz | 0.200293 | 0.199805 |
| D2 | -10 | 2045.298 / 2045.298 / 2045.298 | 0.999945 | 0.051191 | 60.023506 GHz | 0.200353 | 0.199765 |
| D2 | 0 | 2045.298 / 2045.298 / 2045.298 | 0.999945 | 0.051191 | 60.023506 GHz | 0.200353 | 0.199765 |
| D2 | 20 | 2045.298 / 2045.298 / 2045.298 | 0.999945 | 0.051191 | 60.023506 GHz | 0.200353 | 0.199765 |
| D3 | -10 | 2010.22 / 2015.39 / 2018.38 | 0.998838 | 0.056664 | 60.012223 GHz | 0.200896 | 0.199773 |
| D3 | 0 | 2046.52 / 2046.54 / 2046.54 | 0.999985 | 0.050138 | 60.011071 GHz | 0.200300 | 0.199795 |
| D3 | 20 | 2046.573955 / 2046.574026 / 2046.574103 | 0.999986 | 0.050013 | 60.011024 GHz | 0.200293 | 0.199805 |

本轮没有出现隐式 few-carrier estimator：全局最小 `K_eff=1945.17`，仍为 K=2047 的约 95.0%；D2 最小约为 K 的 99.9%。D1 的 -10 dB top-100 最大累积权重也仅 `0.06456`。因此失败不能归因于少数 carrier 垄断，而是近均匀权重足以在少量离散网格临界用户上改变 argmax，但改变方向没有稳定 truth 对齐。

entropy 与 truth gain 的 per-SNR 相关性弱且不一致：D1 -10 dB `+0.187`；D2 -10/0 dB `+0.261/+0.232`；D3 -10/0 dB `+0.127/+0.003`。其余组因 truth gain 全为零而无定义。没有证据支持用权重集中度构造后验 selector。

## 7. Range 与 position

| 方法 | SNR | range RMSE (m) | range MSE ratio | range RMSE变化 | position RMSE (m) | position变化 |
|:---|---:|---:|---:|---:|---:|---:|
| D1 | -10 | 0.12727964 | 1.000591 | +0.0296% | 0.12728148 | +0.0298% |
| D1 | 0 | 0.00998669 | 1.000000 | 0% | 0.00998991 | 0% |
| D1 | 20 | 0.00136035 | 1.000000 | 0% | 0.00136122 | 0% |
| D2 | -10 | 0.12724332 | 1.000020 | +0.0010% | 0.12724492 | +0.0010% |
| D2 | 0 | 0.00998083 | 0.998827 | -0.0587% | 0.00998427 | -0.0564% |
| D2 | 20 | 0.00136035 | 1.000000 | 0% | 0.00136122 | 0% |
| D3 | -10 | 0.12726460 | 1.000355 | +0.0177% | 0.12726627 | +0.0178% |
| D3 | 0 | 0.00998077 | 0.998816 | -0.0592% | 0.00998414 | -0.0578% |
| D3 | 20 | 0.00136035 | 1.000000 | 0% | 0.00136122 | 0% |

所有 D 方案的三档 range Gate 均通过。range/position 变化很小，没有抵消 angle Gate 失败，也没有出现新角度沿用旧 P_A range 的违规。

## 8. Runtime 与 counts

同一 MATLAB session 中，P_A/C baseline 与 D1-D3 实际执行顺序均按用户轮换，减少固定顺序偏差。

| 方法 | mean complete runtime | vs D0 | weight construction | weighted fusion | frozen profile | runtime/C |
|:---|---:|---:|---:|---:|---:|---:|
| D0/P_A | 17.70912 s | baseline | 0 | 原冻结搜索 | 原冻结 profile | 0.516611 |
| D1 | 17.75069 s | +0.04157 s / +0.2347% | 0.000198 s | 0.66592 s | 1.53732 s | 0.517823 |
| D2 | 17.74796 s | +0.03884 s / +0.2193% | 0.013775 s | 0.66556 s | 1.52138 s | 0.517744 |
| D3 | 17.73810 s | +0.02898 s / +0.1636% | 0.013883 s | 0.66757 s | 1.50939 s | 0.517456 |
| C_enhanced | 34.27943 s | +93.57% | 0 | joint search | n/a | 1.000000 |

D1-D3 每用户均为 2047 次 direct EVD、93 个 MUSIC grid evaluations、`2047*93=190371` 个 single-carrier score evaluations。D0 也是 93/190371；C_enhanced 为 3083/6310901。response counts 随冻结 profile 实际一维优化调用数轻微变化：D 方法在 -10/0/20 dB 均值约为 `2086.6-2086.7 / 2052.5 / 2029.15`。

权重构造不是免费项，已计入完整重构 runtime。D2/D3 的解析 steering derivative 约增加 `0.0138 s/user`。

## 9. Frozen engineering Gate

| 方法 | angle MSE ratio -10/0/20 dB | equal-SNR ratio | range ratio -10/0/20 dB | runtime/C | 判定 |
|:---|:---|---:|:---|---:|:---|
| D1 | 1.118494 / 1.000000 / 1.000000 | 1.098467 | 1.000591 / 1.000000 / 1.000000 | 0.517823 | FAIL |
| D2 | 0.992549 / 1.067166 / 1.000000 | 1.004744 | 1.000020 / 0.998827 / 1.000000 | 0.517744 | FAIL |
| D3 | 1.014748 / 1.043995 / 1.000000 | 1.019419 | 1.000355 / 0.998816 / 1.000000 | 0.517456 | FAIL |

- D1：-10 dB per-SNR angle Gate 和 aggregate Gate 失败；
- D2：0 dB per-SNR angle Gate 和 aggregate Gate 失败；
- D3：-10/0 dB per-SNR angle Gate 和 aggregate Gate 失败；
- 三者 range/runtime Gate 全部通过，但不能覆盖 angle Gate 失败。

最终冻结结论：

> Simple parameter-free reliability/information weighting did not provide a robust cross-SNR angular improvement over uniform all-carrier MUSIC fusion.

## 10. 停止与交付

Scheme D 到此停止。不得搜索 exponent、temperature、top-K、threshold、Keff 下限、SNR selector 或 D4；不得与 A/B 组合；不得进入已有 600 calibration；不得运行或读取 R34 final 做开发判断。

结果目录：`matlab/results/full_spectrum/round35_schemeD_weighted_music_v1/`

- `per_user_outputs.csv`
- `method_summary.csv`
- `paired_comparisons.csv`
- `weight_diagnostics.csv`
- `weight_diagnostic_summary.csv`
- `engineering_gate.csv`
- `gate_decision.csv`
- `runtime_summary.csv`
- `d0_identity.csv`
- `failures.csv`
- `source_hashes.csv`
- `all_weights.mat`：D0-D3 全部 2047x60 权重及逐用户频率轴
- `checkpoint.mat`
- `result.mat`
- `figures/D_F1...D_F5...png` 与 `figure_manifest.csv`

全部 CSV/MAT 身份及五张图均标记 `Development study – not R34 final confirmation`。五张图已逐张视觉检查。
