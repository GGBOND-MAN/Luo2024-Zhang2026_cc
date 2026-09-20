# Round33：源码索引、结果目录与复核命令

日期：2026-09-10

## 1. 历史保护和执行边界

没有修改 `+r32`、`+r31`、`+r30`、R32 统计结果或旧最终设计。R33 新实现位于 `matlab/+r33`，结果位于独立 `round33_*` 目录。

没有新增用户，没有运行 60 用户组合回归，没有运行 600/1000/10000 用户扩展，没有运行 1400-trial 最终测试，没有创建授权文件。

## 2. 核心源码

- `matlab/+r33/prepareResponseContext.m`：当前调用内的响应不变量。
- `matlab/+r33/exactSpectralResponse.m`：q-only/按需解析导数。
- `matlab/+r33/front.m`、`refineProfileMonotone.m`：保持 L06 候选和求解规则的快前端。
- `matlab/+r33/profileAtAngle.m`：保持 R32 条件复谱 profile，记录实际 `Er`。
- `matlab/+r33/prepareMusicState.m`：一次构造滑动索引和几何；支持冻结 Gram 尝试及回退。
- `matlab/+r33/principalVector.m`：较小 Gram 恢复；本轮未通过数值门禁，未采用。
- `matlab/+r33/estimate.m`：四方法的独立完整在线入口。
- `matlab/+r33/complexityLedger.m`：符号公式和分类型实际计数。
- `matlab/+r33/sharedRegressionSet.m`：仅供等价回归共享公共计算，不用于独立在线计时。
- `matlab/+r33/finalTrialCandidate.m`：锁定的 A-only 最终候选计算体；本轮未调用。
- `matlab/tests/round33EquivalentAccelerationTest.m`：9 项内核等价与回退测试。
- `matlab/tests/round33ComplexityLedgerTest.m`：4 项复杂度口径测试。

## 3. 实验与审计入口

- `run_round33_nine_user_acceptance`：保留的 v1 跨运行参考错误结果。
- `run_round33_nine_user_acceptance_v2`：同进程 R32 参考下的 9 用户 A/B/AB 验收。
- `run_round33_sixty_user_equivalence`：只有 AB 通过时才允许执行；本轮门禁拒绝，未运行。
- `run_round33_complexity_ledger`：读取已有执行记录生成台账。
- `run_round33_online_timing`：默认只计时已通过的 A，AB 需要 60 用户通过门禁。
- `finalize_round33_a_only_implementation`：冻结 A-only 实现身份和当前源码摘要。
- `prepare_round33_final_test_candidate`：继承 R32 设计，只生成锁定待批准身份，不生成授权。
- `preflight_round33`：专项/全项目测试、Code Analyzer 和执行门禁审计。

## 4. 实际执行命令

```matlab
run_round33_nine_user_acceptance
run_round33_nine_user_acceptance_v2
run_round33_complexity_ledger
run_round33_online_timing(Variant="A_response_invariants", Repetitions=3)
finalize_round33_a_only_implementation
prepare_round33_final_test_candidate
preflight_round33
```

第一条和第二条的失败均保留：v1 因历史参考口径错误拒绝全部变体；v2 正确接受 A、拒绝 B/AB。`run_round33_sixty_user_equivalence` 未执行。

## 5. 结果目录

- `matlab/results/full_spectrum/round33_equivalent_acceleration_v1/nine_user_acceptance`
- `matlab/results/full_spectrum/round33_equivalent_acceleration_v1/nine_user_acceptance_v2`
- `matlab/results/full_spectrum/round33_equivalent_acceleration_v1/complexity_ledger`
- `matlab/results/full_spectrum/round33_equivalent_acceleration_v1/complete_online_timing_a_only`
- `matlab/results/full_spectrum/round33_equivalent_acceleration_v1/accepted_a_only_implementation`
- `matlab/results/full_spectrum/round33_equivalent_acceleration_v1/verification`
- `matlab/results/full_spectrum/round33_final_test_candidate_protocol_v1`

本地文本日志：

- `round33_nine_user_acceptance_local.log`
- `round33_nine_user_acceptance_v2_local.log`
- `round33_complexity_ledger_local.log`
- `round33_online_timing_a_only_local.log`
- `round33_finalize_a_only_local.log`
- `round33_prepare_final_candidate_local.log`
- `round33_preflight_local.log`

## 6. 当前冻结身份

- 统计方法：`R32-PA-finite-closeout-v1`；
- 等价实现：`R33-A-q-only-invariants-direct-EVD-v1`；
- 接受身份：`R33-A-equivalent-implementation-accepted-v1`；
- 源码摘要：`ab98e12fc7f495dbd15be6ba48b454f4d3c2993f6f09c07b3005bf071fb24e2b`；
- 继承设计哈希：`e1f6cc945644e88806432a52d2b6e18d0df026024c279790c9bf26edb9792cd6`；
- 最终状态：锁定、未授权、0 个最终 trial。

## 7. 未来授权边界

本轮没有提供或运行最终 shard 命令。用户未来明确授权后，需要为 R33 A-only 身份建立新的、与上述源码摘要和继承设计哈希绑定的授权门禁；不得直接沿用旧授权，也不得将最终数据用于实现或参数选择。
