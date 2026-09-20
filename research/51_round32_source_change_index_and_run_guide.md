# Round32：源码变更索引、复现入口与交付说明

日期：2026-09-10

## 1. 历史保护

没有修改 `+r30`、`+r31`、Round30/Round31 raw、旧 CSV/MAT、历史哈希或研究报告 01–47。全部新实现位于 `+r32`、`*round32*.m`、research/48–51 和独立结果目录。

## 2. 核心源码

- `matlab/+r32/config.m`：冻结 P_A、四条基线、统计、计时、模型检查和最终协议。
- `matlab/+r32/estimatePA.m`：只从当前 z/Y 出发的独立 P_A。
- `matlab/+r32/estimateHA.m`：不运行 profile 的 H_A。
- `matlab/+r32/estimateC.m`：同前端增强 C 的完整在线入口。
- `matlab/+r32/estimatePublic.m`：透明 C_public 完整在线入口。
- `matlab/+r32/profileAtAngle.m`：冻结 ±2 m 全复谱 profile。
- `matlab/+r32/summarizeExisting.m`：已有 60 用户配对统计。
- `matlab/+r32/applyResidualDelay.m`：固定公共残余时延扰动。
- `matlab/+r32/finalTestDesign.m`：冻结 1400 行设计。
- `matlab/+r32/finalTrial.m`：最终测试性能试验的共享公共组件实现。
- `matlab/+r32/summarizeFinal.m`：按位置成簇的最终预声明统计。
- `matlab/+r32/assertFinalTestAuthorized.m`：最终运行硬门禁。
- `matlab/+r32/manifest.m`、`sourceDigest.m`、`designHash.m`：源码和数据身份。

## 3. 已执行入口

```matlab
run_round32_existing_statistics
run_round32_entry_regression
run_round32_baseline_entry_regression
run_round32_online_timing
run_round32_model_check
prepare_round32_final_test
```

最终两个命令只准备设计并验证拒绝状态，没有运行 final shard。

## 4. 最终测试入口（当前锁定）

以下入口已实现但未授权执行：

```matlab
authorize_round32_final_test
run_round32_final_shard
aggregate_round32_final_test
```

用户明确确认后，才允许先创建与协议/设计/源码哈希绑定的授权文件，再分别在两台 32 线程服务器执行：

```matlab
run_round32_final_shard(1, 2, NumWorkers=32, BatchSize=16, PoolType="Threads")
run_round32_final_shard(2, 2, NumWorkers=32, BatchSize=16, PoolType="Threads")
```

## 5. 已执行验证

```matlab
runtests("matlab/tests/round32FrozenPaTest.m")
runtests("matlab/tests")
```

最终结果分别为 10/10 和 147/147 通过。Round32 源码 `checkcode(...,"-id")` 为 0 项。

## 6. 结果目录

- `matlab/results/full_spectrum/round32_pa_finite_closeout_v1/existing_raw_statistics`
- `matlab/results/full_spectrum/round32_pa_finite_closeout_v1/entry_regression`
- `matlab/results/full_spectrum/round32_pa_finite_closeout_v1/baseline_entry_regression`
- `matlab/results/full_spectrum/round32_pa_finite_closeout_v1/complete_online_timing`
- `matlab/results/full_spectrum/round32_pa_finite_closeout_v1/model_check`
- `matlab/results/full_spectrum/round32_pa_finite_closeout_v1/verification`
- `matlab/results/full_spectrum/round32_final_test_protocol_v1`

最后一个目录只包含协议、1400 行 seed/design、源码哈希和未来命令；没有授权文件和最终结果。

## 7. 大文件边界

交付小包不复制 Round29/Round30 的 775 MB 原始目录或大型 z/Y MAT。入口通过旧 raw 哈希和源码清单绑定基础工程；如需在另一环境独立复现三个首用户或模型检查，可单独提供对应原始 MAT，而不重复上传整个历史目录。
