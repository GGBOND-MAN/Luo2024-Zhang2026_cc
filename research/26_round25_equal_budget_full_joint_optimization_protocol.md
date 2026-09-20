# Round 25：Zhang 与 FSJAD 同预算全参数联合寻优协议

> 状态更新：本轮 60 次/SNR 协议保留为历史预实验。正式大规模等预算寻优已升级到
> Round 26 的 1000 次/SNR 协议，见 `27_round26_large_equal_budget_joint_optimization.md`。

## 1. 为什么先暂停万次验证

Round 23 对 Zhang 的五个未知参数做了统一联合 MC 寻优，而我方 Round 21 只联合搜索了
融合载波、MUSIC 网格和距离剖面间距，其他参数来自更早的分阶段实验。为了使论文中的调参
强度可直接比较，Round 24 万次确认实验暂停，先补做我方全参数联合寻优。

本轮不会读取 Round 24 预留的任何 seed。寻优结束后先冻结算法，再恢复 Round 24。

## 2. 同等级的定义

两种算法的结构不同，因此参数维度数不必相同；“同等级”定义为：

- 相同校准用户：每档 SNR 60 个，三档共 180 个；
- 相同候选预算：136 个联合候选；
- 相同 successive-halving：`136 -> 32 -> 8`；
- 相同累计样本：每档 `4 -> 20 -> 60`；
- 相同样本－配置预算：4128 次；
- 相同选择目标：三档等权归一化距离 MSE 几何平均；
- 相同角度约束：任一 SNR 的角度 RMSE 不超过各自旧基线的 1.15 倍；
- 运行时间不参与选参。

我方使用与 Zhang Round 23 完全相同的 180 个校准用户和噪声 seed。

## 3. 我方联合参数空间

本轮联合覆盖八个维度：

1. 融合载波数：`65/129/257/513/1025/2047`；
2. 子阵长度：`32/64/96/128/160/192/224`；
3. MUSIC 角度半窗：`0.005/0.01/0.02/0.05/0.1/0.2/0.5/1 deg`；
4. MUSIC 距离半窗：`0.0025/0.005/0.01/0.02/0.05/0.1/0.25/0.5/1 m`；
5. MUSIC 网格：从 `21/15/11` 到 `61/41/31` 的六组网格；
6. 条件距离剖面半窗：`0.1/0.2/0.3/0.5/1/2/3 m`；
7. 剖面种子间距：`0.025/0.05/0.075/0.1/0.15/0.2/0.3/0.5 m`；
8. 融合系数：`0/0.25/0.5/0.7/0.8/0.9/0.95/1`。

剖面间距必须不大于剖面半窗。满足该约束的完整离散空间为 7112448 组。本轮从中确定性
抽取 128 个候选并加入 8 个理论、历史和边界锚点，共 136 个。每个参数层级至少出现一次，
但不应表述为穷举 7112448 组。

融合系数限制在理论允许的 `[0,1]`。增强粗前端偏移集合固定为
`[-0.2,-0.1,0,0.1,0.2] deg`，对 Zhang 和我方保持相同，不作为我方额外调参维度。

## 4. 运行方式

在服务器的项目子目录
`Beam Squint Assisted Joint Angle-Distance Localization for Near-Field Communications`
中执行：

```powershell
matlab -batch "addpath('matlab/experiments'); run_round25_fsjad_joint_mc_optimization(NumWorkers=12,BatchSize=6,PoolType='Threads')"
```

建议 worker 数不超过 12，因为第一阶段只有 12 个独立校准用户可并行。若线程池不可用，
改成 `PoolType='Processes'`。脚本按批次保存校准和验证检查点；中断后使用完全相同的命令
即可继续。不要删除或跨不同参数版本复用检查点。

结果目录为：

```text
matlab/results/full_spectrum/round25_fsjad_joint_mc/
```

关键输出包括 `selected_configuration.csv`、三个阶段筛选表、`comparison_summary.csv`、
`paired_summary.csv`、`mechanism_summary.csv` 和 `selected_algorithm.mat`。锁定后使用 600
个全新用户比较优化 Zhang、旧 FSJAD 和优化 FSJAD；这 600 个验证样本不参与选参。

## 5. 恢复最终万次验证

Round 25 完成并审计通过后，把 `selected_algorithm.mat` 复制到两台最终验证服务器的：

```text
matlab/results/full_spectrum/round25_fsjad_joint_mc/selected_algorithm.mat
```

然后再执行 Round 24 的两个分片命令。Round 24 会校验版本必须为
`FSJAD-JointMC-R25-locked`；缺少锁定文件或版本不符时会拒绝运行。
