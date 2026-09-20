# R39 完整阵列孔径与 VPML likelihood 机制消融

日期：2026-09-13  
协议：`research/87_r39_aperture_vpml_factorial_ablation_protocol.md`  
证据角色：既有 60 个 development users 的机制证据，不是独立 final validation

## 1. 执行与隔离

- 仅运行既有 60 个 development users，每个 SNR 20 个。
- 新执行 `L160_uniform`、`L160_vpml`、`N256_uniform` 三个固定单元。
- `N256_vpml` 完全复用冻结 Scheme F development 结果。
- calibration-600 仅在全部估计完成后只读用于绘制 E/F/P_A 曲线；没有参与
  R39 估计、参数选择或 Gate。
- 新用户、R34 final、参数调整、bracket 扩张和方案组合均为 0。
- 结果：
  `matlab/results/full_spectrum/round39_aperture_vpml_factorial_ablation_development_v1/result.mat`
- 结果 SHA-256：
  `fcc17099add6f83120c7061f817b4d14ac8e82438433dc2309d55bc5be0b5c00`

## 2. E、F 与 P_A 的冻结 calibration-600 性能

以下曲线读取冻结 R38 calibration-600，不重新估计任何用户。

![All-600 performance](../Beam%20Squint%20Assisted%20Joint%20Angle-Distance%20Localization%20for%20Near-Field%20Communications/matlab/results/full_spectrum/round39_aperture_vpml_factorial_ablation_development_v1/figures/efpa_calibration/EFPA_F1_performance_all600.png)

![Relative performance](../Beam%20Squint%20Assisted%20Joint%20Angle-Distance%20Localization%20for%20Near-Field%20Communications/matlab/results/full_spectrum/round39_aperture_vpml_factorial_ablation_development_v1/figures/efpa_calibration/EFPA_F3_relative_to_PA_all600.png)

### 2.1 每 SNR RMSE

| SNR | 方法 | angle RMSE (deg) | 相对 P_A 改善 | range RMSE (m) | 相对 P_A 改善 | position RMSE (m) | 相对 P_A 改善 |
|---:|:--|---:|---:|---:|---:|---:|---:|
| -10 | P_A | 0.001366591 | 0 | 0.223611865 | 0 | 0.223613262 | 0 |
| -10 | E single | 0.001305112 | 4.4987% | 0.223604234 | 0.00341% | 0.223605495 | 0.00347% |
| -10 | F VPML | 0.001224413 | 10.4036% | 0.223608752 | 0.00139% | 0.223609881 | 0.00151% |
| 0 | P_A | 0.000436379 | 0 | 0.014713131 | 0 | 0.014715374 | 0 |
| 0 | E single | 0.000397737 | 8.8551% | 0.014710719 | 0.01639% | 0.014712534 | 0.01930% |
| 0 | F VPML | 0.000329167 | 24.5686% | 0.014707917 | 0.03543% | 0.014709226 | 0.04178% |
| 20 | P_A | 0.000092094 | 0 | 0.001222014 | 0 | 0.001223251 | 0 |
| 20 | E single | 0.000041325 | 55.1268% | 0.001219398 | 0.21406% | 0.001219662 | 0.29341% |
| 20 | F VPML | 0.000030797 | 66.5590% | 0.001218223 | 0.31024% | 0.001218376 | 0.39858% |

### 2.2 Equal-SNR aggregate 与复杂度

| 方法 | angle MSE/P_A | angle RMSE 改善 | range MSE/P_A | range RMSE 改善 | position RMSE 改善 | runtime/user | runtime/P_A | profile passes |
|:--|---:|---:|---:|---:|---:|---:|---:|---:|
| P_A | 1 | 0 | 1 | 0 | 0 | 24.3835 s | 1 | 1 |
| E single | 0.901640 | 5.0453% | 0.999931 | 0.00347% | 0.00355% | 24.5815 s | 1.00812 | 1 |
| F VPML | 0.778371 | 11.7747% | 0.999969 | 0.00155% | 0.00170% | 27.1478 s | 1.11337 | 2 |

因此当前冻结证据不支持“E、F 都造成距离性能下降”。E single 和 F 在
all-600 的每个 SNR 上，range MSE ratio 均小于 1。F 相对 E single 的
pooled range MSE ratio 为 `1.0000385`，即 F 比 E 略差约 `0.00193%`
range RMSE，但两者都略优于 P_A。

## 3. 2 x 2 机制消融

固定 raw-snapshot estimator family，比较：

| 单元 | 孔径 | carrier 聚合 |
|:--|---:|:--|
| L160 uniform | 160 | 每 carrier 归一化后等权 |
| L160 VPML | 160 | raw projection energy likelihood |
| N256 uniform | 256 | 每 carrier 归一化后等权 |
| N256 VPML | 256 | raw projection energy likelihood，Scheme F |

![Factor contributions](../Beam%20Squint%20Assisted%20Joint%20Angle-Distance%20Localization%20for%20Near-Field%20Communications/matlab/results/full_spectrum/round39_aperture_vpml_factorial_ablation_development_v1/figures/R39_F2_factor_contributions.png)

### 3.1 Equal-SNR aggregate

| 固定另一因素 | candidate/reference angle MSE | angle RMSE 改善 | paired W/T/L |
|:--|---:|---:|:--|
| N256/L160，uniform | 0.653118 | 19.1843% | 36/4/20 |
| N256/L160，VPML | 0.662150 | 18.6274% | 34/6/20 |
| VPML/uniform，L160 | 0.995366 | 0.2320% | 24/21/15 |
| VPML/uniform，N256 | 1.009131 | -0.4555% | 16/22/22 |

interaction ratio 为 `1.013829`。在这 60 行上，VPML energy weighting
没有增强完整孔径收益，反而产生约 1.38% 的不利 MSE 交互。

### 3.2 每 SNR 的孔径贡献

| SNR | N256/L160 under uniform：RMSE 改善 | N256/L160 under VPML：RMSE 改善 |
|---:|---:|---:|
| -10 | 16.9231% | 16.3787% |
| 0 | 30.8712% | 30.4155% |
| 20 | 50.2613% | 50.1958% |

完整孔径在所有 SNR 都是稳定的大效应，并随 SNR 提升而增强。这符合阵列
孔径缩窄角度主瓣、提高局部曲率的机制；低 SNR 时 raw snapshot 噪声限制了
可兑现的孔径增益。

### 3.3 归因结论

1. Scheme F 的主要角度收益来自 `L160 -> N256` 完整阵列孔径。
2. VPML 相对 equal-carrier normalized projection 的额外贡献接近 0；在 N256
   上当前点估计略为负。
3. `L160_uniform` 与 `L160_vpml` 相对 P_A 的 equal-SNR angle RMSE 分别
   恶化 10.140% 和 9.885%。说明去掉 P_A 的 spatial smoothing/MUSIC 后，
   单独使用中央 L160 raw snapshot 在低、中 SNR 不占优势；完整 N256 孔径
   才抵消该损失并形成净收益。
4. 本消融严格分离了 raw-snapshot family 内的“孔径”和“carrier energy
   weighting”。它不能把 P_A spatial smoothing、raw matched projection 和
   MUSIC likelihood 三者完全拆成独立因素。

`N256_uniform` 在本轮 diagnostic Gate 全部通过，且 development-60 角度
RMSE 略优于 Scheme F；但 R39 协议禁止方法提升和 calibration 选择，因此
这里只能作为下一独立分支的候选假设，不能替代冻结 F 结论。

## 4. 为什么局部上仍会出现距离下降

### 4.1 角度和距离目标不是同一真值损失

E/F 都先从 P_A 状态更新角度，再给出与新角度相容的距离。优化的是观测
score，而不是未知真值的 angle/range squared error。因此 score 增加不保证
每个用户的距离误差减少。

all-600 配对结果印证这一点：

| 方法 | range changed | range SE W/T/L | corr(angle truth gain, range truth gain) |
|:--|---:|:--|---:|
| E single | 576/600 | 273/24/303 | 0.0231 |
| F VPML | 600/600 | 287/0/313 | 0.0134 |

相关性几乎为 0。虽然小幅 range loss 的用户略多，少数更大的 range gain
使 aggregate MSE 仍略优于 P_A。E/F 对 P_A 的平均绝对距离变化只有
`3.39e-5 m` / `3.97e-5 m`，最大约 `4.5e-4 m`。

### 4.2 E single 的机制

E single 用冻结 profile 在 P_A 最优点的 `J_rr` 和 `J_rtheta` 做隐式迁移：

`delta_r = -(J_r + J_rtheta delta_theta)/J_rr`。

它保留 P_A range 作为候选，只在新角度下 transported range 的同一 profile
score 更高时才接受。该规则控制了一阶耦合和复杂度，但局部 Hessian 是噪声
实现上的二阶近似，score 变好仍不等于 range truth error 变好。

原始完整 Scheme E 在 -10 dB 曾出现 `range MSE ratio=1.001446`，原因是新
角度后进行完整 profile 重搜可能切换到另一局部峰。R37 single-profile 取消
第二次完整搜索后，该退化已经消失。

### 4.3 Scheme F 的机制

F 在固定 P_A range 下，用每 carrier 独立复增益消元后的 raw-array VPML
更新角度，然后确实额外运行一次冻结 range profile。因此 F 总计两次完整
profile，而 P_A 与 E single 各一次。

独立的 carrier 复增益会吸收跨频复相位/幅度，F 的角度 likelihood 主要利用
阵列内空间相位和完整孔径，不直接约束后续跨频 range profile 的真值误差。
新角度使条件 profile 的最优点 `r*(theta)` 发生微小移动；该移动可能对单个
用户有利或不利，但 calibration-600 中没有形成总体距离损失。

### 4.4 为什么 development-60 看起来下降

R39 development-60 中 N256 uniform/F 的 pooled range RMSE 分别下降
`0.01036%`/`0.01080%`（负号表示变差），而 frozen all-600 中 F 改善
`0.00155%`。这些变化比主距离 RMSE 小四个数量级，且逐用户正负近乎对半，
因此 60 行样本的比值方向不稳定。它应解释为小样本波动，而不是稳定的
angle-range tradeoff。

## 5. Gate 与停止

- `L160_uniform`、`L160_vpml`：低/中 SNR angle Gate 和 aggregate angle
  Gate 失败。
- `N256_uniform`、`N256_vpml`：固定 development-60 diagnostic Gate 通过。
- 所有单元 range Gate 与 runtime-to-C_enhanced Gate 通过。
- 按 R39 协议停止；没有执行 calibration、R34 final、参数后验调整或新方案
  提升。

## 6. 输出

- `method_summary.csv`
- `factorial_effects.csv`
- `paired_factor_comparisons.csv`
- `variant_diagnostics.csv`
- `diagnostic_engineering_gate.csv`
- `distance_paired_diagnostics_r38_calibration.csv`
- `distance_paired_diagnostics_r39_ablation.csv`
- `EFPA_performance_relative_all600.csv`
- `EFPA_equal_snr_aggregate_all600.csv`
- `R39_equal_snr_relative_to_PA.csv`
- `figures/R39_F1_angle_factorial.png`
- `figures/R39_F2_factor_contributions.png`
- `figures/R39_F3_range_factorial.png`
- `figures/R39_F4_complexity.png`
- `figures/efpa_calibration/EFPA_F1_performance_all600.png`
- `figures/efpa_calibration/EFPA_F2_performance_holdout540.png`
- `figures/efpa_calibration/EFPA_F3_relative_to_PA_all600.png`
- `figures/efpa_calibration/EFPA_F4_complexity_all600.png`
