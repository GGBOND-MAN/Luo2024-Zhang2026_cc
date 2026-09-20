# Round 27：共享前端收敛修复与同角度距离消融

> **历史设计记录**：本文件包含早期 `zhang_declared_protocol` 分支。
> 该分支已在 Round 27 v3 中移至独立公式审计，不再进入正式性能比较。
> 服务器运行以 `31_round27_v3_server_protocol.md` 为准。

## 1. 四个问题的明确回答

### 外层参数寻优与内层数值收敛

Round 26 已完成的 Monte Carlo 寻优，是对载波数、子阵、窗口、网格等候选的平均风险进行比较。
但对每个候选和每个随机样本，内部仍先调用同一个复谱前端，且每个起点只迭代 12 次。
所有候选都可以完整跑完，同时仍有一部分样本的前端没有收敛。扩大外层 MC 不会改变内层上限。
“共享”表示 Zhang-EF 与 FSJAD 使用相同前端算法和同一个观测下的相同粗点，
并非两台服务器共享了一个运行进程，也不是参数寻优没有运行完。

### α 曾经推导和使用过，但不是 R26 的最终执行路径

早期分支对前端距离 r_F 与 MUSIC 距离 r_M 做融合：

`r_hat=r_F+alpha*(r_M-r_F)`。

若 e_F=r_F-r，delta=r_M-r_F，则固定权重的总体最优表达式为：

`alpha*=clip(-E[e_F*delta]/E[delta²],0,1)`。

该表达式含未知总体矩，不能仅因为有闭式表达式就认为在线已经知道最优权重。
之前用分组重复估计、协方差近似或参数化 bootstrap 估计这些量，相关代码仍在
`covarianceRangeShrinkage.m`、`groupedCovarianceShrinkage.m`、`parametricBootstrapShrinkage.m`。
其无真值实现需要偏差、相关性和重复样本代表性等假设，并无普遍最优保证。

R26 实际执行的是：先取得 MUSIC 角度，在该角度条件下得到复谱距离 r_P，然后
`r_hat=r_F+lambda*(r_P-r_F)`。lambda 是离线联合搜索的固定候选，选中值为 1。
因此最终 r_hat=r_P，既不是前端/MUSIC 距离的旧融合，也没有调用旧逐样本 alpha 估计器。
这是方法演变，前期沟通没有清楚区分版本，不能用“已完成闭式最优 alpha”概括当前成果。

### 错误与仍成立的部分

已确认的错误包括：将原文公开参数称为未知参数；把增强前端基线等同完整原文流程；
默认前端 12 次迭代足以收敛；部分理论表述过强。当前数据内部配对与预算一致，
集中似然和投影 EFIM 核心实现已有数值验证，不能因为发现这些问题就断言全部数据无效。
同样，也不能因为旧单元测试通过就断言理论和研究结论都没有问题。

### 执行顺序

先完成 R27 的收敛和消融诊断；收到服务器结果后判断剩余收益，再决定新前端下是否重调优。
本轮只用 R26 校准样本，不读取独立验证或预留 Round 24 的最终验证样本。

## 2. 新前端的数学设计

保留原有归一化集中似然 `S=|q^H z|²/[(q^H q)(z^H z)]`。
令 beta_hat=q^H z/(q^H q)，residual=z-beta_hat*q；将参数尺度设为角度 1 deg、距离 1 m。
以消去复增益后的导数 J 构造 `H=Re(J^H J)/(z^H z)` 和
`b=Re(J^H residual)/(z^H z)`，则目标梯度为 2b。

新版先算阻尼 Gauss-Newton 方向，再裁剪至物理参数边界，并通过 Armijo 回溯验证似然增加。
对所有旧多起点的最终位置继续求解，选择目标值最高的结果。新版的选中似然不得低于旧前端。
数值设置预先固定为最大 200 次迭代、投影尺度梯度容差 1e-6；这些不是依据验证 RMSE 选择的参数。

收敛只代表给定数值精度下的局部约束驻点。达到迭代上限、线搜索停滞不会被当作收敛；
诊断输出保留状态、驻点残差、所有起点收敛标志和目标历史，不声称全局最优。
未收敛但有限的样本仍纳入主 RMSE 并单独报告；有运行异常则汇总拒绝继续，不能静默删样本。

实现：`+fsjad/refineProfileMonotone.m` 和 `+fsjad/convergedFrontEstimate.m`。
旧 `refineProfileEstimate` 与旧 `angleMultistartProfileEstimate` 未更换数值行为，保留 R26 可追溯性。

## 3. 十个输出与消融含义

| 输出名 | 含义 |
|---|---|
| legacy_front | 原来的多起点、每起点 12 次迭代前端 |
| stable_front | 由所有旧起点继续求解的新前端；名字不是收敛保证 |
| zhang_r26_legacy | 直接复用原 R26 所选 Zhang 校准输出 |
| fsjad_r26_legacy | 直接复用原 R26 所选 FSJAD 校准输出 |
| zhang_r26_stable | R26 Zhang 参数搭配新前端 |
| fsjad_r26_stable | R26 FSJAD 参数搭配新前端 |
| profile_at_zhang_angle | 使用 zhang_r26_stable 的完全相同角度，重新计算条件距离 |
| profile_at_front_angle | 使用 stable_front 的完全相同角度，重新计算条件距离 |
| music_at_fsjad_angle | fsjad_r26_stable 内部同一个 MUSIC 的角度和原始 MUSIC 距离 |
| zhang_declared_protocol | 轨迹粗点、公开 L=128、公开半窗 1 deg/1 m、受限原始域 |

前端效应：比较 stable 与各自 legacy。距离目标效应：比较 profile_at_zhang_angle 与
zhang_r26_stable，以及 fsjad_r26_stable 与 music_at_fsjad_angle。
MUSIC 角度贡献：比较 profile_at_zhang_angle 与 profile_at_front_angle。

旧估计直接来自两个 R26 优化 MAT 的校准矩阵，避免不必要的重算；只在 compact smoke 中重算旧支路。
新支路共享重建的同一组观测和同一个新粗点。半窗与剖面间距沿用锁定的我方 R26 数值，
固定参数是为了隔离修改效果，不能据此称为“新实现的最优参数”。

## 4. 原文流程基线的边界

原文公开 L=128 和两个半窗 1 deg/1 m，本支路遵循这些数值以及峰值索引到轨迹粗点的流程。
融合数暂用 R26 Zhang 的 K=2047，数值网格设为 61/41/31；两者是透明的实现假设，
还不是针对原文流程完成联合寻优的配置。因此不能凭这个单配置支路声称超过最优原文方法。

为遵循原文式 (42)-(43)，后续细网格始终裁回原始搜索域；旧增强支路保持原 R26 的移动窗口规则。
MUSIC 新增了分层、分维边界诊断，默认数值搜索行为不变。条件剖面边界改用连续结果与端点的距离判断。

本轮仍使用 R26 的合成观测：公共复增益、已知相位参考的精确标量复谱，以及独立 Fresnel
阵列快拍。保留这个模型是为了隔离前端数值问题，不表示审计提出的物理获取/同步问题已经解决。
将它映射到发射波束、接收合并和实际同步结构，是后续单径模型验证的独立工作；不扩展多径。

## 5. 数据、分片与保护

每个 SNR 1000 个已有校准用户，总计 3000 个，seed 来自 R26 的 36200001..36401000 分组。
两服务器按每档 trialIndex 的奇数/偶数分片，各处理 1500 个用户，每个用户都计算相同十个输出。
不搜索新参数，不使用 600 个验证样本，也不使用 Round 24 万次预留样本。

每个 batch 保存原子替换的 checkpoint。协议、输入数据、源码内容必须与 checkpoint 一致才允许续跑。
汇总必须具备全部分片、完全相同的源码/设置、精确样本覆盖和没有异常失败。
非收敛样本保留在总指标内，同时报告收敛率；不能只挑成功收敛的样本声称总体领先。

## 6. 运行说明

两服务器均需要相同的新代码及两份原始 R26 优化 MAT。推荐上传生成的 Round 27 server bundle，
解压后进入包含 `matlab/` 的目录。

先在每台服务器执行：

```bash
matlab -logfile round27_preflight.log -batch "addpath('matlab/experiments'); preflight_round27"
```

预检包括新增 10 项测试、已有相关测试、已知异常样本重放、compact smoke、断点续跑与汇总。
只有打印 `ROUND27_PREFLIGHT_PASSED` 并生成源码匹配的 `preflight_passed.mat` 后，长实验才能启动。
若失败，请回传日志和 `matlab/results/full_spectrum/round27_preflight/`，不要反复启动长实验。

服务器 1：

```bash
matlab -logfile round27_shard1.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(1,2,NumWorkers=12,BatchSize=12)"
```

服务器 2：

```bash
matlab -logfile round27_shard2.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(2,2,NumWorkers=12,BatchSize=12)"
```

需要进程池时加 `PoolType='Processes'`。中断后原命令续跑；源码改变时不允许直接复用旧检查点。
每个分片完成后输出 `ROUND27_SHARD_COMPLETE`，目录内有 `COMPLETE.csv`。
回传两服务器日志、预检目录，以及 `round27_convergence_ablation/shard_01_of_02` 和 `shard_02_of_02`。

两分片放进同一个 `round27_convergence_ablation/` 下后，汇总命令为：

```bash
matlab -batch "addpath('matlab/experiments'); aggregate_round27_convergence"
```

## 7. 本机验证状态

2026-09-06：源码已完成手工检查，新增测试已写入，但本机 MATLAB 执行尚未完成。
自动审批拒绝沙箱外测试，理由为未能核实测试文件路径；随后只读检查确认文件存在。
受限环境内普通启动又报 `System Error: File system inconsistency`。
没有绕过拒绝重试沙箱外执行，因此本轮不能引用旧的 53/78 项测试通过记录作为新代码验证结果。
服务器预检实际通过后，才可补上本版验证结论；长任务入口已强制此条件。
