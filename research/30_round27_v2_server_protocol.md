# Round 27 v2：收敛审计与同角度距离消融服务器协议

> **已废弃（2026-09-06）**：正式服务器实验请使用
> `31_round27_v3_server_protocol.md` 和 `round27_v3_upload_*.zip`。
> v2 把公开公式有歧义的 `zhang_declared_protocol` 混入正式汇总，不能再用于长实验。

日期：2026-09-06

## 1. 本轮目的与边界

Round 26 的 Zhang 与 FSJAD 全参数联合寻优结果保持冻结。本轮不重新选择参数，
只使用 Round 26 的 1000 个/每 SNR 校准样本，不读取 600 个独立验证样本，
也不读取 Round 24 的万次预留样本。

本轮回答三个问题：

1. 原复谱前端每起点 12 次迭代是否造成未收敛；200 次和 400 次继续求解是否一致。
2. 在角度严格相同的条件下，用条件复谱距离剖面替换 MUSIC 距离是否改善距离。
3. 改善来自前端、MUSIC 角度还是条件距离目标中的哪一部分。

本轮仍限于当前单径、同步、已知相位参考的仿真模型，不扩展多径，也不把数值局部收敛
表述为全局最优。原文流程中未完成联合寻优的实现假设会被明确标记，不能冒充作者真实参数。

## 2. 数值求解器

新前端最大迭代数预先固定为 200，梯度型停止阈值为 `1e-6`。复数残差和雅可比拆成
实部/虚部的增广最小二乘，使用 MATLAB 对高矩阵反斜杠所采用的 QR 路径，避免直接构造
正规方程。每一步由阻尼、物理边界投影和 Armijo 回溯共同控制；目标值不得下降。

200/400 稳定性判据只使用：是否收敛、驻点残差、目标差、角度差和距离差。
真值误差只保存在输出中用于事后诊断，不参与“收敛”判定，也不用于调参。

## 3. 十二个输出

| 编号 | 名称 | 作用 |
|---:|---|---|
| 1 | `legacy_front` | Round 26 原 12 次迭代前端 |
| 2 | `stable_front` | 从全部旧起点继续求解的新前端 E |
| 3 | `a_legacy_zhang_music` | 旧前端 + Zhang R26 MUSIC，即 A |
| 4 | `b_legacy_zhang_profile` | 与 A 完全相同角度 + 条件复谱距离，即 B |
| 5 | `c_stable_zhang_music` | 新前端 + Zhang R26 MUSIC，即 C |
| 6 | `d_stable_zhang_profile` | 与 C 完全相同角度 + 条件复谱距离，即 D |
| 7 | `zhang_r26_cached` | Round 26 保存的 Zhang 输出，用于复现一致性检查 |
| 8 | `fsjad_r26_cached` | Round 26 保存的 FSJAD 输出 |
| 9 | `fsjad_r26_stable` | 新前端 + 我方 R26 MUSIC 角度 + 条件距离 |
| 10 | `fsjad_music_stable` | 与 9 完全相同角度的原始 MUSIC 距离 |
| 11 | `profile_at_front_angle` | 与 E 完全相同角度的条件距离 |
| 12 | `zhang_declared_protocol` | 公开 `L=128`、半窗 `1°/1 m` 的透明假设版本 |

最重要的主比较是 `D-C`：角度逐样本严格相同，只替换距离估计目标。
`B-A` 是旧前端下的同角度复核；`C-A` 隔离前端变化；`D-E` 是完整局部链路相对前端。
输出还报告异常值分位数、最大误差、最差 1%/5% 对 SSE 的占比、边界命中率、配对 bootstrap
区间及 A 与 Round 26 Zhang 缓存结果的最大数值差。

## 4. 服务器运行顺序

将新压缩包上传到两台服务器并分别解压。进入解压后含 `matlab/` 的顶层目录。
旧 `round27_upload_*.zip` 是 v1，不要继续使用或与 v2 检查点混合。

### 4.1 两台服务器都先预检

```bash
matlab -logfile round27_preflight.log -batch "addpath('matlab/experiments'); preflight_round27"
```

必须看到 `ROUND27_PREFLIGHT_PASSED`。若失败，停止后续任务并回传日志与
`matlab/results/full_spectrum/round27_preflight/`。

### 4.2 服务器 1：200/400 前端稳定性，10 个/每 SNR

```bash
matlab -logfile round27_front_stability_10.log -batch "addpath('matlab/experiments'); run_round27_front_stability(CountPerSnr=10,NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

输出目录：
`matlab/results/full_spectrum/round27_front_stability_0010_per_snr/`。
程序不会因为某个样本不满足稳定性阈值而删样本；它会完整保存并汇总稳定率。

### 4.3 两台服务器：正式配置的小规模先导，10 个/每 SNR

服务器 1：

```bash
matlab -logfile round27_pilot10_shard1.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(1,2,CountPerSnr=10,NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

服务器 2：

```bash
matlab -logfile round27_pilot10_shard2.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(2,2,CountPerSnr=10,NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

输出目录均为 `matlab/results/full_spectrum/round27_v2_0010_per_snr/`。
每台服务器各生成一个 `shard_XX_of_02`。中断后原命令可续跑；源码或参数改变时不得复用检查点。

将服务器 2 的 `shard_02_of_02` 整个复制到服务器 1 的同一输出目录，再在服务器 1 运行：

```bash
matlab -logfile round27_pilot10_aggregate.log -batch "addpath('matlab/experiments'); aggregate_round27_convergence"
```

先回传 10 个/每 SNR 的稳定性与先导结果。确认 Zhang 缓存复现差、失败率、边界率和异常值
没有实现异常后，再启动 200 个/每 SNR；不要直接跳到 1000 或 Round 24 最终验证。

### 4.4 先导审查通过后：200 个/每 SNR

服务器 1：

```bash
matlab -logfile round27_200_shard1.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(1,2,CountPerSnr=200,NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

服务器 2：

```bash
matlab -logfile round27_200_shard2.log -batch "addpath('matlab/experiments'); run_round27_convergence_shard(2,2,CountPerSnr=200,NumWorkers=12,BatchSize=12,PoolType='Threads')"
```

合并两个分片后：

```bash
matlab -logfile round27_200_aggregate.log -batch "addpath('matlab/experiments'); aggregate_round27_convergence(fullfile('matlab','results','full_spectrum','round27_v2_0200_per_snr'))"
```

## 5. 建议回传的文件

先导阶段请回传：

- 两台服务器的 `round27_preflight.log`；
- `round27_front_stability_10.log` 与完整稳定性输出目录；
- 两个 `round27_pilot10_shard*.log`；
- 合并后的 `round27_v2_0010_per_snr/aggregate/`；
- 两个分片中的 `COMPLETE.csv`、`failures.csv`；若失败还需对应 `shard_result.mat`。

不要只回传截图。CSV 用于快速审查，MAT 用于逐样本追踪。

## 6. 本地验证记录

2026-09-06，本版所有修改文件通过 MATLAB Code Analyzer，0 项警告或信息。
Round 27 专项 12 项测试全部通过；完整预检合计 44 项测试/理论检查全部通过。
已知异常 seed `36400431` 的 200/400 结果在目标、角度和距离上完全一致，且满足驻点阈值。
compact 三档 SNR 冒烟、断点续跑和汇总成功。上述 compact 数据只验证软件流程，不用于性能结论。
