# Round34 正式授权服务器执行指南

日期：2026-09-11

## 1. 冻结身份

用户已明确授权一次冻结的1400-trial最终独立测试。正式执行必须保持：

- source digest：`2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`；
- design hash：`e1f6cc945644e88806432a52d2b6e18d0df026024c279790c9bf26edb9792cd6`；
- estimator：`R33-A-q-only-invariants-direct-EVD-v1`；
- statistics：`R34-R32-frozen-statistics-bootstrap-index-fix-v1`；
- `UseFastResponse=true`、`UseGram=false`。

授权不允许改变算法、参数、seed、设计行、统计规则或样本量。

## 2. 授权后预检说明

不要在授权后调用旧 `preflight_round34`。该函数是授权前门禁，第5项检查要求授权文件不存在，
因此在合法授权后必然失败。修改它会改变冻结source digest，同样禁止。

两台服务器使用包外只读审计器：

```powershell
matlab -logfile round34_authorized_preflight_server1.log -batch "addpath('server_tools'); round34_authorized_preflight('server1')"
```

服务器2将标签改为 `server2`。正确结果必须包含：

```text
ROUND34_AUTHORIZED_PREFLIGHT_PASS
targeted=14 full=174 static=0 trials=0
```

以及完全一致的source、design、estimator、statistics和A-only实现标志。

## 3. 两服务器分片

服务器1：

```powershell
matlab -logfile round34_final_shard1.log -batch "addpath('matlab/experiments'); run_round34_final_shard(1,2,NumWorkers=32,BatchSize=16,PoolType='Threads')"
```

服务器2：

```powershell
matlab -logfile round34_final_shard2.log -batch "addpath('matlab/experiments'); run_round34_final_shard(2,2,NumWorkers=32,BatchSize=16,PoolType='Threads')"
```

每个分片必须完成700行、100个完整位置、每档SNR 100行。中断后只允许用完全相同命令读取
`checkpoint.mat`续跑。正常大误差样本不得替换；`success=false`必须保留并在聚合前报告。

## 4. 聚合

将两个完整分片目录放到同一工程的
`matlab/results/full_spectrum/round34_final_test_v1`下，再执行：

```powershell
matlab -logfile round34_final_aggregate.log -batch "addpath('matlab/experiments'); aggregate_round34_final_test(2)"
```

若任何行失败、分片不完整、身份漂移或输入不一致，聚合必须停止。成功标志为：

```text
ROUND34_FINAL_AGGREGATE_COMPLETE rows=1400 positions=200
```

## 5. 结果边界

最终统计只能使用冻结的R34入口和按位置成簇的20000次bootstrap。不得根据结果增加样本、
切换H/P、调整窗口或网格、恢复alpha，或重新选择任何算法参数。`C_public`仅为透明假设基线，
不能称为作者完整Zhang2026程序。
