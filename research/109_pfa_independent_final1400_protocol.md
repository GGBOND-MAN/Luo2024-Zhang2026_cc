# P_FA 独立最终对比协议 R46

日期：2026-09-17  
协议版本：`R46-PFA-independent-final1400-v1`  
状态：**协议冻结草案；尚未授权或执行最终 trial**

## 1. 冻结对象

主候选固定为 `PFA-full-aperture-sequential-v1`：

`L06 q-only front -> K2047/N256 per-carrier-gain concentrated angle -> one unchanged q profile`。

冻结校准源码摘要为
`f1483ec49bb59907a9b5b2f70aa95459f11277450a0bbcf715a43b3324439868`。
R46 前置检查必须确认 `+r45` 方法源码及全部运行依赖与该摘要一致。计时驱动和结果报告不是
算法定义；不得借协议实现修改角窗、载波数、导向模型、优化器、profile或候选保留规则。

## 2. 全新独立设计

- 200个新位置；`theta ~ Uniform[-60,60] deg`，`r ~ Uniform[15,50] m`；
- position RNG：`mt19937ar`，seed `61000000`；
- SNR：`[-10,-5,0,5,10,15,20] dB`；
- 每个位置跨七SNR复用，形成1400行；统计簇为 `positionId`；
- trial seed root：`61100000`，规则
  `seed = 61100000 + 100000*snrIndex + positionId`；
- bootstrap seed：`61200000`，20,000次整位置重采样；
- 与R34、R41、R42--R45的设计和seed完全分离。

设计生成后立即写入 `design.csv`、design hash和protocol hash。最终授权前只允许做结构预检，
不能生成观测、试跑最终seed或查看误差。

## 3. 方法与执行

每个 trial 在同一观测上输出：

1. `P_FA`：主候选；
2. `P_A`：主参照与主攻击基线；
3. `G_schur`：已独立验证的 P_A 后处理参照；
4. `C_enhanced`：强化 Zhang-style 二维 MUSIC 参照。

精度运行可共享数学上完全相同的 L06 前端和冻结 A-only baseline kernel，以降低服务器成本；
共享不改变任何方法的估计值，也不得用于完整入口计时。P_FA 只能从公共 L06 front、当前 `z/Y`
和已知配置出发，不能读取 P_A/G/C 的最终角度、距离、MUSIC state或grid。

执行分为两个700行分片，每个分片包含100个完整位置和全部七SNR。检查点只能在 source digest、
protocol hash、design hash、shard hash和统计摘要完全一致时恢复。任一 trial 失败即停止主推断，
不得只重跑不利seed或删除尾部。

## 4. 共同主要终点

R46 只有同时通过以下两个 co-primary families 才判定最终成功。

### 4.1 角度优效

对每个SNR计算

`R_theta,s = MSE_theta(P_FA,s)/MSE_theta(P_A,s)`。

按位置整簇bootstrap，并在七SNR的 log-ratio 上构造单侧 simultaneous max-statistic 上界。
由于有两个共同主要家族，每个家族使用 `97.5%` 单侧同时上界。七个SNR必须全部满足

`U97.5(R_theta,s) < 1`。

任何SNR未通过，只能报告未建立全SNR角度优效；不得改成聚合通过来救回主结论。

### 4.2 距离非劣

同样定义

`R_r,s = MSE_r(P_FA,s)/MSE_r(P_A,s)`，

并要求七个SNR的单侧 simultaneous `U97.5` 全部满足

`U97.5(R_r,s) < 1.02`。

2%是校准前已采用的MSE非劣 margin。最终数据不得缩放或放宽该界。

### 4.3 联合判定

只有角度优效 family 与距离非劣 family 同时通过、1400行零失败、身份检查全部通过，才写：

“P_FA 在冻结单径同步条件模型和七SNR区域内，相对 P_A 建立角度MSE优效并保持距离MSE非劣。”

两个97.5% family-wise上界通过 Bonferroni 控制共同结论的单侧错误率不超过5%。

## 5. 次要与描述性终点

- equal-SNR aggregate P_FA/P_A angle/range MSE ratio及普通95% cluster bootstrap；
- P_FA 对 G_schur、C_enhanced 的逐SNR和聚合 angle/range/position 指标；
- RMSE、median absolute、P90/P95、严格W/T/L、profile边界与失捕；
- 角度改进向距离/位置的传递；
- 完整入口计时沿用 R45 已完成的独立 matched timing，不用 final shard吞吐替代。

这些终点不得替代失败的共同主要终点。若只在部分SNR通过，只逐SNR描述，不扩大成全范围结论。

## 6. 数值与身份审计

最终聚合前必须检查：

1. 200个位置、1400行、每SNR 200行、1400个唯一seed；
2. 两分片位置不重叠，行无缺失、无重复；
3. source/protocol/design/statistics/authorization摘要全部一致；
4. P_FA `musicEvaluationCount=0`、`evdCount=0`、每行一个q profile；
5. shared baseline Gram=0、fallback=0，direct EVD计数符合冻结实现；
6. P_FA候选保留margin非负，所有输出有限；
7. 从raw rows独立重算全部MSE、分位数、W/T/L和bootstrap并与结果文件一致；
8. 保存失败证据后停止，不能静默替换或重跑。

## 7. 攻击结论边界

最终通过将支持：在当前冻结模型中，Zhang-style空间平滑二维MUSIC并非必要；完整孔径、显式逐
载波复增益消元和顺序q距离后端能以更低计算量获得更好角度并保持距离。

最终通过仍不支持：作者未公开代码被严格复现、真实RF能量公平、未知公共时延下q距离稳健、
多径/阵列误差/CFO鲁棒、所有联合ML均无效或完整孔径方法普遍优于空间平滑。

## 8. 一次性规则

R46 在显式授权前的 final trial count 为0。授权后只允许一次冻结1400行执行。不得因显著性、
尾部、单个SNR、运行时间或中途日志增加样本、修改统计层级、切换G、调整P_FA或生成第二套
final seed。若共同主要终点失败，P_A继续作为主方法；P_FA保留为通过R45的机制增强结果。

