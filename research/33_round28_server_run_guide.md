# Round 28 v1 服务器运行说明

日期：2026-09-07

本包只为现有 Round 27 v3 的 600 个校准用户增量增加固定角度一维距离消融。
它不会重跑旧 11 条链路，不会启动 Round 24，也不会生成每 SNR 1000/10000 个新用户。

## 1. 两台服务器都先预检

解压后进入包含 `matlab/` 的顶层目录：

```bash
matlab -logfile round28_preflight.log -batch "addpath('matlab/experiments'); preflight_round28"
```

必须看到 `ROUND28_PREFLIGHT_COMPLETE`。失败时不要启动长任务，请回传日志和
`matlab/results/full_spectrum/round28_preflight/`。

## 2. 600 用户增量消融

服务器 1：

```bash
matlab -logfile round28_shard1.log -batch "addpath('matlab/experiments'); run_round28_fixed_angle_shard(1,2,CountPerSnr=200,NumWorkers=12,BatchSize=6,PoolType='Threads',Protocol='formal',RunExpansion=true)"
```

服务器 2：

```bash
matlab -logfile round28_shard2.log -batch "addpath('matlab/experiments'); run_round28_fixed_angle_shard(2,2,CountPerSnr=200,NumWorkers=12,BatchSize=6,PoolType='Threads',Protocol='formal',RunExpansion=true)"
```

如果服务器的线程池不稳定，把 `PoolType='Threads'` 改为 `PoolType='Processes'`；
不要同时改变其他参数。中断后使用完全相同的命令续跑。源码或协议改变后不得续用旧 checkpoint。

每个分片完成后应看到 `ROUND28_SHARD_COMPLETE`，输出分别位于：

- `matlab/results/full_spectrum/round28_v1_0200_per_snr/shard_01_of_02/`
- `matlab/results/full_spectrum/round28_v1_0200_per_snr/shard_02_of_02/`

## 3. 45 起点定向数值闭合

该任务只处理预声明的 9 个 seed，不进入总体性能。可在任一空闲服务器运行一次：

```bash
matlab -logfile round28_targeted_front.log -batch "addpath('matlab/experiments'); run_round28_targeted_front_diagnostics(NumWorkers=8,PoolType='Threads')"
```

完成标志为 `ROUND28_TARGETED_DIAGNOSTICS_COMPLETE`。若输出目录已有匹配的完整结果，程序会读取
完成标志并停止，不重复执行；`Force=true` 只用于明确要求建立一个新的独立输出目录，
不应覆盖旧结果。

## 4. 合并与汇总

把两台服务器的完整 `shard_XX_of_02` 放进同一个
`matlab/results/full_spectrum/round28_v1_0200_per_snr/`，再运行：

```bash
matlab -logfile round28_aggregate.log -batch "addpath('matlab/experiments'); aggregate_round28_fixed_angle(fullfile('matlab','results','full_spectrum','round28_v1_0200_per_snr'))"
```

必须看到 `ROUND28_AGGREGATE_COMPLETE`。聚合器会检查全部 seed 覆盖、分片版本一致和所有行成功；
失败或缺失行不会被静默删除。

## 5. 回传内容

请回传：

- `round28_preflight.log`（两台）；
- `round28_shard1.log`、`round28_shard2.log`；
- 两个完整分片目录；
- 聚合后的 `aggregate/`；
- `round28_targeted_front.log` 和完整定向诊断目录。

不要只回传截图。MAT 用于逐样本、候选排序、环境和异常复核，CSV 用于统计审计。
