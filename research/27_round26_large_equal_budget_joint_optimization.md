# Round 26：两服务器大规模同预算联合寻优协议

## 1. 目标与冻结规则

Round 26 对 Zhang 复现和 FSJAD 分别做一次同等级的全参数联合 Monte Carlo 寻优。
“全参数”表示覆盖各方法已定义的全部未知参数维度及离散层级，不表示穷举完整笛卡尔积。
寻优得到的是本仿真模型和搜索空间下的最优复现参数，不应表述为恢复了原作者未公开参数。

两种方法使用完全相同的校准用户、噪声 seed、候选数和 successive-halving 预算：

- SNR：`-10/0/20 dB`；
- 随机角度：`[-55,55] deg`；
- 随机距离：`[17,48] m`；
- 每档 SNR 校准样本：1000；
- 联合候选数：136；
- 累计样本阶段：`67 -> 333 -> 1000`；
- 保留候选：`136 -> 32 -> 8`；
- 校准 seed 根：`36100000`；
- 独立中间验证：每档 SNR 200，seed 根为 `37100000`；
- 运行时间不参与候选排序。

每种方法的样本-配置评估总数严格为：

```text
136 * 67 * 3 + 32 * (333 - 67) * 3 + 8 * (1000 - 333) * 3
= 68880
```

最终 Round 24 的 10000 次/SNR 确认实验使用另一组 seed，不能用于修改 Round 26 参数。

## 2. 两台服务器运行

两台服务器均应放置完整项目目录，并进入：

```text
Beam Squint Assisted Joint Angle-Distance Localization for Near-Field Communications
```

服务器 1 只运行 Zhang 联合寻优：

```powershell
matlab -batch "addpath('matlab/experiments'); run_round23_zhang_joint_mc_optimization(Protocol='large',NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

服务器 2 只运行 FSJAD 联合寻优：

```powershell
matlab -batch "addpath('matlab/experiments'); run_round25_fsjad_joint_mc_optimization(Protocol='large',NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

`NumWorkers=12` 是保守起点，`BatchSize` 建议不小于 worker 数，才能让全部 worker 同时工作。
若服务器物理核心和可用内存充足，可同步增加两者；若线程池不兼容，把
`PoolType='Threads'` 改为 `PoolType='Processes'`。进程池通常占用更多内存。

脚本每个 batch 保存检查点。中断后不要删除结果目录，使用完全相同的命令即可续跑。
不要修改协议、worker 以外的算法代码后继续复用旧检查点。

## 3. 输出目录和版本

服务器 1 输出：

```text
matlab/results/full_spectrum/round26_zhang_large_joint_mc/
```

锁定版本为 `Zhang-EF-JointMC-R26-locked`。

服务器 2 输出：

```text
matlab/results/full_spectrum/round26_fsjad_large_joint_mc/
```

锁定版本为 `FSJAD-JointMC-R26-locked`。

运行结束后应保留并回传整个目录。至少需要：

- `selected_algorithm.mat`；
- `selected_configuration.csv`；
- `stage1_screen.csv`、`stage2_screen.csv`、`stage3_screen.csv`；
- `candidate_membership.csv`；
- `protocol.csv`；
- `calibration_design.csv`、`validation_design.csv`；
- `comparison_summary.csv`、`paired_summary.csv`、`seed_audit.csv`；
- 各自的完整优化 `.mat` 文件。

FSJAD 目录还应包含 `mechanism_summary.csv`。检查点建议一并保留，以便异常审计或续跑。

## 4. Round 24 前的文件汇合

在运行最终 10000 次/SNR 验证的每台服务器上，必须同时具备：

```text
matlab/results/full_spectrum/round26_zhang_large_joint_mc/selected_algorithm.mat
matlab/results/full_spectrum/round26_fsjad_large_joint_mc/selected_algorithm.mat
```

Round 24 会校验两个版本字符串。任一文件缺失或版本错误都会停止，避免误用旧 Round 23/25
参数。只有两份 Round 26 结果完成审计并汇合后，才启动 Round 24 分片。
