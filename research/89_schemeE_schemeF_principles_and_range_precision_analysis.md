# Scheme E 与 Scheme F 原理、实现和距离精度分析报告

日期：2026-09-13  
用途：外部技术复核材料  
证据范围：既有 development/calibration 数据，不是 R34 independent final validation

## 1. 问题背景

当前系统的冻结参数为：

- 阵列天线数：`N=256`；
- 子载波数：`M=2048`；
- angle search 使用载波数：`K=2047`；
- P_A spatial smoothing 子阵长度：`L=160`；
- 子阵数：`P=97`；
- angle grid：`41/31/21`；
- `L06 front`、`q-only`、direct EVD、`UseGram=false`；
- range estimator：当前角度下冻结的 `+/-2 m` conditional range profile；
- profile 参数：`lambda=1`。

研究目标是在不明显改变距离性能的前提下，提高 P_A 的角度精度。

需要先澄清：当前冻结的 Scheme E single-profile 和 Scheme F 在
calibration-600 中都没有造成相对 P_A 的总体距离精度下降。出现过距离下降
的是早期完整 Scheme E 的个别低 SNR 情况，以及 development-60 中幅度极小、
随后未被 calibration-600 复现的波动。

## 2. 原方法 P_A

### 2.1 处理流程

P_A 的主要流程是：

1. 用 `L06 front` 得到前端角度和距离中心；
2. 对 `K=2047` 个载波分别构造 `L=160, P=97` 的 spatial-smoothed
   covariance；
3. 每个载波执行 direct EVD，得到信号/噪声子空间；
4. 在固定 `41/31/21` 多级角度网格上融合一维 MUSIC statistic；
5. 得到最终离散角度 `theta_A`；
6. 在 `theta_A` 下运行一次冻结 `+/-2 m` conditional q-only range
   profile，得到 `r_A`。

因此 P_A 是明确的顺序估计：

`observations -> theta_A -> r_A(theta_A)`。

角度不是与距离同时进行二维全局优化。距离对角度有条件依赖。

### 2.2 P_A 的限制

P_A 的角度误差可能来自：

- 最终离散角度网格；
- `L=160` 子阵而不是完整 `N=256` 物理孔径；
- spatial smoothing 带来的孔径损失；
- 每载波 MUSIC statistic 的融合方式；
- 低 SNR 下子空间估计误差；
- Fresnel steering model 与噪声实现误差。

Scheme A 已证明简单连续化原 MUSIC statistic 不能充分解释 P_A 的误差，
即主要瓶颈不是单纯网格量化。

## 3. Scheme E：range-orthogonal local angle correction

Scheme E 包含两个版本：

1. R36 完整 Scheme E：新角度后重新运行第二次完整 range profile；
2. R37 Scheme E single-profile：保留同一角度结果，用隐式 range transport
   替代第二次完整 profile。

当前更合理的工程版本是第二种。

## 4. Scheme E 的角度原理

### 4.1 局部残差模型

Scheme E 复用 P_A 已经得到的每载波 signal vector `u_m`，并在
`(theta_A,r_A)` 附近构造 steering vector：

`a_m(theta,r)`。

对 steering vector 去除信号子空间投影：

`e_m = (I-u_m u_m^H) a_m`。

定义平均 subspace residual cost：

`C(theta,r) = mean_m ||e_m(theta,r)||^2`。

计算对角度和距离的局部 Jacobian：

`e_theta = (I-u_m u_m^H) partial(a_m)/partial(theta)`，

`e_r = (I-u_m u_m^H) partial(a_m)/partial(r)`。

由此得到二维 Gauss-Newton gradient 和 information matrix：

```text
g = [g_theta; g_r]

J = [J_theta_theta  J_theta_r
     J_r_theta      J_r_r]
```

### 4.2 Schur complement 消除距离 nuisance

Scheme E 不直接使用只对角度求导的 Newton step，而是先把局部距离方向
profile 掉：

`g_eff = g_theta - J_theta_r J_r_r^(-1) g_r`，

`J_eff = J_theta_theta - J_theta_r J_r_r^(-1) J_r_theta`。

角度更新为：

`delta_theta = -g_eff/J_eff`。

然后将 `theta_A+delta_theta` 限制在 P_A 最终最佳网格点左右相邻点构成的
bracket 内。

其物理意义是：允许距离作为局部 nuisance parameter 调整后，再判断真正
属于角度方向的 residual 下降，避免把 angle-range coupling 全部误认为角度
信息。

### 4.3 Scheme E 属于联合估计吗

严格来说，Scheme E 不是完整联合二维估计：

- 它没有在 `(theta,r)` 二维区域内执行网格搜索或二维优化；
- 它从 P_A 的 `(theta_A,r_A)` 出发；
- 它只执行一次经过 Schur complement 的局部 angle step。

更准确的描述是：

**带局部 range profiling 的顺序角度修正，或者局部准联合估计。**

它利用了二维导数信息，但最终执行结构仍然是先更新角度，再给出与新角度
相容的距离。

## 5. Scheme E 的距离处理

### 5.1 完整 Scheme E

完整版本在得到 `theta_E` 后，再运行一次冻结 conditional profile：

`r_E = argmax_r J_profile(theta_E,r)`。

总流程为：

`P_A angle -> first profile -> Schur angle update -> second profile`。

该版本有两个完整 range profile。

### 5.2 Scheme E single-profile

R37 不重新扫描完整 `+/-2 m` profile。它使用同一个 exact q-only log-profile
在 `(theta_A,r_A)` 的导数：

```text
J_r       = partial J_profile / partial r
J_rr      = partial^2 J_profile / partial r^2
J_rtheta  = partial^2 J_profile / partial r partial theta
```

根据隐函数/局部最优流形关系估计距离移动：

`delta_r = -(J_r + J_rtheta delta_theta)/J_rr`。

在新角度 `theta_E` 下只比较两个候选：

- 保留原 P_A range：`r_A`；
- 隐式迁移 range：`r_A+delta_r`。

使用完全相同的 exact q-only profile score，保留得分更高者。负曲率无效、
profile endpoint 或得分没有提高时均保留 `r_A`。

因此 Scheme E single-profile：

- 只有一次完整 range profile；
- 新增一次导数评价和两次候选评价；
- 不进行新的 range 搜索；
- 不是二维联合 ML。

## 6. Scheme F：full-array raw-snapshot variable-projection ML

### 6.1 观测模型

Scheme F 不再用 P_A 的 `L=160` spatial-smoothed MUSIC signal vector 作为
局部角度 objective，而是直接使用每个载波的完整 `N=256` 原始阵列快照：

`y_m in C^(256)`。

在固定 P_A range `r_A` 下，建立条件模型：

`y_m = alpha_m a_m(theta,r_A) + n_m`。

其中：

- `a_m` 是单位范数的完整阵列 Fresnel steering vector；
- `alpha_m` 是每载波独立未知复增益；
- `n_m` 是阵列噪声。

### 6.2 Variable projection

对任意候选角度，先解析消除复增益：

`alpha_hat_m(theta) = a_m(theta,r_A)^H y_m`。

代回最小二乘/条件 ML 后，最小化 residual energy 等价于最大化 explained
energy：

`S_F(theta) = sum_m |a_m(theta,r_A)^H y_m|^2 / sum_m ||y_m||^2`。

分母与角度无关，因此本质上最大化所有载波的 raw projection energy。

这里的 variable projection 是消除每载波复增益 `alpha_m`，不是把 range
一起消除。range 在整个 angle refinement 中固定为 `r_A`。

### 6.3 局部有界搜索

Scheme F 使用 P_A 最终实际角度网格：

1. 找到 P_A 最佳网格点及其左右相邻点；
2. 评价左点、P_A 点和右点的 VPML score；
3. 在左右点构成的 bracket 内用 `fminbnd` 最大化 VPML score；
4. 将连续解和三个固定网格点共同作为候选；
5. 强制保留 P_A grid optimum，最终 score 不得低于它。

得到 `theta_F` 后，重新运行一次完全冻结的 `+/-2 m` q-only range
profile，得到 `r_F`。

总流程为：

`P_A angle/range -> full-array VPML angle refinement at fixed r_A -> second range profile`。

### 6.4 Scheme F 属于联合估计吗

Scheme F 不是 angle-range joint ML：

- angle refinement 时 `r=r_A` 固定；
- 被 variable projection 消除的是每载波 `alpha_m`，不是 range；
- range 只在得到 `theta_F` 后重新条件估计。

因此它是：

**固定 P_A range 的完整阵列条件 ML 角度修正，然后重新条件估计距离。**

## 7. Scheme E 与 Scheme F 的主要区别

| 项目 | Scheme E single-profile | Scheme F |
|:--|:--|:--|
| 起点 | P_A `(theta_A,r_A)` | P_A `(theta_A,r_A)` |
| angle 数据 | P_A 每载波 signal vectors | 完整 N=256 raw snapshots |
| angle objective | subspace residual Gauss-Newton | concentrated raw-array conditional ML |
| range coupling | Schur complement 显式消除一阶 coupling | angle search 中固定 `r_A` |
| 连续更新 | 单次解析 Newton step | bounded `fminbnd` |
| 搜索范围 | P_A 相邻 grid bracket | P_A 相邻 grid bracket |
| range 更新 | profile 导数隐式迁移 | 第二次完整 frozen profile |
| complete profiles | 1 | 2 |
| 严格联合估计 | 否 | 否 |

## 8. 角度与复杂度结果

Calibration-600 equal-SNR aggregate：

| 方法 | angle MSE/P_A | angle RMSE 改善 | runtime/P_A | response count | profile passes |
|:--|---:|---:|---:|---:|---:|
| P_A | 1 | 0 | 1 | 2055.512 | 1 |
| E single-profile | 0.901640 | 5.0453% | 1.00812 | 2058.512 | 1 |
| F | 0.778371 | 11.7747% | 1.11337 | 2210.943 | 2 |

Scheme F 相对 E single 的 angle MSE ratio 为 `0.863284`，angle RMSE 再改善
`7.0869%`，但 runtime 增加约 `10.44%`。

R39 机制消融表明，Scheme F 的主要收益不是 VPML carrier energy weighting，
而是完整阵列孔径：

- `N256/L160` under uniform：angle RMSE 改善 `19.1843%`；
- `N256/L160` under VPML：改善 `18.6274%`；
- VPML/uniform at L160：改善 `0.2320%`；
- VPML/uniform at N256：反而恶化 `0.4555%`。

因此更准确的机制判断是：

**Scheme F 主要通过恢复完整 N=256 物理孔径提高局部角度曲率和分辨率；
VPML energy weighting 在当前数据中不是主要增益来源。**

## 9. 距离精度的实际结果

### 9.1 当前 E single 和 F 没有总体下降

Calibration-600：

| 方法 | equal-SNR range MSE/P_A | range RMSE 变化 | position RMSE 变化 |
|:--|---:|---:|---:|
| E single-profile | 0.999931 | 改善 0.00347% | 改善 0.00355% |
| F | 0.999969 | 改善 0.00155% | 改善 0.00170% |

每 SNR range MSE ratio：

| 方法 | -10 dB | 0 dB | 20 dB |
|:--|---:|---:|---:|
| E single/P_A | 0.999932 | 0.999672 | 0.995723 |
| F/P_A | 0.999972 | 0.999291 | 0.993805 |

全部小于 1。因此不能把当前结论写成“E、F 用距离性能交换角度性能”。

### 9.2 曾经出现的距离下降

1. 完整 Scheme E 在 all-600 的 -10 dB 曾得到 range MSE ratio
   `1.001446`，约等于 range RMSE 恶化 `0.0723%`。
2. R39 development-60 中 Scheme F pooled range RMSE 约恶化 `0.0108%`，
   但 calibration-600 变为改善 `0.00155%`。
3. F 相对 E single 的 pooled range MSE ratio 为 `1.0000385`，即 F 的
   range RMSE 比 E single 差约 `0.00193%`，但仍略优于 P_A。

## 10. 为什么新角度可能导致单用户距离变差

### 10.1 条件距离估计天然依赖角度

range estimator 实际求解的是：

`r_hat(theta) = argmax_r J_profile(theta,r)`。

当角度从 `theta_A` 改为 `theta_E` 或 `theta_F` 后，profile 曲线的峰值位置、
局部曲率和不同旁峰的相对高度都会改变。即使新角度更接近真值，也不能保证
在该噪声实现上新的 `r_hat(theta)` 更接近真实距离。

### 10.2 优化 score 不是真值误差

E 优化 subspace residual，F 优化 raw-array explained energy，range estimator
优化 q-only profile score。三者都不直接优化未知的：

`(r_hat-r_true)^2`。

因此：

- angle score gain 不等于 angle truth-error gain；
- angle truth-error gain 也不等于 range truth-error gain。

all-600 中 angle truth gain 与 range truth gain 的相关系数只有：

- E single：`0.0231`；
- F：`0.0134`。

两者在统计上几乎解耦。

### 10.3 完整 profile 的模态切换

完整 Scheme E 的第二次 profile 会在整个冻结 `+/-2 m` 区间重新比较峰值。
低 SNR 下两个局部峰得分非常接近，极小的角度变化可能使 optimizer 从原峰
切换到另一个旁峰。

R36/R37 已发现一行典型情况：

- 真值距离约 `18.169 m`；
- P_A 和 E single 约 `18.176 m`；
- 完整 Scheme E 第二 profile 跳到约 `18.046 m`。

R37 的隐式局部迁移没有发生该错误跳变，因此修复了完整 Scheme E 的低 SNR
小幅距离退化。

### 10.4 Scheme F 的每载波独立增益

Scheme F 对每个载波设置独立复增益 `alpha_m`。这会吸收载波间的复幅度和
公共/非公共相位差异，使 angle likelihood 对模型失配更稳健，但也意味着其
angle objective 不直接保持用于距离估计的跨频相干结构。

F 在固定 `r_A` 时选择的角度主要由完整阵列内的空间相位决定。后续 range
profile 则主要依赖跨频响应结构。这两个 objective 的信息利用方式不同，
所以 F 的 likelihood 增加不保证 range profile 的真值误差下降。

### 10.5 模型和近似不完全一致

E/F 的角度局部模型采用 Fresnel steering/derivative，而冻结 range profile
使用 exact q-only response statistic。即使两种模型在当前参数区间非常接近，
其局部梯度和曲率也不必完全一致。

这种 objective mismatch 会使 angle update 在自身模型下正确，但在新角度
重新计算 exact range profile 后出现微小距离位移。

### 10.6 小样本比值不稳定

距离 RMSE 主要由 -10 dB 的较大误差控制，而 E/F 引起的平均 range 移动只有：

- E single：`3.39e-5 m`；
- F：`3.97e-5 m`。

最大移动约 `4.5e-4 m`。这种变化比整体低 SNR range RMSE 小约三至四个
数量级，因此 60 个用户中少数行就可以改变 MSE ratio 位于 1 的哪一侧。

### 10.7 配对胜负与 aggregate MSE 可以方向不同

All-600 的 range squared-error 配对结果：

| 方法 | win/tie/loss vs P_A | aggregate range MSE/P_A |
|:--|:--|---:|
| E single | 273/24/303 | 0.999931 |
| F | 287/0/313 | 0.999969 |

虽然单用户 loss 数量略多，但 gain 行的幅度稍大，最终 aggregate MSE 仍略有
改善。这进一步说明当前距离差异非常小，不能只用 win rate 或少量用户下结论。

## 11. 对两个方案的技术判断

### Scheme E single-profile

优点：

- 与 P_A 高度兼容；
- 利用 Schur complement 控制一阶 angle-range coupling；
- 只有一次完整 profile；
- runtime 只增加约 0.81%；
- 当前 calibration 中角度、距离和位置 Gate 均通过。

局限：

- 只是一阶/二阶局部修正；
- 依赖 P_A signal vectors 和局部信息矩阵；
- 高噪声或强模型失配时，局部 Hessian 不是真值改善证书；
- 不是完整联合 ML。

### Scheme F

优点：

- 使用完整 N=256 阵列孔径；
- 直接使用 raw snapshots，避免 L160 spatial smoothing 的孔径损失；
- variable projection 解析消除每载波复增益；
- calibration 中角度提升明显强于 E。

局限：

- 当前实现需要第二次完整 range profile；
- runtime 比 P_A 高约 11.34%；
- 每载波独立增益削弱跨频约束与 angle-range 一致性；
- 低 SNR 下大量结果达到冻结 bracket endpoint；
- VPML score 不是逐用户 truth-error 证书；
- R39 表明主要贡献来自孔径，而不是 VPML weighting。

## 12. 可提交给 ChatGPT 的复核问题

建议将本报告连同以下问题提交给外部模型：

```text
请以近场宽带阵列估计和统计信号处理专家的角度审查附件报告。

请重点回答：

1. Scheme E 使用 Gauss-Newton information matrix 的 Schur complement
   profile 掉 range nuisance，其推导和“局部准联合估计”定位是否正确？

2. Scheme E single-profile 的
   delta_r=-(J_r+J_rtheta*delta_theta)/J_rr
   是否是合理的局部最优流形迁移？保留 r_A 与 transported range 两个候选
   是否足以避免低 SNR profile mode switching？

3. Scheme F 的模型
   y_m=alpha_m a_m(theta,r_A)+n_m
   在每载波独立 alpha_m 下，集中似然
   sum_m |a_m^H y_m|^2 / sum_m ||y_m||^2
   是否可以称为 conditional variable-projection ML？

4. 每载波独立 alpha_m 会吸收哪些跨频幅相信息？是否会削弱距离可辨识性或
   angle-range 一致性？注意 Scheme F 的 range 并不在该 likelihood 中优化，
   而是在 angle refinement 后由独立 q-only profile 重新估计。

5. 2x2 消融显示完整孔径贡献约 18.6%-19.2% angle RMSE，而 VPML weighting
   贡献约 0 或略为负。是否应将 Scheme F 的核心贡献解释为 full-aperture
   raw-snapshot refinement，而不是 VPML likelihood weighting？

6. 当前 all-600 数据中 E/F 的 range MSE 均略优于 P_A，但逐用户 angle gain
   与 range gain 的相关系数接近 0。请分析这种“角度显著改善、距离基本不变、
   单用户距离正负波动”的统计和物理原因。

7. 完整 Scheme E 的第二次全 profile 曾发生旁峰模态跳变，而隐式局部迁移
   避免了该问题。请判断这是合理的 regularization，还是可能隐藏某些本应
   发生的大范围 range correction。

8. 在不使用新用户、不扩大 bracket、不增加参数 gating 的前提下，下一步
   最有价值的理论验证应是什么？请区分：
   - estimator mechanism；
   - finite-sample evidence；
   - independent final validation。

请不要假设“E 和 F 已经造成总体距离下降”，因为 calibration-600 的每-SNR
range MSE ratio 均小于 1。需要解释的是为什么单用户或小样本仍可能下降。
```

## 13. 证据边界

- Scheme E single 和 Scheme F 的结果属于 development/calibration evidence；
- 尚未使用 R34 final 1400 trials；
- 当前结果不能称为 independent final validation；
- 本报告没有新增实验、用户、调参或方案组合；
- 任何从本报告提出的新 estimator 都必须建立新的冻结协议和独立证据链。

## 14. 关联文件

- `research/69_angle_improvement_common_protocol.md`
- `research/82_r37_single_profile_transport_results.md`
- `research/83_r38_schemeF_raw_array_vpml_protocol.md`
- `research/86_r38_schemeF_calibration600_results.md`
- `research/87_r39_aperture_vpml_factorial_ablation_protocol.md`
- `research/88_r39_aperture_vpml_factorial_ablation_results.md`
- `matlab/+r36/schemeE/r36RangeOrthogonalOneStep.m`
- `matlab/+r37/singleProfile/r37ImplicitProfileTransport.m`
- `matlab/+r38/schemeF/r38RawArrayVpmlScore.m`
- `matlab/+r38/schemeF/r38BracketedVpmlRefinement.m`
