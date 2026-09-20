# R35 方向四：前端、子空间与可兑现的计算收益

本轮为R35探索研究；六个固定几何/SNR工况不构成总体性能或独立优效证据。原P_A、原R34结果及research/01–68均保留。

## Amdahl界约束了下一步能获得的收益

按旧R33的完整在线计时，P_A的front占44.17%，subspace占39.02%，angle search占4.63%，profile占7.67%。单独无限加速某个模块时，其余成本仍然存在：

| module | fraction | totalSpeedup |
| --- | --- | --- |
| front | 0.441705 | 1.79117 |
| subspace | 0.390153 | 1.63976 |
| angle_search | 0.0463185 | 1.04857 |
| profile | 0.0767418 | 1.08312 |
| front_plus_subspace | 0.831858 | 5.94737 |

消除全部angle search的理论完整加速上限仅约1.049倍；因此评分点下降96.98%不能再用作剩余在线加速的依据。front+subspace的上限约5.95倍只是令两模块成本为零的数学情景，不是可实现预测。

## Matrix-free eigs原型与实测

当前aligned矩阵X是160×97。新原型用v↦X(X^Hv)/P作用，不显式构造160×160协方差，并请求两个最大特征对以记录谱隙。固定Tol1e−13、MaxIterations300、初向量全1归一化。每个新工况取首/中/末3载波，共18矩阵；每方法一次预热、交替顺序3次正式计时。计时包括该求解器诊断开销，是局部微基准，未测完整2047载波方法路径。

| metric | value |
| --- | --- |
| measured_matrices | 18 |
| matrix_free_speedup_min | 0.144248 |
| matrix_free_speedup_median | 1.47586 |
| matrix_free_speedup_max | 2.07726 |
| geometric_score_gate_pass | 11 |
| algebraic_stress_gate_pass | 10 |
| maximum_geometric_score_error | 2.03517e-11 |
| maximum_stress_score_error | 1.60944 |

完整18行见[微基准CSV](../research_extensions/r35_five_directions/results/subspace_microbenchmark.csv)，aligned矩阵、两法3次原始时间与残差在case MAT中。speedup=direct中位时间/matrix-free中位时间，小于1就是更慢。MATLAB官方文档明确，小型稠密问题用eigs不一定比eig快；收敛flag与残差必须检查。[MathWorks eigs](https://www.mathworks.com/help/matlab/ref/eigs.html)

## 为什么小投影差仍可能有明显谱分数差

设Pi=uu^H，d(a)=max(1−a^HPi a,eps)。单位范数a下

$$|a^H(\widetilde\Pi-\Pi)a|\le\|\widetilde\Pi-\Pi\|_2,$$

$$|\log\widetilde d-\log d|\le\frac{\|\widetilde\Pi-\Pi\|_2}{\min(d,\widetilde d)}.$$

因此极小MUSIC分母会放大机器精度级投影扰动。几何网格评分比较与额外的“把两法u/v自身当探针”代数压力测试分开保存。后者不代表真实Fresnel流形上的典型角度，但可说明截断分母的数值敏感性；不能把它混称为18个用户定位错误。

特征残差很小也不单独证明得到了唯一稳定的最大特征方向：还需主特征值身份与谱隙。Davis–Kahan类结果为子空间扰动与谱隙之间的关系提供理论背景，但本轮没有建立全输入、严格舍入误差界。[Yu、Wang与Samworth](https://arxiv.org/abs/1405.0680)

## 决策

原R33 Gram失败记录不变，冻结实现继续direct EVD。新matrix-free模块仅是研究原型；18矩阵的局部速度或分数通过都不足以取得全路径数值等价身份，更没有全2047载波、最终定位输出和完整在线计时证据。

前端方面，本轮落实成本瓶颈与响应调用账目，没有将新的批量求和/精度压缩偷偷替换进L06。后续若优化前端，应先保持候选、载波、求和/评分定义和退出规则，记录实际response calls与峰值内存，再按同输入数值回归评价；R30少载波失败不能被忽略。
