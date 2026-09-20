# Round 24：双服务器万次确认性 Monte Carlo 协议

> 状态更新：最终验证现已要求先完成 Round 26 的双方大规模同预算寻优，并加载两份
> `R26-locked` 参数文件。运行入口和分片设计仍沿用本文，其参数冻结前置条件以
> `27_round26_large_equal_budget_joint_optimization.md` 为准。

## 1. 目的与冻结规则

本轮在 Round 25 完成后，只验证两个已经锁定的算法，不再寻优或根据结果修改参数：

- Zhang：`Zhang-EF-JointMC-R23-locked`；
- 我方：`FSJAD-JointMC-R25-locked`。

Round 24 已暂停，直至 Round 25 对我方八个设计参数完成与 Zhang 同预算的联合 MC
寻优。启动本轮前，必须把 Round 25 生成的 `selected_algorithm.mat` 放到两台服务器的
`matlab/results/full_spectrum/round25_fsjad_joint_mc/`。脚本不再接受旧的 Round 23
我方配置，以免确认集被错误版本消耗。

每档 SNR 独立验证 10000 个用户，SNR 为 `-10/0/20 dB`，共 30000 个配对 trial。角度
均匀分布于 `[-55,55] deg`，距离均匀分布于 `[17,48] m`。同一 trial 中，两种方法共享
真值、复频谱观测、完整 2048 载波阵列快照和粗前端估计。

## 2. 分片规则

两台服务器按 trial 序号交错分片：

- 服务器 1：`1,3,5,...,9999`，每档 5000 个；
- 服务器 2：`2,4,6,...,10000`，每档 5000 个。

因此每台服务器运行 15000 个 trial。seed 由 SNR 和 trial 序号确定，与服务器、worker
数量和执行顺序无关。聚合器要求两个分片的协议与冻结参数完全一致，并检查每档 SNR 的
`1:10000` 是否无重复、无缺失。

## 3. 服务器命令

在两台服务器上放置完全相同的项目目录，并进入
`Beam Squint Assisted Joint Angle-Distance Localization for Near-Field Communications`。

服务器 1：

```powershell
matlab -batch "addpath('matlab/experiments'); run_round24_confirmatory_shard(1,2,CountPerSnr=10000,NumWorkers=32,BatchSize=32,PoolType='Threads')"
```

服务器 2：

```powershell
matlab -batch "addpath('matlab/experiments'); run_round24_confirmatory_shard(2,2,CountPerSnr=10000,NumWorkers=32,BatchSize=32,PoolType='Threads')"
```

`NumWorkers=32` 应按服务器可用 CPU 核数和内存调整；两台服务器不要求相同。若 MATLAB
版本或函数不支持线程池，将 `PoolType='Threads'` 改为 `PoolType='Processes'`。恢复中断
时必须使用与首次启动相同的 shard、`CountPerSnr` 和输出目录；worker 数和 batch 大小可
调整。脚本每批保存 `checkpoint.mat`，重复执行同一命令会继续未完成行。

## 4. 汇总

两个任务完成后，各目录必须存在 `COMPLETE.txt` 和 `shard_result.mat`。将
`shard_01_of_02` 与 `shard_02_of_02` 放在同一个
`matlab/results/full_spectrum/round24_confirmatory/` 下，然后执行：

```powershell
matlab -batch "addpath('matlab/experiments'); aggregate_round24_confirmatory"
```

汇总结果位于 `round24_confirmatory/aggregate/`。正式分析使用：

- `comparison_summary.csv`：RMSE、MAE、中位绝对误差、P90/P95/P99 和耗时；
- `paired_summary.csv`：配对 MSE 差、95% CI、RMSE/MSE 降幅和逐样本胜率；
- `mechanism_summary.csv`：MUSIC 谱边界率及真值落入局部窗的比例；
- `all_trials.csv`：全部 30000 个 trial 的真值、估计和误差；
- `round24_confirmatory.mat`：完整 MATLAB 结果。

只有聚合器成功结束后的结果才能进入论文。任一分片缺失、重复、失败或协议不一致都会使
聚合器报错，不能手工跳过失败样本。
