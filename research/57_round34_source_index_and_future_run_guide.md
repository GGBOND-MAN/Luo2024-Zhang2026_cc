# Round34 源码索引、交付说明与未来双服务器命令

日期：2026-09-10  
当前状态：`LOCKED-WAITING-FOR-EXPLICIT-USER-AUTHORIZATION`

## 1. 历史保护与差异

工程目录没有 Git 元数据，因此本轮差异以独立新增命名空间和 SHA-256 清单审计。没有修改
`+r32`、`+r33` 或旧结果。R33 当前摘要与已接受摘要完全一致。

### 新增 `matlab/+r34`

- `config.m`：冻结 R32 统计、R33 A-only 和最终门禁身份；
- `estimate.m`：无 Gram 参数的独立在线入口；
- `sharedPerformanceSet.m`：A-only 共享性能计算体；
- `assertAOnlyCost.m`：直接 EVD/Gram/回退审计；
- `prepareInputHashes.m`：主线程重放并计算 z/Y SHA-256；
- `finalTrial.m`：Threads 安全的紧凑最终 trial；
- `partitionDesign.m`：按 positionId 整簇分片；
- `saveCheckpoint.m`、`loadCheckpoint.m`：身份绑定的断点；
- `mergeShardPayloads.m`：缺失、重叠和身份漂移拒绝；
- `clusterBootstrapMeans.m`：显式 reshape 的簇 bootstrap；
- `simultaneousUpper.m`：冻结 studentized max-statistic 上界；
- `summarizePaired.m`：可测试的通用统计核心；
- `summarizeFinal.m`：额外强制 1400 行设计哈希；
- `assertFinalTestAuthorized.m`：正式授权硬门禁；
- `manifest.m`：R34 与全部继承执行依赖清单。

### 新增实验入口

- `run_round34_bootstrap_index_counterexample.m`
- `run_round34_engineering_smoke.m`
- `prepare_round34_final_test.m`
- `authorize_round34_final_test.m`（已实现但本轮未调用）
- `run_round34_final_shard.m`（负向门禁测试外未运行）
- `aggregate_round34_final_test.m`（未运行）
- `preflight_round34.m`

### 新增测试

- `round34FinalEngineeringTest.m`：14 项，覆盖 A-only 固定、Gram 拒绝、bootstrap 最小反例、
  显式循环一致、相同/更好/更差/零方差/零基线、输入排序、位置成簇、缺失/重复/失败拒绝、
  两服务器分片、缺失授权和 checkpoint 身份漂移。

## 2. 实际执行日志

- `round34_bootstrap_counterexample_local.log`
- `round34_engineering_smoke_local.log`
- `round34_unauthorized_gate_local.log`
- `round34_targeted_tests_initial_local.log`（保留失败）
- `round34_targeted_tests_second_local.log`（保留失败）
- `round34_targeted_tests_final_local.log`（保留浮点夹具失败）
- `round34_targeted_tests_final_v2_local.log`（14/14 通过）
- `round34_static_initial_local.log`（保留 3 项警告）
- `round34_static_final_local.log`（0 项）
- `round34_prepare_final_protocol_local.log`
- `round34_preflight_local.log`（14/14 专项、174/174 全项目、0 static、6/6 gate）

## 3. 结果目录

- `matlab/results/full_spectrum/round34_final_engineering_v1/bootstrap_index_counterexample`
- `matlab/results/full_spectrum/round34_final_engineering_v1/development_smoke`
- `matlab/results/full_spectrum/round34_final_engineering_v1/verification`
- `matlab/results/full_spectrum/round34_final_test_protocol_v1`

协议目录含 1400 行设计、165 文件依赖哈希、协议 MAT 和未来命令，不含授权文件。不存在
`round34_final_test_v1`，因此最终 trial 数为 0。

## 4. 未来明确授权后的命令（当前不要运行）

以下命令只是已准备的未来入口。只有用户再次明确授权最终新用户试验后，才在已审查主副本
执行一次：

```matlab
addpath('matlab/experiments');
authorize_round34_final_test("I_EXPLICITLY_AUTHORIZE_R34_FINAL_1400");
```

随后将完全一致的工程、`round34_final_test_protocol_v1` 目录和新生成的授权文件同步到两台
服务器。两台服务器分别从项目根目录执行：

服务器 1：

```powershell
matlab -logfile round34_final_shard1.log -batch "addpath('matlab/experiments'); run_round34_final_shard(1,2,NumWorkers=32,BatchSize=16,PoolType='Threads')"
```

服务器 2：

```powershell
matlab -logfile round34_final_shard2.log -batch "addpath('matlab/experiments'); run_round34_final_shard(2,2,NumWorkers=32,BatchSize=16,PoolType='Threads')"
```

每台服务器固定获得 100 个位置的全部七档 SNR，共 700 行；不是按单行交错拆散同一位置。
`BatchSize` 只改变内存、调度和 checkpoint 频率，不改变估计器、seed 或统计。

下载两个完整 shard 到同一工程后执行：

```powershell
matlab -logfile round34_final_aggregate.log -batch "addpath('matlab/experiments'); aggregate_round34_final_test(2)"
```

聚合器会再次检查授权、源码摘要、设计哈希、两 shard 的互斥和完整性，并使用修正后的 R32
冻结统计。任何失败行都会使主推断停止并要求机制审计，不会静默删除。

## 5. 当前停止点

当前不得执行授权命令、两个 shard 命令或聚合命令。本轮交付只证明代码与协议已准备，并未
证明最终精度、统计非劣或距离优效。

