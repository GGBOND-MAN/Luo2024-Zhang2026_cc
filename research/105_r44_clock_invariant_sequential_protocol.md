# R44 时钟不变完整孔径顺序方法协议

日期：2026-09-17  
版本：`R44-clock-invariant-sequential-development-v1`  
证据角色：全新 development pilot 与预声明 timing stress，不是 calibration/final

## 1. 动机

R43 的 common-gain coherent `Y` profile 在零时延下精度极高，但 `0.1 ns` 残余时延会
产生约 `3 cm` 距离偏移。R44 不继续扩大该理想同步结果，而是显式消除每个载波的未知
公共复相位，仅利用完整阵列内的近场空间曲率估计距离。

主方法 `H_seqVP`：

`L06 z-front -> full-N phase-invariant angle -> full-N phase-invariant range profile`。

对每个载波使用模型 `y_m=alpha_m a_m(theta,r)+n_m` 并解析消去 `alpha_m`。角度与距离
按顺序分别做一维搜索。主方法不执行 `P_A`、MUSIC、空间平滑、covariance 或 EVD。

## 2. 冻结数据和条件

- 全新 10 个位置，位置种子 `58000000`，trial 根种子 `58100000`。
- 主性能 SNR 为 `-10/0/20 dB`，共 30 个新配对 trial。
- R34/R41 final、R42/R43 estimate rows 不得用于选参、fallback 或 stopping。
- `P_A` 与 `C_enhanced` 只在 estimator 外部作为同观测基线运行。
- 主性能完成后，在相同 10 个位置的 0 dB 观测上施加 `-0.1/+0.1 ns` 公共残余时延，
  端到端重跑 `P_A` 和 `H_seqVP`。timing stress 不改变主方法选择。

## 3. 冻结数值结构

- L06 front、2047 个局部载波、完整 `N=256` 物理孔径；
- angle window `+/-0.2 deg`，41 点初始网格与有界连续细化；
- range window `[r_F-2,r_F+2]` 与物理范围交集；
- range 网格间距、峰保留数、`TolX` 和 candidate retention 与 `P_A` profile 一致；
- `H_seqZ` 作为相同角度下的 q-only 距离消融；`F_L06` 作为粗前端控制。

## 4. Pilot 门槛

主方法同时满足才通过：

1. 相对 `P_A` 每 SNR angle/range MSE ratio 均不超过 `1.05`；
2. 相对 `P_A` equal-SNR angle MSE ratio 不超过 `0.98`；
3. 相对 `P_A` equal-SNR range MSE ratio 不超过 `0.98`；
4. 相对 `C_enhanced` 每 SNR angle/range MSE ratio 均不超过 `1.05`；
5. 相对 `C_enhanced` 两个 aggregate MSE ratio 均小于 `1`；
6. 零失败、有限输出、所有 scalar searches 满足 candidate-retention invariant。

Timing stress 单独判定：相对各自零时延输出，`H_seqVP` 最大角度移动不超过
`1e-8 deg`、最大距离移动不超过 `1e-6 m`；并报告 `P_A` 的对应移动和 MSE 增长。

## 5. 与 Zhang2026 攻击的预声明解释

若通过，R44 支持：在相同 raw-array 输入下，保留完整孔径并逐载波 profile nuisance phase
的顺序一维估计，可替代 localized spatial-smoothed joint 2-D MUSIC，并避免使用绝对跨载波
时延相位。它直接检验 Zhang-style spatial smoothing、二维网格和 covariance statistic 是否
是性能所必需。

R44 仍不消除 coarse-center/support dependence，也不等于 Zhang 作者代码复现。即使 timing
stress 通过，也只表示对公共逐载波相位旋转不变；不证明多径、阵列校准误差、载波相关
增益、CFO、相位噪声或硬件鲁棒。
