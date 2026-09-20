# Zhang-style局部精化：攻击点—证据矩阵

整理日期：2026-09-11。原论文事实核对见[全文回顾](../paper_support/zhang2026_full_review.md)。本文件中的“攻击”指可检验的剩余限制；承认原方法是joint 2-D optimization。C_enhanced固定称strengthened Zhang-style executable baseline；C_public固定称transparent-assumption baseline。

## Attack A — coarse-center-dependent feasible support

**Claim.** Joint搜索仍依赖随机粗中心，不自动免除局部化约束。

**Mathematical mechanism.**

\[
(\hat\theta,\hat r)=\arg\max_{(\theta,r)\in W(\theta_F,r_F)}J_{\rm MUSIC}(\theta,r).
\]

\(T(Y;\theta_F(Y),r_F(Y))\)是一般依赖示意；本项目更准确写\(T(Y;F(z))\)，因为前端由z构造。coarse center通过可行支持、几何补偿、据此冻结的子空间、有限网格与局部谱进入输出。改变粗中心可能同时改变补偿和可行域，不应把这种对照当作只改变一个原因。

**Supporting experiment.** R14的180机制样本及10002历史预审计显示高边界饱和；oracle-center对照显示中心依赖。R27只延长同批起点未排除候选遗漏；R28/29进一步区分驻点、wrong mode和candidate miss。

**Final independent evidence.** R34预定seed52100034的front误差1.913612m超出C的0.0025m硬窗。其后端结果仍在窗内；Figure 2给出真实支持集。它展示机制，不估计该机制在全体中的因果占比。

**Strength.** 集合与函数依赖是严格结构事实；总体主导性是有限实验解释，非全模型定理。

**Allowed paper wording.** “Joint optimization avoids the explicit substitution of a fixed angle estimate into a subsequent range estimator, but does not by itself remove the dependence of the local refinement on the coarse localization center and feasible search region.”

**Forbidden wording.** “Zhang joint MUSIC does not solve error propagation at all.” 不得把“不自动保证”写成“完全无效”。

## Attack B — truth outside local support

**Claim.** 当\(|r_F-r_{true}|>\Delta_r\)且后续始终受该硬窗约束时，true range不可达。

**Mathematical mechanism.** \(r_{true}\notin I_C\)且\(\hat r_C\in I_C\)，故\(|\hat r_C-r_{true}|\ge d(r_{true},I_C)>0\)。对历史移动窗口必须换成全部可达域；不能把R28的0.00278333m累计可达域混同R34的0.0025m硬窗。

**Supporting experiment.** R14局部窗外样本及窗口消融；R18前端严重失捕；R19无正例检测器未识别；R28/29候选遗漏诊断。

**Final independent evidence.** 固定seed52100034、−10dB：truth=16.953422m，front=15.039810m；C支持[15.037310,15.042310]m，C=15.042310m，误差1.911112m；P_A支持[15,17.039810]m（\([r_F-2,r_F+2]\cap[15,50]\)），P_A=16.884243m，误差0.069179m。原始精度值见Fig02_case.csv，不以这里的小数截断作计算。

**Strength.** 单案例中的支持排除是确定事实；P_A在该案例恢复为经验事实。没有普遍恢复保证。P_A角度域、补偿和profile中心也仍依赖前端。

**Allowed paper wording.** “In this prespecified final-test case, the strengthened baseline's frozen narrow interval excludes the true range, whereas the proposed conditional profile returns a much smaller range error within its wider, physically clipped support.”

**Forbidden wording.** “Zhang2026 uses a ±0.0025m default range window.” 原文正文约±1m；此0.0025m只属于项目strengthened C_enhanced。

## Attack C — joint search does not guarantee reliable range refinement

**Claim.** 固定相同angle与subspace时，扩大MUSIC range支持不保证距离改善，可能暴露更远的竞争模式。

**Mathematical mechanism.** 目标的最大值随可行集扩张不减，但truth误差不是被优化的目标；更高谱峰可对应更大的位置误差。MUSIC距离统计来自Y的空间子空间，profile来自z的相干宽带信息。\(J_P=\log(|q^Hz|^2/(\|q\|^2\|z\|^2))\)消去公共复增益，但不消去公共时延。

**Supporting experiment.** R28定义Mn/Pn/Mw/Pw，固定补偿、参考子阵与子空间；10/SNR smoke只作软件证据。R29正式600校准机制数据：Pw/Mw RMSE下降74.38/90.97/91.67%；三个Holm p=1.4999e−4。Mn边界549/600，Pn78/600，Mw1/600，Pw0/600；低SNR Mw失捕12/200而Pw0/200。R29 F*的600选中解驻定仍不代表全局最优。

**Final independent evidence.** R34未重复完整2×2因果消融。最终结果支持冻结整套P_A性能，不将R29机制差异升级为R34独立机制验证。Figure 2的C谱重放哈希未通过，故不使用该谱曲线；保留raw已存profile分数。

**Strength.** 开发/校准下较强受控机制证据，统计信息不同且不具独立最终身份。

**Allowed paper wording.** “They exploit different information/statistics. Under the fixed-angle, frozen-subspace development audit, wider MUSIC support exposed competing modes and did not necessarily improve range accuracy.”

**Forbidden wording.** “Under exactly identical information, our objective is theoretically superior to MUSIC.” **REJECTED HYPOTHESIS**：local Hessian angle-range cross curvature是主要失败机制。R14预测相关0.033/0.036/−0.103，固定真角度未显著改善。

## Attack D — reducing 2-D search for angle under the frozen configuration

**Claim.** 在已考虑的窄距离硬窗及冻结离散规则下，angle-only MUSIC保持角度性能。

**Mathematical mechanism.** 每层离散最佳角度评分间隔若满足\(\Delta_\ell>2\epsilon_\ell\)，其中\(\epsilon_\ell\)统一界定允许range扰动对score的变化，则该层joint最大化与固定range角度最大化选择相同角度。多层必须归纳保持相同角度网格；这是充分条件，不是所有trial已验证的证书。

**Supporting experiment.** R30少载波轻量方案主要损失角度。R31在同L06、K2047、L160下A=C角度60/60一致；仅65载波B的angle RMSE为A的7.62/5.72/2.56倍。支持删除range维和删除载波信息是不同操作。

**Final independent evidence.** 1398/1400角度完全相同；seed52102081(0dB)和52104065(10dB)均相差−0.0002666667°。七SNR angle MSE ratio同时上界均低于1.21，最大约1.113107（10dB）。一个差异P_A较准，另一个C较准。

**Strength.** 七点预声明统计非劣 + 逐trial描述事实；没有exact equivalence结论。

**Allowed paper wording.** “Under the considered narrow local range interval and frozen discrete search protocol, one-dimensional angle MUSIC preserved the angle performance of the joint two-dimensional search.”

**Forbidden wording.** “Angle and range are universally decoupled.” 也不声称连续最优解必然相同。

## Attack E — complexity

**Claim.** MUSIC角度评分点减少，并在冻结同机独立在线计时中取得实际时间收益。

**Mathematical mechanism.** \(G_C=41^2+31^2+21^2=3083\)，\(G_A=41+31+21=93\)，评分点降\(100(1-93/3083)=96.98\%\)。所有方法统一采用单信号向量内积\(O(KGL)\)。共同前端、补偿、协方差、direct EVD仍保留，P_A增加profile。

**Supporting experiment.** R20/21历史网格压缩不可作为最终配置。R33接受q-only/invariant reuse；Gram B/AB虽输出相同，但score差1.480e−12超过预冻结1e−12，保持REJECTED。

**Final independent evidence.** 精度用R34；时间使用独立冻结R33 timing协议，3个0dB位置×3重复/方法，共9次/方法，均从当前z重算完整路径。均值C_public4.067596s，H_A8.458548s，P_A9.133054s，C_enhanced18.336638s。P_A对C完整runtime降低50.1923%，仍是C_public的2.2453倍。两类证据不是同一批runtime users。

**Strength.** 搜索点数为精确计数；时间为有限机器上的实测描述，不是阶数、RF时延或作者代码收益。

**Allowed paper wording.** “The MUSIC score grid was reduced by 96.98%; complete online runtime was reduced by 50.19% relative to the equally optimized strengthened baseline in the frozen timing protocol.”

**Forbidden wording.** “96.98% total complexity reduction”; “lower complexity than Zhang2026 author implementation.”

## Attack F — limitations of our method

**Claim.** Profile的增量收益不是每个SNR必需；所有机制和性能结论有模型及统计边界。

**Mathematical mechanism.** 定义\(100(\mathrm{RMSE}_{H_A}-\mathrm{RMSE}_{P_A})/\mathrm{RMSE}_{H_A}\)。正值为改善，负值为退化；它是描述性量，不是另一个预声明优效家族。

**Supporting experiment.** R29 Pw对H*在20dB退化2.02%；R32±0.1ns对应约±0.03m距离平移。完整复谱依赖校准时间参考；P_A仍受有限候选与有限支持约束。

**Final independent evidence.** −10/−5/0/5/10/15/20dB的相对改善为+40.71/+15.98/+41.22/+1.83/−0.72/−0.56/−0.14%。高SNR front已准确，P_A对C优势主要与避免C narrow range update相关，不能说profile普遍超过front。低SNR对C严格胜率仅47.5%，40.54% RMSE改善主要由尾部驱动。统计优效只在0/15/20dB建立。

**Strength.** Final描述性消融与预声明主家族结论；高SNR小负差不构成普遍“有害”论证。

**Allowed paper wording.** “The conditional profile provides substantial gains at low-to-moderate SNR, whereas its incremental benefit becomes negligible at high SNR where the front-end range estimate is already accurate.”

**Forbidden wording.** “profile universally beats front range”; “multipath robust”; “robust to timing offset”; “hardware validated”。这些词只作为被禁止的主张出现。

适用范围：synchronized LoS single-path；common delay calibrated；conditional z+Y（z exact spherical，Y Fresnel，噪声条件独立）；尚无统一physical RF/total-energy acquisition proof；不主张多径或异步性能。原文已公开顺序RF获取，不应再把旧未说明指控写进攻击矩阵。最终server2预检流程偏差和aggregate元数据滞后见research/62，保留原数据、不掩盖失败。
