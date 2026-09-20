# 最终创新点与四项论文贡献

日期：2026-09-11。这是研究贡献的归纳，不宣称已经完成外部文献范围内的首创性证明。原论文贡献先按[全文回顾](../paper_support/zhang2026_full_review.md)准确陈述；证据映射见[claim_evidence_matrix.csv](../paper_support/claim_evidence_matrix.csv)。

## Contribution 1 — Coarse-center-induced localization constraints

Identify coarse-center-induced localization constraints in local joint angle-distance MUSIC refinement.

创新内容是把“joint变量形式”与“依赖随机coarse center的实际可行支持”分开。论文可从受约束argmax与truth-outside-support的集合事实出发，再以历史控制实验和预定final case说明其工程表现。需要同时承认原论文已讨论窗宽权衡；贡献是进一步拆解并验证这种剩余依赖，不是宣称首次发现局部窗可能失捕。图1、2、S1支持；Hessian主导假设已被拒绝。

## Contribution 2 — Information-role-separated architecture

Introduce an information-role-separated architecture: complex wideband spectrum for the front-end range information, MUSIC spatial subspaces for high-resolution angle, and conditional complex-spectrum profiling for the final range.

P_A先用L06有限复谱前端，随后固定front range执行1-D angle MUSIC，再固定angle用±2m物理裁剪域内的full-spectrum profile估计range。λ=1，不含旧alpha、门控、学习或收缩。Y空间统计与z相干宽带统计承担不同作用；不能称同一信息上的纯目标理论优越。H_A是必要消融；最终10–20dB profile没有净RMSE收益。图3、5、6与S3支持。

## Contribution 3 — Localized MUSIC search reduction with angle preservation

Reduce localized MUSIC from a two-dimensional angle-range search to an angle-only search while preserving angle performance under the frozen configuration.

冻结K2047/L160、±0.2°角窗和41/31/21规则，MUSIC评分点3083→93（−96.98%）。R31隔离了删range维与少载波信息损失；R34七SNR角度MSE统计非劣，1398/1400估计角度完全相同。有限离散充分条件可辅助解释，不能写成连续域精确解耦。R33仅q-only复用被接受；Gram仍拒绝。图4、7与S2支持。

## Contribution 4 — Frozen independent accuracy–complexity evidence

Demonstrate accuracy–complexity gains with a frozen independent 200-position × 7-SNR evaluation.

最终1400个配对trial中，P_A对strengthened Zhang-style executable baseline的range RMSE七点数值下降3.05%–49.63%；预声明单侧同时上界仅在0/15/20dB支持range MSE优效。冻结计时另给完整在线均值下降50.1923%，不得与评分点降幅混用。P_A比transparent-assumption baseline慢2.2453倍，但0dB range RMSE为0.014037m对0.844860m。图3–8支持，runtime与accuracy来自不同冻结协议。

## 贡献之外必须保留的内容

R30六候选失败、R33 Gram失败、前端未全局闭合、高SNR profile小幅负变化、低SNR重尾及未建立优效的四点，都与贡献同时报告。同步LoS单径、公共时延已校准、条件z+Y与未统一RF/总能量采集限制进入方法和实验设置；不能只放脚注。R34流程偏差保留在复现材料。无需新增试验来使上述叙述更好看。
