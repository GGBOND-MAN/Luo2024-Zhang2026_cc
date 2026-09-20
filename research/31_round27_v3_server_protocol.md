# Round 27 v3：正式收敛与同角度距离消融服务器协议

日期：2026-09-06

## 1. 本版修正

正式性能任务只保留 11 个具有明确比较含义的方法。`zhang_declared_protocol`
已从正式协议、配对比较和汇总中移除，公开公式的一致性问题由
`run_round27_published_formula_audit.m` 单独记录。

原因是 Zhang 论文式 (14)-(15)、声明的 15--50 m 感知范围以及文中的
`(14.8 deg, 29.5 m)` 粗估计不能同时成立。按公开公式，14.8 deg 对应约
102.576 m，2048 个离散载波中只有 383 个轨迹点落在 15--50 m。
该问题不能作为我方性能优势，也不能用一个未经寻优的假设实现代表作者真实算法。

## 2. 正式比较范围

Round 26 的 Zhang 与 FSJAD 联合 Monte Carlo 寻优结果保持冻结。本轮不重新调参，
只从两份 Round 26 优化 MAT 中读取相同的校准样本和锁定配置。

正式输出为：

1. `legacy_front`
2. `stable_front`
3. `a_legacy_zhang_music`
4. `b_legacy_zhang_profile`
5. `c_stable_zhang_music`
6. `d_stable_zhang_profile`
7. `zhang_r26_cached`
8. `fsjad_r26_cached`
9. `fsjad_r26_stable`
10. `fsjad_music_stable`
11. `profile_at_front_angle`

主比较为 `D-minus-C-primary`：C 与 D 逐样本使用完全相同的前端和 MUSIC 角度，
只替换距离输出，因此能够检验条件复谱距离后端是否优于 MUSIC 距离。
`C-minus-A` 检验前端继续收敛的影响，`B-minus-A` 是旧前端下的距离后端复核。

本轮仍是单径、同步、已知相位参考的模型诊断，并使用 Round 26 校准样本，
不能代替冻结方法后的独立最终验证，也不能声称闭式最优 alpha 已经部署。

## 3. 已完成的本地验证

- 所有修改文件通过 MATLAB Code Analyzer，0 项问题。
- 全量测试：93 Passed，0 Failed，0 Incomplete。
- 预检相关测试、异常种子重放、断点续跑及汇总均通过。
- 正式尺寸 10 次/SNR，共 30 个样本，30/30 成功。
- v3 与旧 v2 的 11 个共同方法逐样本最大角度差和距离差均为 0。
- 稳定前端在 30 个样本中的选中解收敛率为 100%。

10 次/SNR 仅证明软件路径和数值稳定性，不能作为论文性能结论。

## 4. 服务器运行

把同一个 v3 压缩包上传到两台服务器并分别解压。进入含 `matlab/` 的顶层目录。
不要复制或续用 v1/v2 的 `round27_v1_*`、`round27_v2_*` 检查点。

### 4.1 两台服务器都先预检

```bash
matlab -logfile round27_v3_preflight.log -batch "addpath('matlab/experiments'); preflight_round27"
```

必须看到 `ROUND27_PREFLIGHT_PASSED`，否则不要启动长任务。

### 4.2 服务器 1

```bash
matlab -logfile round27_v3_200_shard1.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(1,2,CountPerSnr=200,NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

### 4.3 服务器 2

```bash
matlab -logfile round27_v3_200_shard2.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(2,2,CountPerSnr=200,NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

每台服务器处理每个 SNR 的一半样本。中断后可以使用完全相同的命令续跑。
输出分别位于：

- `matlab/results/full_spectrum/round27_v3_0200_per_snr/shard_01_of_02/`
- `matlab/results/full_spectrum/round27_v3_0200_per_snr/shard_02_of_02/`

### 4.4 合并与汇总

把两个 `shard_XX_of_02` 文件夹放入同一个
`matlab/results/full_spectrum/round27_v3_0200_per_snr/`，然后运行：

```bash
matlab -logfile round27_v3_200_aggregate.log -batch "addpath('matlab/experiments'); aggregate_round27_convergence(fullfile('matlab','results','full_spectrum','round27_v3_0200_per_snr'))"
```

## 5. 回传文件

请回传：

- 两台服务器的 `round27_v3_preflight.log`；
- `round27_v3_200_shard1.log` 和 `round27_v3_200_shard2.log`；
- 两个完整的 `shard_XX_of_02` 文件夹；
- 合并生成的 `aggregate/` 文件夹。

不要只回传截图。MAT 用于逐样本审计，CSV 用于统计检查。
