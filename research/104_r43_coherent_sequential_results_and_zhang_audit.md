# R43 相干顺序架构结果与 Zhang2026 攻击审计

日期：2026-09-17  
协议：`R43-coherent-sequential-development-v1`  
状态：**同步条件下 pilot 通过；同步鲁棒性不通过；不自动授权独立终局主张**

## 1. 执行完整性

- 全新确定性位置 10 个，SNR 为 `-10/0/20 dB`，共 30 个配对 trial。
- 30/30 成功，失败数为 0，所有估计为有限值。
- R34/R41 final 和 R42 结果行读取数为 0。
- `H_seqY` 估计器不执行 `P_A`、MUSIC、空间平滑或 EVD。
- `P_A` 与 `C_enhanced` 仅在 trial 外层作为同观测配对基线执行。
- 单元测试 5 passed、0 failed、0 incomplete；主要源码 Code Analyzer 无 error/warning。
- 原始结果在汇总之前保存；结果目录保留 `raw_results.mat`、`result.mat` 和全部 CSV。

本轮仍是小样本 development evidence，不是统计 superiority 或 independent final evidence。

## 2. 主方法 H_seqY

`H_seqY` 的冻结顺序为：

`L06 z-front -> full-N raw-array angle -> common-gain coherent Y range profile`。

角度阶段只使用逐载波相位不变的完整孔径投影。距离阶段固定新角度，使用一个跨阵元、
跨载波公共复增益的相干 `Y` profile，因此保留载波间相对相位。

### 2.1 相对 P_A

| SNR | angle MSE ratio | angle RMSE 改善 | range MSE ratio | range RMSE 改善 | range W/L |
|---:|---:|---:|---:|---:|---:|
| -10 | 0.13137 | 63.75% | 2.0188e-6 | 99.8579% | 10/0 |
| 0 | 0.44602 | 33.22% | 1.0390e-5 | 99.6777% | 10/0 |
| 20 | 0.11671 | 65.84% | 2.5187e-5 | 99.4981% | 10/0 |
| equal-SNR aggregate | 0.15473 | 60.66% | 2.1235e-6 | 99.8543% | 30/0 |

### 2.2 相对 strengthened Zhang-style C_enhanced

| SNR | angle MSE ratio | range MSE ratio |
|---:|---:|---:|
| -10 | 0.13137 | 2.0900e-6 |
| 0 | 0.44602 | 1.7699e-6 |
| 20 | 0.11671 | 3.6400e-6 |
| equal-SNR aggregate | 0.15473 | 2.0685e-6 |

预声明的 `P_A` 和 `C_enhanced` angle/range 工程门槛全部通过。必须强调：
`C_enhanced` 是本项目 equally optimized strengthened Zhang-style executable baseline，
不是 Zhang 作者的未公开完整实现。

### 2.3 绝对误差与运行时间

`H_seqY` range RMSE 在 `-10/0/20 dB` 分别为
`1.5396e-4/3.8942e-5/5.0841e-6 m`。完整在线时间的 equal-SNR 描述均值为：

- `P_A`: `20.25 s/user`；
- `C_enhanced`: `38.03 s/user`；
- `H_seqY`: `18.03 s/user`。

本次运行中，`H_seqY` 相对 `P_A` 和 `C_enhanced` 分别低约 `10.94%` 和
`52.59%`。这是同机小样本描述性时间，不是渐近复杂度或作者代码时间结论。

## 3. 机制消融

`H_seqZ` 使用同一个新角度，但距离仍为 `q`-only profile。其 aggregate angle MSE ratio
同样为 `0.15473`，而 range MSE/P_A 为 `1.000999`。因此：

1. 大幅角度收益来自完整 `N=256` 孔径，而不是距离目标；
2. 仅替换角度时，距离仍基本保持 `P_A` 水平；
3. `H_seqY` 的数量级距离收益完全来自跨载波相干 `Y` phase，而不是从角度收益间接产生。

`H_seqZY` 的 aggregate range MSE/P_A 为 `4.9957e-6`，仍非常低但弱于 `Y`-only。
这说明在当前完全匹配的 `Y` 仿真中，额外等权加入较噪的 `z` block 并没有提供收益。

## 4. 残余时延审计

在同一批 0 dB 位置上冻结 front、角度和所有数值设置，只向 `Y` 加入 R32 已定义的
公共基带线性相位：

| residual delay | 平均距离移动 | 理论 c*tau | delay/zero MSE ratio |
|---:|---:|---:|---:|
| -0.1 ns | -0.0299797 m | -0.0299792 m | 5.9266e5 |
| +0.1 ns | +0.0299796 m | +0.0299792 m | 5.9272e5 |

最大移动残差小于 `1.1e-6 m`，表明估计器精确地把残余时延解释为距离。这不是实现
错误，而是绝对跨载波相位模型的可辨识性边界。零时延 range RMSE 为
`3.8942e-5 m`，加入 `+/-0.1 ns` 后约为 `0.02998 m`。

## 5. Zhang2026 攻击要求审计

### Attack A/B：coarse-center 与可达支持

**仍然成立，但 R43 没有解决它。** `H_seqY` 仍由 L06 粗中心确定 `+/-0.2 deg` 角窗和
`+/-2 m` 距离支持。若真值在支持外，顺序 profile 同样不可返回真值。因此 R43 不能写成
“消除了误差传播”或“全局搜索替代”。它只避免使用 Zhang 的窄二维 MUSIC 局部目标。

### Attack C：joint MUSIC 不保证可靠距离精化

**R43 提供新的强机制证据，但有同步限定。** 对同一 `Y`，逐载波 covariance/MUSIC 对
每个载波的公共复相位不变，而相干 profile 保留该相位携带的时延信息。本 pilot 中后者
显著优于 `C_enhanced`，说明二维 MUSIC 并未用尽输入数据中的距离信息。

不得写成“同一 nuisance model 下理论上 profile 普遍优于 MUSIC”。两者采用不同 gain/
clock 假设；`H_seqY` 的优势要求跨载波 phase coherent 和公共时延已校准。

### Attack D：角度不需要二维 range 搜索

**满足并强化。** `H_seqY/H_seqZ` 不运行二维 MUSIC，角度 aggregate MSE 相对
`C_enhanced` 为 `0.15473`。这支持：在当前冻结单径模型中，完整孔径 angle-only
refinement 足以超过 spatial-smoothed joint search。它仍不是任意模型下 angle-range
普遍解耦的证明。

### Attack E：复杂度

**提供正向开发证据。** 本轮 `H_seqY` 完整运行时间约为 `C_enhanced` 的 `47.41%`，且
省去每载波 covariance、direct EVD 和二维网格。只能报告该冻结实现和机器上的结果，不能
声称低于 Zhang 作者代码的运行时间。

### Attack F：自身限制

**必须升级为核心限定。** `+/-0.1 ns` 即产生 `+/-3 cm` 系统距离偏差，因此禁止声称
timing-offset robust、hardware validated 或异步可用。当前大幅距离结果只属于 synchronized
LoS single-path、相干 acquisition、Fresnel `Y` 模型和已校准 common delay。

## 6. 最终判断

当前新架构对 Zhang2026 的攻击要求是 **条件满足，而非全面满足**：

1. 它强力支持“localized joint 2-D MUSIC 不是高精度角距估计的必要结构”；
2. 它展示了 Zhang-style per-carrier covariance 会丢弃可用于距离的跨载波公共相位；
3. 它以更低描述性运行时间同时改善当前 strengthened baseline 的角度和距离；
4. 它没有消除 coarse-center/support dependency；
5. 它的距离优势依赖严格同步，不能直接转换为硬件或异步场景的普遍结论。

因此，R43 可以作为 Zhang2026 **信息利用不足和二维 MUSIC 非必要性** 的开发证据，但不能
替代既有 Attack A/B 的支持排除论证，也不能在没有显式 clock nuisance 的情况下晋升为
最终通用方法。下一项理论工作应将未知公共时延纳入 nuisance parameter；若没有外部时间
参考，绝对距离与时延偏置本身不可分辨，必须明确报告相对距离或同步先验。
