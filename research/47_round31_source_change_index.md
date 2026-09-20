# Round31 源码变更索引

日期：2026-09-10。

本轮没有修改 `matlab/+r30`、`matlab/+jad`、`matlab/+fsjad` 或旧实验入口。相对历史版本，
代码差异全部是以下独立新增文件；因此不存在需要回写旧命名空间的行级补丁。

## 核心实现 `matlab/+r31`

- `config.m`：冻结容差、profile 窗口、门槛和数据用途。
- `maximizeScore1D.m`：修复网格/可行/连续候选保留、去重和边界状态。
- `reviseRound30Summary.m`：修订 F/H/P 成本和诊断语义。
- `selectDeployments.m`：以 `(candidateId, output)` 独立筛选和 Pareto 判断。
- `assertFormalExpansionAllowed.m`：拒绝诊断候选进入正式扩展。
- `stagedJointMusic.m`：复现受初始硬窗约束的二维 41/31/21 MUSIC。
- `stagedAngleMusic.m`：相同分级规则的固定距离一维 MUSIC。
- `stateFromBaseline.m`、`subsetState.m`：复用 C 子空间并严格映射 B 的载波列。
- `profileAtAngle.m`：在实际 A/B 角度上重算 ±2 m 条件复谱距离。
- `controlTrial.m`、`repairL06Trial.m`：单用户 C/A/B 与 L06 修复回放。
- `summarizeControls.m`、`evaluateControlThresholds.m`：60 用户精度汇总和原门槛判断。
- `arrayHash.m`、`loadRound30Raw.m`、`manifest.m`：数据身份和源码依赖校验。

## 实验入口 `matlab/experiments`

- `audit_round31_legacy_raw.m`
- `run_round31_l06_solver_repair.m`
- `aggregate_round31_l06_solver_repair.m`
- `run_round31_angle_controls.m`
- `aggregate_round31_angle_controls.m`
- `run_round31_fixed_n256_timing.m`
- `aggregate_round31_fixed_n256_timing.m`
- `revise_round31_fixed_n256_timing_front.m`
- `export_round31_diagnostics.m`
- `prepare_round31_formal_expansion.m`
- `preflight_round31.m`

## 测试

- `matlab/tests/round31CorrectnessTest.m`：13 项新增正确性回归。

最终逐文件 SHA-256 见
`matlab/results/full_spectrum/round31_preflight_v2/source_hashes.csv`；该清单同时包含 132 个
实际继承依赖，避免把只有新增文件的增量包误写成完整可执行源码。

