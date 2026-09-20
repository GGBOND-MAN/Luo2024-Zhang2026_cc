# R43 相干顺序架构开发协议

日期：2026-09-17  
版本：`R43-coherent-sequential-development-v1`  
证据角色：全新开发 pilot，不是 calibration 或 independent final validation

## 1. 研究问题

R42 已证明：不执行 `P_A` 的完整孔径顺序架构可以改善角度，但逐载波独立复增益的
`z+Y` 联合似然会丢弃阵列观测的跨载波距离相位，并错误重排距离模态。

R43 检验以下冻结假设：在保持顺序结构的前提下，让完整阵列观测 `Y` 只在其统计模型
有效的阶段工作，可以同时改善角度与距离：

`L06 front -> full-N angle -> coherent fixed-angle range profile`。

主方法 `H_seqY` 不执行 `P_A`、MUSIC、空间平滑或 EVD。`P_A` 和
`C_enhanced` 仅作为 estimator 外部的配对基线执行。

## 2. 冻结数据边界

- R34、R41 和 R42 的估计行、误差、统计量不得用于 R43 选参、回退或停止决定。
- R42 只提供“顺序结构”和“独立逐载波增益失败”的机制动机。
- 使用 10 个全新确定性位置，在 `-10/0/20 dB` 重复，共 30 个配对 trial。
- 位置种子为 `57000000`，trial 根种子为 `57100000`，与既有开发和终局数据分离。
- pilot 失败后不得从消融结果切换主方法或修改门槛。

## 3. 冻结估计器

### 3.1 角度阶段

从当前 `z` 运行冻结 L06 front，得到 `(theta_F,r_F)`。在 `r_F` 固定时，使用
完整 `N=256` 原始阵列和逐载波复增益消元的 VP score，在
`theta_F +/- 0.2 deg` 内执行 `41` 点网格与有界连续细化。该阶段输出
`theta_H`，不使用 `P_A` 的角度、网格或 bracket。

### 3.2 主距离阶段 H_seqY

在 `theta_H` 固定后，对所有选中载波的完整阵列模型

`Y = gamma A(theta_H,r) + W`

集中消去一个跨阵元、跨载波公共复增益 `gamma`。距离得分为向量化 `Y` 与候选
`A` 的归一化相干投影能量。它保留载波间相对相位，区别于 R42 的逐载波
`alpha_m` 模型。

距离只在 `[r_F-2,r_F+2]` 与物理范围的交集内，用与 `P_A` 相同的网格间距、
峰保留数和 `fminbnd` 容差优化。

### 3.3 预声明消融

- `H_seqZ`：相同角度，冻结 `q`-only conditional profile，即 R42 `H_array` 机制。
- `H_seqZY`：相同角度，等权组合两个 block 的 profile residual fraction；只用于
  判断 `z` 是否能稳定相干 `Y` 距离，不得替换主方法。
- `F_L06`：front 输出，作为粗中心控制。

## 4. Zhang2026 攻击判据

R43 只有同时满足以下结构和数值条件，才能加强 Zhang2026 攻击：

1. 主方法不运行局部二维 MUSIC、空间平滑或 EVD；
2. 主方法仍使用当前 `z/Y` 和相同位置/SNR，不读取基线结果；
3. 相对 `C_enhanced`，equal-SNR aggregate angle 和 range MSE ratio 均小于 1；
4. 每个 SNR 相对 `C_enhanced` 的 angle/range MSE ratio 不超过 1.05；
5. 相对 `P_A`，aggregate angle MSE ratio 不超过 0.98，range MSE ratio不超过
   0.95，且每个 SNR 两项均不超过 1.05；
6. 零失败、有限输出，所有一维搜索满足已评价候选保留不变量。

这些是开发工程门槛，不是统计优效证明。

## 5. 允许与禁止解释

若通过，可表述为：在当前同步、单径、跨载波相位相干的条件仿真中，局部二维 MUSIC
并非获得高角距精度的必要结构；完整孔径顺序估计可利用 MUSIC covariance 丢弃的相干
载波相位。

即使通过，也不能声称消除了 coarse-center dependence：L06 角窗和 `+/-2 m` 距离支持
仍依赖粗中心。也不能声称优于 Zhang 作者未公开的完整实现、异步鲁棒、多径鲁棒或硬件
验证。若相干 `Y` 的收益在加入载波相位扰动后消失，则该方法只能作为同步条件下的模型
审计，而不能作为通用替代方案。
