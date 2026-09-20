# 给Claude的任务：P_FALF重尾不稳定与七SNR同时统计保证

日期：2026-09-19

请接受以下实验结果为既定事实，不要重新解释R55为PASS，也不要建议删除尾部、修改R55 Gate或
重新运行R55。目标是提出一个新的、理论可辩护的距离后端，使P_FA角度完全保持，同时降低
P_FALF的有害峰切换和逐SNR方差。

## 1. 当前方法

### P_A

流程：L06前端 -> L160空间平滑一维MUSIC角度 -> 固定角度的exact-q距离profile。

P_A是当前主方法和主攻击依据。相对强化Zhang-style二维MUSIC基线C_enhanced：

- 聚合角度MSE比1.0，角度输出相同；
- 聚合距离MSE比0.35550；
- 距离RMSE改善40.38%。

### P_FA

流程：L06前端 -> N256全孔径、每载波复增益消元的条件投影角度 -> 与P_A相同的硬角度q-only
距离profile。

R46 final-1400已经建立P_FA相对P_A的七SNR角度优效，聚合角度MSE比约0.4257。距离与P_A
工程上接近，但没有建立预声明2%同时非劣。

R50 oracle-angle诊断证明：正常局部支持内，即使使用真值角度，q-only距离MSE也几乎不变；
角度传导项通常只占距离MSE的约1e-5至1e-3。因此继续提高角度不能解决距离瓶颈。

### P_FALF

P_FALF严格保持最终角度：

\[
\hat\theta_{FALF}=\hat\theta_{FA}.
\]

固定该角度后，标量z块为：

\[
E_z(r)=\|z\|^2-\frac{|q(\hat\theta_{FA},r)^Hz|^2}{\|q(\hat\theta_{FA},r)\|^2},
\qquad
\ell_z(r)=-M\log(E_z/M).
\]

阵列Y块对每载波独立复增益解析消元：

\[
E_Y(r)=\sum_m\left(\|y_m\|^2-
\frac{|a_m(\hat\theta_{FA},r)^Hy_m|^2}{\|a_m(\hat\theta_{FA},r)\|^2}\right),
\]

\[
\ell_Y(r)=-NK\log(E_Y/(NK)).
\]

联合距离目标：

\[
\ell_{FALF}(r)=\ell_z(r)+\ell_Y(r).
\]

距离支持、粗网格、保留峰数和fminbnd均与P_A相同。没有融合权重、温度、selector、扩大窗口
或SNR规则。

## 2. 数据模型审计

当前仿真中z和Y不是同一噪声样本：它们使用同一个确定性随机流中不重叠的随机抽样，因此条件于
真实theta和r时可以因子化。z使用exact spherical响应，Y由Fresnel响应生成。该独立性只在当前
混合仿真中成立；真实系统若z=b^H Y，则不能直接相加似然。

theta_FA由Y估计后，Y又进入距离目标，所以P_FALF是conditional plug-in concentrated
likelihood，不是外部已知角度下的完整联合ML。

## 3. Development与Calibration

### R53 development-90

- P_FALF/P_A聚合距离MSE比0.65293；
- 三个SNR比值0.64827/0.94855/0.85772；
- 预声明development Gate通过；
- 但bootstrap区间很宽，收益由6个-10 dB换峰行主导。

### R54 calibration-600

- all-600聚合距离比0.61014，cluster U95=0.83459；
- holdout-540聚合距离比0.59633，U95=0.87094；
- -10/0/20 dB比值0.60781/0.91446/0.90220；
- all-600和holdout-540全部校准Gate通过；
- 18/600行发生q峰身份变化；
- 换峰贡献约86%的净改善，但非换峰行也有净改善；
- leave-one-position-out最坏比值0.77262。

## 4. R55 Final-1400

执行身份完整：1400/1400成功，0失败，角度逐行等于P_FA，direct EVD=2,872,800，Gram=0，
fallback=0。

### 距离点估计

| SNR | P_FALF/P_A距离MSE | simultaneous U97.5 |
|---:|---:|---:|
| -10 | 0.69933 | 0.87677 |
| -5 | 0.93875 | 1.17694 |
| 0 | 0.86552 | 1.08514 |
| 5 | 0.87349 | 1.09512 |
| 10 | 0.89120 | 1.11733 |
| 15 | 0.96699 | 1.21236 |
| 20 | 0.85850 | 1.07633 |

equal-SNR聚合距离MSE比0.71913，cluster U95=0.84935，因此预声明聚合优效PASS。但七SNR
simultaneous 2%非劣家族只有-10 dB通过，正式primaryPass=false。

共同simultaneous临界放大因子为1.25374。当前200位置规模下，要通过共同上界，观测比值需
大约低于0.8136。

### 单档只读诊断

单独97.5%上界：-10/0/5/10/20 dB低于1.02；-5 dB为1.1157，15 dB为1.0571。
因此主要薄弱档是-5和15 dB，正式共同校正又把其他档一并判为FAIL。

### 重尾机制

- 聚合W/T/L为757/1/642；
- top 1%的14行贡献绝对配对差的71.1%，并贡献净改善的102.7%；
- 删除top-14后MSE比为1.0122；
- |r_FALF-r_FA|>0.1 m的31行贡献净改善-0.8859 m^2，其余1369行贡献-0.1330 m^2；
- leave-one-position-out比值始终低于1，范围0.7005至0.7563；
- 方法不是单个位置主导，但聚合收益主要由少数大幅峰切换产生；
- 同时存在有害切换，例如P_A误差接近0时，P_FALF被Y证据推向0.1至0.35 m外的峰。

## 5. Y-only与信息瓶颈

Y-only距离估计在R54中的聚合MSE约为P_A的6.54倍，说明每载波自由复增益消元后，Y本身不是
可靠距离估计器。P_FALF的成功来自z主导下Y对竞争峰的弱重排，而不是Y替代q。

当前每载波自由alpha_m消除了跨载波公共相位中的主要距离信息。R43曾表明相干Y距离非常强，
但对残余时延和时钟偏差敏感。若恢复低维跨频相位模型，必须解决公共时延tau与传播距离r的
可辨识性冲突。

## 6. 相对强化Zhang-style基线

使用R55相同1400行：

| 方法 | 聚合角度MSE比 | 角度RMSE改善 | 聚合距离MSE比 | 距离RMSE改善 |
|---|---:|---:|---:|---:|
| P_A/C_enhanced | 1.0000 | 0% | 0.35550 | 40.38% |
| P_FALF/C_enhanced | 0.42094 | 35.12% | 0.25565 | 49.44% |

C_enhanced是强化Zhang-style可执行基线，不是原作者提供的代码。

## 7. 已失败或停止的路线

- P_FAM5/GH局部角度边缘化：对距离只有微米到亚毫米移动；
- 单纯扩大角度或距离窗口：增加错误全局峰；
- R51/R52证书恢复：开发Gate失败，无法稳定检测range-only错误；
- Y-only phase-invariant距离：明显失败；
- R42无约束Y+z联合搜索：Y重排q模式后距离失败；
- 事后调权、SNR规则、learned selector、truth gate均禁止。

## 8. 当前准备研究的候选

暂定R56：q-anchored split-consensus likelihood fusion。

设想：

1. 最终角度严格保持theta_FA；
2. q-profile首先产生冻结的局部候选峰和盆地；
3. Y不得生成q候选集之外的新盆地；
4. 将Y载波按选中序列的奇偶位置分成两个独立噪声fold；
5. 只有odd、even和full joint三者都选择同一个q候选盆地时，才允许改变P_FA的q盆地；
6. 否则在P_FA原q盆地内做联合似然局部细化；
7. 不设分数阈值、权重、SNR规则或truth gate。

该方法试图保留低SNR有益换峰，同时阻止Y-only偏好的不稳定新模式。

## 9. 请Claude重点回答

1. R56的q锚定与odd/even/full一致性规则是否有严格统计解释，还是仍属于启发式selector？
2. theta_FA由全部Y估计后再对Y奇偶拆分，两个fold是否仍可称为独立验证？如不能，应如何构造
   真正cross-fitted的角度与距离评分，同时最终角度仍输出full-data theta_FA？
3. 是否应使用efficient score或Godambe composite-likelihood权重，修正插件角度和模型失配造成的
   过度置信？请给出可实现公式，不要建议手调lambda。
4. 如何限制Y只重排q候选而不破坏连续距离精度？盆地局部优化应使用什么数学边界？
5. 对-5与15 dB的小效果量，算法上怎样增加稳定距离信息？在当前自由alpha_m模型下是否存在
   信息论上限？
6. 若引入低维相干相位模型，tau与r如何可辨识？需要什么先验、校准或多观测设计？
7. 怎样设计新的development/calibration，使目标是降低重尾方差而不是利用少数幸运换峰？
8. 是否有比R56更简单、理论更严谨、不会读取P_A输出且保持PA-free攻击解释力的方法？

请明确区分：理论可证明的修改、合理但需实验的修改、以及不应继续的后验调参路线。

