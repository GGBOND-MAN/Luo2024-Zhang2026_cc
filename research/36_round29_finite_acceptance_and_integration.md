# Round29：有限候选验收与一般化前端接线

日期：2026-09-07。本文追加纠正，不覆盖 research/32–35 或任何旧结果。

## 结论纠正

9个定向用户的SNR分布是6/2/1，其合并RMSE不是总体性能。
200/400/800下选中解稳定，不等于全部候选收敛或全局搜索完成。
36200114说明我们自己的旧前端存在候选遗漏，不能直接解释为MUSIC的理论缺陷。
research/34的30用户smoke属于旧前端v1，600用户正式机制消融尚未执行。

原 serial_thread_check.csv 的 withinTolerance=0 原样保留。
候选角度阈值1e-10度和选中角度阈值1e-7度均失败，而非仅前者。
新增工程分析采用评分差1e-10、角度差1e-6度、距离差1e-5m；
另用0.01度/0.01m判断模态变化。这些是不同量纲的检验，
不把角度容差和投影驻点残差相比较，不将事后工程容差写成旧预注册检查通过。

## 固定工作量

对36200034、36200114、36200073、36200127进行一次2x2敏感性分析：
距离间距0.05/0.025m，峰预算16/32。复用4份基准结果，只新增12个任务。
新增任务保留基准候选库，属于可追溯的增广诊断，不声称纯粹改变单一网格参数。
只做最终200次分支；选中解不驻定，或发现更高评分新模态时，
只对该竞争解继续400/800，不要求低评分候选全部收敛。
若有高评分新模态，采用预定最密0.025m/32峰参考配置；
否则采用0.05m/16峰。两种情况都停止加密，不用真值误差选择配置。

## 一般化入口

`r29.front(cfg,z,scan,protocol)`没有seed参数，不读取CSV或历史定位结果。
锚点政策是none，正式入口不调用旧多峰宽括区fminbnd。
历史锚点仅在敏感性诊断中使用；新入口不冒称与R28前端v2完全相同。
版本是R29-observation-only-reference-v1，定位为数值参考前端，不是低成本部署算法。
候选生成、第一阶段200次、前端角度剖面、最终200次和选中解续算分别记录响应次数和时间。
无离线候选缓存，缓存生成成本为0；各任务的观测重放成本另列。

## 真正后端接线

每用户重放相同z/Y，计算一次F*，用固定的Zhang-R26后端配置计算一次新的二维MUSIC。
其几何补偿随F*更新；载波仍按同一z峰载波选取（不是使用真值或旧C的载波）。
随后直接使用该次MUSIC返回的signalVectors，不重新计算特征向量，
冻结角度、载波、补偿粗点、参考子阵、单位范数导向和几何平均融合。

输出E*、C*、H*、Mn、Pn、Mw、Pw、PF*及独立扩窗公共终域M/P。
窄窗按MUSIC累计位移并裁剪物理范围；宽窗是F*距离的正负2m。
M/P使用相同可行候选（F*与C*距离）、初始网格、峰数、连续求解器和端点规则；
只目标及统计信息不同。连续MUSIC使用原始批次无关log谱。
Mn与C*仍混有一维连续细化和多级二维搜索路径差异，不称为纯耦合效应。
扩窗只按端点及向外走势触发2/4/8m，最终M/P使用相同公共区间。

## Pilot与后续

从已有600行按SNR、trialIndex排序，每档选择最早20个非9-seed用户。
共60行，不按误差筛选，属于开发校准数据，不是独立验证。
只跑一次新前端与后端接线pilot；第一个用户另外作串行/线程复现诊断。
验收基于执行正确、公共冻结状态、选中解驻定和复现容差，不依赖Pw获胜。
600用户是机制审计，需人工运行；不自动启动1000或10000用户/SNR。
后续独立验证不得使用R26剩余校准行或Round24保留seed冒充新样本。

所有新完成标志和checkpoint验证完整version/config/design/data/source/shard身份。
旧入口原样封存，其中仅凭seed短路的完成标志不应用于新实验。
失败、异常、尾部样本保留；若有执行失败，不输出删掉失败行后的性能表。
每档样本数预固定，无显著性提前停止。主比较Pw-Mw的三个SNR使用Holm校正；
bootstrap区间和校正p仅作当前校准数据描述，不升级为独立验证证据。

## 模型与信息边界

z由精确球面标量扫描响应生成，跨载波公共复增益为单位幅度随机相位；
Y使用Fresnel阵列响应与随后独立噪声抽样，z/Y并不是同一次数字阵列接收的两个表示。
条件于真实用户，噪声抽样相互独立；全流程仍从固定seed重放。
prepareScan使用理想已知逐载波球面聚焦波束。z的SNR按平均扫描响应能量除噪声方差定义；
Y按每阵元单位信号幅度和标称噪声定义。这不是已统一发射能量的硬件端到端口径。
路径损耗、实际波束增益、RF链、模拟合并、时隙和总能量尚未统一建模，必须保留假设。
公共复增益可吸收公共初相，不能吸收未知公共时延产生的跨频线性相位。
已有随机相位/Wiener测试不能替代未知时延审计。
同窗P优于M只能说明当前不同信息与统计后端组合的差异，不是同信息下纯目标优势。
z的EFIM不是使用z+Y的混合估计器的下界。本阶段不扩展多径。

## 命令

在含matlab目录的工程/服务器包根目录运行：

```powershell
matlab -logfile round29_preflight.log -batch "addpath('matlab/experiments'); preflight_round29"
matlab -logfile round29_sensitivity.log -batch "addpath('matlab/experiments'); run_round29_sensitivity(NumWorkers=8)"
matlab -logfile round29_pilot.log -batch "addpath('matlab/experiments'); run_round29_shard(1,1,Mode='pilot',NumWorkers=8,BatchSize=8)"
matlab -logfile round29_replay.log -batch "addpath('matlab/experiments'); check_round29_pilot_replay"
matlab -logfile round29_pilot_summary.log -batch "addpath('matlab/experiments'); aggregate_round29('pilot')"
```

仅验收通过后，两台32线程服务器各自预检，然后分别运行：

交付包已经包含严格校验的60行pilot缓存，每片复用30行，仅新增270行；
复用来源和原本地环境记录在reuse_provenance.mat。未启动任何600行计算。
当前命令BatchSize=16，最多并发16个用户；NumWorkers=32是池容量，
并不意味着每个批次都同时运行32个用户。

```powershell
matlab -logfile round29_600_shard1.log -batch "addpath('matlab/experiments'); run_round29_shard(1,2,Mode='calibration600',NumWorkers=32,BatchSize=16)"
matlab -logfile round29_600_shard2.log -batch "addpath('matlab/experiments'); run_round29_shard(2,2,Mode='calibration600',NumWorkers=32,BatchSize=16)"
```

将两个分片目录放入相同matlab/results/full_spectrum/round29_calibration600_v1后汇总：

```powershell
matlab -logfile round29_600_summary.log -batch "addpath('matlab/experiments'); aggregate_round29('calibration600')"
```

结果包含原始观测、RNG、冻结子空间、全部前端候选与轨迹、方法/配对统计、
分位数、1m失捕、逐样本胜率、尾部贡献、位置误差、模块成本、失败清单、环境与源码哈希。
实际运行状态另写执行记录，本文不将已准备代码当作实验通过。
