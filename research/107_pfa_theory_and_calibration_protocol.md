# P_FA 理论定义与 R45 Calibration-600 协议

日期：2026-09-17  
方法版本：`PFA-full-aperture-sequential-v1`  
实验版本：`R45-PFA-calibration600-v1`  
证据角色：预最终校准，不是 independent final validation

## 1. 正式方法

`P_FA` 固定为：

`L06 coherent z front -> full-N conditional raw-array angle -> exact q-only range profile`。

它是一个独立在线估计器，不执行 `P_A`，不读取 `P_A` 的最终角度、距离、MUSIC grid、
subspace 或 bracket。它只复用经过等价验证的 L06 前端定义和 q-only 距离 profile 定义。

## 2. 角度目标的集中似然

在 L06 给出的距离 `r_F` 固定时，对选中的 `K=2047` 个载波采用条件模型

`y_m = alpha_m a_m(theta,r_F) + n_m`，

其中 `a_m` 是单位范数的完整 `N=256` Fresnel 导向矢量，`alpha_m` 是逐载波未知复增益。
在复高斯等方差噪声条件下，对 `alpha_m` 解析最小化得到

`alpha_hat_m(theta) = a_m(theta,r_F)^H y_m`，

以及集中残差

`E_Y(theta|r_F) = sum_m (||y_m||^2-|a_m^H y_m|^2)`。

因此最小化残差等价于最大化

`S_FA(theta|r_F) = sum_m |a_m(theta,r_F)^H y_m|^2 / sum_m ||y_m||^2`。

`P_FA` 在 `[theta_F-0.2 deg,theta_F+0.2 deg]` 与物理域交集上先评价41点网格，随后只在
最佳网格点相邻区间内执行有界 `fminbnd`。最终候选不得低于已评价网格最佳得分。

## 3. 相位 nuisance 不变性

对任意逐载波相位 `phi_m`，若 `y_m' = exp(j phi_m)y_m`，则

`|a_m^H y_m'|^2 = |a_m^H y_m|^2`。

所以角度目标对公共时延、每载波公共初相和其他只对整列施加的相位旋转不变。该不变性不
覆盖阵元相关相位误差、阵列校准误差、CFO 引起的时变列内失配或多径。

## 4. 完整孔径角度机制

在远场线性相位主项下，去除未知复增益后的角度信息与阵元坐标二阶中心矩成正比。对居中
ULA，单位范数 steering 的线性角度导数能量含有

`(N^2-1)d^2/12`。

仅比较几何孔径项，`N=256` 与 `L=160` 的导数能量比约为

`(256^2-1)/(160^2-1) = 2.56`。

这说明完整孔径具有更强的局部角度曲率，但不是 `P_FA/P_A` MSE 比值定理：空间平滑会改变
噪声统计、有效快照和融合方式，近场二次相位也会增加额外项。R45 只能用独立校准验证实际
有限样本收益。

## 5. 固定前端距离的局部条件

令集中角度目标为 `S(theta,r)`。若真值邻域内 `-S_theta_theta >= mu > 0` 且
`|S_theta_r| <= kappa`，则由隐函数关系

`d theta_star / dr = -S_theta_r/S_theta_theta`

可得局部敏感性界

`|delta theta_star| <= (kappa/mu)|delta r| + higher-order terms`。

该条件解释了为何 range 误差小且角度曲率强时可以固定 `r_F`，但 R45 不假定每个 trial 都
满足统一 `mu/kappa`。没有曲率证书的行只能由有限样本结果评价。

## 6. 距离后端与局部传递

在 `theta_FA` 固定后，距离使用与 `P_A` 完全相同的集中复谱目标

`J_P(r|theta_FA)=log(|q^H z|^2/(||q||^2||z||^2))`

及 `[r_F-2,r_F+2]` 物理裁剪支持、0.05 m最大网格间距、8峰保留和连续细化。增强方法
没有提出新的距离统计。若局部 profile 峰满足 `J_rr<0`，其角度敏感性由

`dr_star/dtheta = -J_rtheta/J_rr`

描述；这解释小角度变化为何通常只引起很小距离移动，但不构成逐样本距离非劣保证。

## 7. 理论边界

- L06、角窗和 `+/-2 m` 距离域仍由粗中心确定；不声明全局最优。
- `z` 使用 exact spherical response，`Y` 使用 Fresnel response；两块不是统一似然。
- 当前 `z/Y` 条件仿真没有统一 RF 时隙、路径损耗和总能量预算。
- q profile 仍要求 common delay 已校准；不声明异步、多径或硬件鲁棒。
- 完整孔径收益是机制假设，不是普遍优于 spatial smoothing 的定理。

## 8. R45 新数据设计

- 200 个全新独立位置，角度均匀分布于 `[-60,60] deg`，距离均匀分布于 `[15,50] m`；
- 每个位置复用到 `-10/0/20 dB`，共600个配对 trial；
- position seed `59000000`，trial seed root `59100000`；
- 不读取 R34/R41 final estimate rows，也不读取 R42--R44 estimate rows；
- 比较 `P_FA/P_A/G_schur/C_enhanced`；所有参数在运行前冻结；
- 位置1--20构成预声明 diagnostic-60，位置21--200构成 holdout-540；二者都不用于调参。

## 9. 预声明校准判据

硬判据同时适用于 all-600 与 holdout-540：

1. 每SNR `P_FA/P_A` angle MSE ratio `<=1.05`；
2. equal-SNR angle MSE ratio `<=0.85`；
3. 每SNR range MSE ratio `<=1.02`；
4. equal-SNR range MSE ratio `<=1.01`；
5. equal-SNR `P_FA/C_enhanced` angle/range MSE ratio 均 `<1`；
6. 零失败、有限输出和候选保留不变量全部通过。

统计校准使用 position-cluster bootstrap，10,000次、seed `59200000`，三SNR共享重采样索引：

- angle success：`U95(equal-SNR MSE ratio P_FA/P_A)<1`；
- range noninferiority：`U95(equal-SNR MSE ratio P_FA/P_A)<1.02`。

G 是已冻结的已验证参照。`P_FA/G` 只作预声明 secondary comparison，不用于改变方法。

## 10. 停止规则

任一硬判据、bootstrap判据或身份检查失败，R45 停止，不能进入 independent final。校准通过
后只允许：冻结最终 source digest、运行独立 matched timing、制定新1400行最终协议。不得从
R45结果修改角窗、载波数、搜索网格、profile、选择器或 nuisance model。

## 11. 投影 Fisher 信息命题

以下结论只针对单载波条件模型

`y_m = alpha_m a_m(theta,r_F) + n_m,  n_m ~ CN(0,sigma_m^2 I)`，

且 `alpha_m` 为未知确定性复 nuisance。令

`Pi_m_perp = I-a_m a_m^H/(a_m^H a_m)`，

则消去 `Re(alpha_m), Im(alpha_m)` 后，角度的等效 Fisher 信息为

`J_theta theta^(m) = 2|alpha_m|^2/sigma_m^2 * ||Pi_m_perp partial_theta a_m||^2`。

证明要点是：完整均值导数矩阵由 `alpha_m partial_theta a_m` 与 nuisance 方向
`a_m, j a_m` 组成；对 nuisance block 作 Schur 补，等价于把角度导数正交投影到
`span_C{a_m}` 的补空间。各载波独立时信息相加。因此，`P_FA` 的角度目标与“消去逐载波
未知复增益后的有效角度信息”一致，而不是把未知增益当作已知。

在居中 ULA 的远场主项

`[a_m]_n = N^(-1/2) exp(-j k_m x_n sin(theta))`

下，`sum_n x_n=0` 使 `a_m^H partial_theta a_m=0`，从而

`||Pi_m_perp partial_theta a_m||^2
 = k_m^2 cos^2(theta) * d^2 (N^2-1)/12`。

若只改变孔径长度、保持每载波阵列输出 SNR、载波集合和 nuisance 定义相同，则几何信息比为

`J_N/J_L = (N^2-1)/(L^2-1)`，代入 `N=256,L=160` 得 `2.5601`。相应局部标准差的理想
下限比为 `sqrt(J_L/J_N)=0.625`。这只是同条件局部信息上限；P_A 的空间平滑包含重叠子阵、
协方差构造和有限样本特性，故不能预言实际 RMSE 必然改善37.5%。R45 的 `<=0.85` MSE
门槛远弱于理想几何比，目的是验证可重复收益而不是追逐该上限。

## 12. 顺序结构的理论角色

`P_FA` 不是 `P_A+G`，也不是对 `P_A` 输出的后处理：

1. `P_A`：L06 后执行 `L=160` 空间平滑一维 MUSIC，再执行一次 q-only 距离 profile；
2. `G`：必须先完整执行 `P_A`，再在 P_A 最终邻域执行一次全孔径角度修正，并传递距离；
3. `P_FA`：L06 后直接执行 `N=256` 条件投影角度，再执行一次原 q-only 距离 profile，
   不生成 P_A 的 MUSIC 状态、角度网格或输出。

因此三者共享“先角度、后条件距离”的顺序思想和同一 q 后端，但计算图不同。`G` 回答“P_A
结果还能否低成本修正”，`P_FA` 回答“是否可从前端直接避免空间平滑孔径损失”。只有后者能
形成 PA-free 的孔径机制消融。

顺序结构成立所需的不是角度和距离严格统计独立，而是两个局部稳定条件：角度阶段对前端
距离误差的偏移由 `|S_theta r/S_theta theta|` 控制，距离阶段对角度误差的偏移由
`|J_r theta/J_rr|` 控制。R45 通过逐样本有限性、边界命中、角度与距离 MSE 以及尾部分位数
间接检验这些条件；它没有逐样本 Hessian 证书，故通过后仍只能称为冻结区域内的经验稳定。

## 13. 对 Zhang2026 攻击的分层映射

| 攻击命题 | P_A 的作用 | P_FA 通过 R45 后可增加的作用 | 仍不能声称 |
|---|---|---|---|
| 峰值子载波/一维轨迹不足以唯一确定二维位置 | 主证据：使用完整 q 频谱恢复距离，并已有独立最终验证 | 同样保留完整 q 频谱，可作架构复现 | 不能由 P_FA 再次证明全局不可辨识；该结论来自既有理论与无噪声审计 |
| 局部二维 MUSIC 不是获得高精度角距的必要结构 | 主证据：一维 MUSIC + 条件 profile 已在1400行中成立 | 更强机制证据：连 MUSIC/EVD 都可移除而保持/改善精度 | 不能推出所有联合估计都无效，也不能否认联合 ML 在匹配模型下的效率 |
| 空间平滑造成角度孔径损失 | P_A 自身仍用 L160，不能直接支持 | 直接机制消融：N256 条件投影对 L160 P_A 的配对角度改善 | 不能把有限样本改善写成普遍的 N/L MSE 定理 |
| nuisance model 必须显式说明 | P_A 的 MUSIC 与 q 后端隐含不同统计处理 | P_FA 明确逐载波复增益投影及其相位不变性 | 不能声称对阵元相位误差、CFO、异步 q 距离、多径或硬件失配稳健 |
| 条件距离 profile 可替代局部二维距离网格 | P_A 的最成熟主证据 | 若距离非劣，说明更换角度前端后该后端仍稳定 | 不能声称 q profile 在每个 SNR/每个用户都严格改善距离 |

所以即使 R45 全部通过，论文主攻击依据仍应是 `P_A` 的独立最终证据；`P_FA` 的新增价值是
把“二维 MUSIC 非必要”进一步拆成“空间平滑孔径损失”和“逐载波 nuisance 消元后完整孔径
仍可辨角”两个机制证据。若 R45 失败，P_A 的既有攻击结论不受影响，只能否定当前 P_FA
参数化在预声明区域内足够稳定。

## 14. 理论严谨性的结论边界

当前理论可以严格支持：目标函数是逐载波复增益消元后的集中似然；其对逐载波公共相位严格
不变；局部角度有效信息由投影导数决定；完整孔径在同条件远场主项下具有2.5601倍几何信息；
顺序误差传递可由两个隐函数导数刻画。

当前理论不能严格支持：全局唯一收敛、所有位置均优于 P_A、距离逐样本非劣、统一 z+Y
似然最优、未知时延下 q 距离可辨，以及真实 RF 能量公平。故“理论严谨”应表述为：方法定义
与局部机制严谨，性能结论仍需 R45 和后续独立最终试验限定；不能在 R45 前写成已充分验证。
