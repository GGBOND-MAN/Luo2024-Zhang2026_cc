# R44 结果与 P_A / 新顺序方法攻击能力比较

日期：2026-09-17  
协议：`R44-clock-invariant-sequential-development-v1`  
状态：**主 pilot 失败；timing stress 按协议未执行；P_A 保持主攻击方法**

## 1. R44 实验完整性

- 10 个全新位置，`-10/0/20 dB`，共 30 个配对 trial；30/30 成功。
- 未读取 R34/R41 final 或 R42/R43 estimate rows 进行选参、fallback 或 stopping。
- 主方法 `H_seqVP` 不执行 `P_A`、MUSIC、空间平滑、covariance 或 EVD。
- 单元测试 5 passed、0 failed、0 incomplete；主要源码 Code Analyzer 无 correctness issue。
- 由于主性能 gate 失败，预声明 timing stress 没有执行，不能用次要 stress 结果救回方法。

## 2. R44 主结果

### 2.1 H_seqVP 相对 P_A

| SNR | angle MSE ratio | angle RMSE 改善 | range MSE ratio | range W/L |
|---:|---:|---:|---:|---:|
| -10 | 0.52769 | 27.36% | 18.3960 | 1/9 |
| 0 | 0.44923 | 32.98% | 63.6945 | 1/9 |
| 20 | 0.06448 | 74.61% | 94.7814 | 1/9 |
| equal-SNR aggregate | 0.51996 | 27.89% | 19.1100 | 3/27 |

`H_seqVP` 通过 angle gate，但 range gate 全部失败。range RMSE 在
`-10/0/20 dB` 为 `0.32372/0.07549/0.009931 m`，对应 `P_A` 为
`0.07548/0.009459/0.001020 m`。

### 2.2 相对 C_enhanced

聚合 angle MSE ratio 为 `0.51996`，说明完整孔径 angle-only refinement 仍明显优于
spatial-smoothed joint angle。聚合 range MSE ratio 为 `4.47555`，因此相位不变的
full-array curvature profile 不能替代 Zhang-style range output。

### 2.3 运行时间

equal-SNR 描述均值：

- `P_A`: `20.29 s/user`；
- `C_enhanced`: `44.30 s/user`；
- `H_seqVP`: `16.21 s/user`。

`H_seqVP` 相对两者快约 `20.13%/63.41%`，但失败方法的速度不能抵消距离精度失败。

## 3. 失败机制

- 30 行均无 endpoint 或 near-boundary 命中，失败不是搜索区间截断。
- mean absolute displacement from front 在 `-10/0/20 dB` 为
  `0.2335/0.05364/0.00819 m`。
- 最大 range error 为 `0.7281/0.1724/0.02237 m`。
- 使用 truth angle 重跑同一个 phase-invariant range profile 后，RMSE 为
  `0.32323/0.07545/0.009927 m`，与实际角度结果几乎相同。
- selected range 相对 truth range 的 score 优势中位数只有
  `4.02e-7/2.77e-7/8.02e-9`。

因此主要失败不是 angle-to-range error propagation，而是逐载波 nuisance phase 被消除后，
只剩近场阵列曲率提供距离信息；该目标在当前 `N=256`、15--50 m 与噪声条件下过平，有限
样本噪声足以选择远离真值的内部竞争峰。

## 4. P_A 与新顺序方法的相同攻击点

### 4.1 都否定“二维联合搜索自动移除粗估计依赖”

两者都从 L06 front 出发，并在粗中心限定的角度/距离支持内运行。它们都说明后端即使是
joint 或 sequential，也不能自动使支持外真值重新可达。两者自身也没有消除该限制。

### 4.2 都支持二维 MUSIC 对角度不是必要的

- `P_A`：固定距离的一维 MUSIC 在 R34 的 1400 independent trials 中与 C 有
  1398/1400 相同角度，并完成七 SNR 预声明非劣检验。
- 新顺序方法：完整 `N=256` raw-array angle 在 R42--R44 development pilots 中多次得到
  更低 angle MSE，R44 聚合 angle MSE/P_A 为 `0.51996`。

两者共同攻击 Zhang2026 将 angle 和 range 都放入局部二维网格的必要性，但证据成熟度不同。

### 4.3 都使用与 MUSIC 不同的统计信息估计距离

`P_A` 使用相干 `z/q` conditional profile；R43 使用 coherent raw `Y` phase；R44 使用
per-carrier phase-invariant raw-array curvature。共同结论是：MUSIC pseudo-spectrum 最大值不等于
最小 truth range error，联合搜索也不会自动保证可靠距离更新。

### 4.4 都保留模型和硬件边界

两者都只在 synchronized LoS single-path 条件模型中开发，均不能声称 multipath robust、
hardware validated 或优于 Zhang 作者未公开实现。

## 5. 两者不同的攻击点

| 攻击维度 | P_A | 新完整孔径顺序方法 |
|:--|:--|:--|
| coarse support | 通过 `+/-2 m` profile 和预指定 final case 直接展示窄窗排除真值 | 使用相同有限支持，没有新增 support 恢复证据 |
| angle 机制 | 删除二维 range 维，但仍保留 L160 spatial-smoothed MUSIC/EVD | 删除二维 range 维，并进一步删除 smoothing、covariance、MUSIC 和 EVD |
| aperture 攻击 | 不能攻击 spatial smoothing 的孔径损失，因为自身仍用 L160 | 直接攻击 L160 aperture loss；完整 N256 在三个新 pilot 中持续改善角度 |
| range 信息 | 使用 `z` 的跨频相干波束响应，低中 SNR 可稳定修复窄 MUSIC range | R43 coherent Y 极准但依赖 clock；R44 clock-invariant Y curvature 太弱而失败 |
| timing | `P_A` 在 R32 的 `+/-0.1 ns` 下约移动 `+/-0.02998 m` | R43 同样敏感；R44 score 理论相位不变，但精度 gate 已失败，未进入端到端 stress |
| 复杂度证据 | 评分点减少 96.98%，冻结 timing 中比 C 快 50.19% | R44 pilot 比 C 快 63.41%，但仅 development 且方法失败 |
| 证据等级 | R34 200 positions、7 SNR、1400 independent trials，加冻结统计和 timing | R42--R44 各为 10-position development pilot，无独立 final evidence |

## 6. 哪个方法更能支持攻击 Zhang2026

### 当前总体答案：P_A 更强

原因不是 `P_A` 在所有数值上更先进，而是其攻击链更完整：

1. 有严格的 support exclusion 数学事实和预指定 final case；
2. 有 1400 个 independent trials，而新方法只有 development pilot；
3. angle 非劣、range 结果、复杂度和限制均已有冻结统计口径；
4. `P_A` range 在当前模型中可用，而 R44 的 clock-invariant range 已明确失败；
5. R43 的巨大 range 收益依赖已校准 common delay，只适合作为信息上界/机制证据。

### 新方法更强的局部攻击点

新完整孔径顺序方法在以下问题上比 `P_A` 更有解释力：

1. Zhang 的 spatial smoothing 会损失有效孔径和角度曲率；
2. raw full-aperture angle refinement 不需要 MUSIC/EVD 即可超过当前 joint baseline；
3. per-carrier covariance 会丢弃跨载波绝对相位中的距离信息；
4. 若消去该相位，单靠空间曲率的距离信息在当前场景又过弱，揭示了 range identifiability
   对 gain/clock nuisance model 的强依赖。

因此论文策略应为：**P_A 继续承担主方法与主攻击证据；完整孔径新方法作为 angle/aperture
机制消融和未来扩展，不替换 P_A。** R43 可作为 synchronized oracle 上界，R44 则作为
“时钟不变但距离信息不足”的负结果，两者共同界定为什么不能简单宣称一种 raw-array
顺序方法在所有 nuisance assumptions 下同时优于 Zhang2026。
