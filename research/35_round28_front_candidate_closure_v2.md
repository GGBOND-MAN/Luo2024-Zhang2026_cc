# Round 28 前端候选闭合 v2

日期：2026-09-07

## 目的和结论边界

Round 28 v1 表明，把相同旧起点从 200 次继续到 800 次通常不会改变选中解，但它同时发现：

- 至少两个样本存在同一可行域内更高似然的额外候选；
- seed `36200034` 的旧宽括区 `fminbnd` 会在多峰区间中选择不同局部峰；
- seed `36200073` 的一个选中路径在 800 次时仍未满足投影驻点阈值。

因此 v2 只做有限的候选与数值闭合，不进行总体性能比较，也不授权运行 600 用户增量实验。

## 冻结规则

- 保留与旧前端相同的角度偏移入口；
- 每个固定角度在完整 `[15,50] m` 物理范围内使用统一原始条件复谱 log-score；
- 初始网格间距 `0.05 m`，三层嵌套网格逐层减半；
- 每个角度最多保留 16 个局部峰，并始终保留两个物理端点；
- 先对第一阶段候选进行 200 次二维单调细化；
- 再在第一阶段选中角度处进行完整距离剖面，将剖面峰作为额外二维起点；
- 候选冻结后分别以 200/400/800 次上限重新细化；
- 选择只依据同一归一化集中似然，不使用真值；
- 服务器线程数和本地线程数可以不同，但每次运行必须记录请求值与实际值。

版本：`FS-Front-Deterministic-Multipeak-R28-v2`。旧 R26/R27/R28-v1 输出均不覆盖。

## 本地预检

在压缩包根目录运行：

```powershell
matlab -logfile round28_front_v2_preflight.log -batch "addpath('matlab/experiments'); preflight_round28_front_v2"
```

预检只运行单元和缩小配置测试，不运行 9 个完整样本。

## 服务器完整定向诊断

32 线程服务器：

```powershell
matlab -logfile round28_front_v2.log -batch "addpath('matlab/experiments'); run_round28_front_candidate_closure_v2(NumWorkers=32,PoolType='Threads')"
```

如服务器启动时已有不同大小或不同类型的并行池，代码会先关闭并按请求重新创建。服务器使用
32 线程、本地使用 8 线程是允许的；应比较的是输出候选和选中解，而不是要求硬件线程数相同。

## 需要反馈的文件

请下载整个目录：

`matlab/results/full_spectrum/round28_front_candidate_closure_v2/`

以及两个日志。重点文件为：

- `selected_front_200_400_800.csv`
- `v1_v2_comparison.csv`
- `serial_thread_check.csv`（重点复核 seed `36200034`）
- `candidate_bank.csv`
- `front_candidate_closure_v2.mat`
- `COMPLETE.csv`

只有结果审计通过后，才决定是否冻结新前端并改造 600 用户增量入口。
