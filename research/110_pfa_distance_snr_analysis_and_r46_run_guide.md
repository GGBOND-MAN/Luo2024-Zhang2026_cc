# P_FA 距离 SNR 反转分析与 R46 单机执行说明

日期：2026-09-17  
R46状态：**锁定包已准备、预检通过、未授权、最终trial=0**

## 1. 为什么低 SNR 略优、高 SNR 略低

P_FA 与 P_A 使用完全相同的 q-only 距离 profile、相同前端距离中心和相同 `+/-2 m` 支持。
两者距离结果唯一的输入差别是固定角度。因此距离差可局部写为

`delta r_star ~= -(J_r theta/J_rr) delta theta`。

### 1.1 -10 dB

- P_FA/P_A range MSE ratio：`0.997520`；
- RMSE：`0.1362177 m` 对 `0.1363869 m`，仅改善 `0.1692 mm`；
- 距离 W/L：112/88；
- P_FA 与 P_A 距离估计之差的 RMS 为 `0.012755 m`，但平均绝对差只有
  `0.001036 m`，说明少量尾部行主导RMS；
- 距离平方误差净减少总和为 `0.0092247 m^2`，正向贡献最大的20行合计
  `0.0100299 m^2`，占净改善 `108.7%`；其余行合计部分抵消。

低 SNR 下 P_A 的角度噪声较大，完整孔径角度减少了部分严重角度偏移，少数 q-profile 尾部峰
因此回到更有利的位置。该效应是真实的配对尾部改善，但不是普遍的距离目标优势。

### 1.2 0 dB 与20 dB

| SNR | range MSE ratio | RMSE绝对变化 | W/L | P_FA与P_A距离估计RMS差 |
|---:|---:|---:|---:|---:|
| 0 dB | 1.001042 | P_FA差约`0.00610 mm` | 100/100 | `0.1035 mm` |
| 20 dB | 1.001082 | P_FA差约`0.000599 mm` | 99/101 | `0.02437 mm` |

高 SNR 时两种角度误差的绝对量都已经极小，角度项对距离 MSE 的贡献远低于 q-profile 自身的
噪声、曲率和连续峰位扰动。P_FA 虽然相对角度改善很大，但绝对角度变化只有微小量；它可能
把 profile 峰向真值移动，也可能破坏 P_A 角度误差与 q-profile 距离误差之间偶然的抵消。
0/20 dB 的胜负接近完全对称，且损失仅微米到亚微米级，因此不能解释为 P_FA 在高 SNR
丢失了距离信息。

逐样本中，角度平方误差改善与距离平方误差改善的相关系数仅为
`0.1208/0.1122/-0.0445`（-10/0/20 dB）。这进一步说明距离变化主要是局部 profile
峰位对角度微扰的弱、符号不固定响应，而不是角度 MSE 改善按固定比例传递到距离。

## 2. 当前电脑与时间预算

- CPU：Intel Core i7-14650HX；
- 物理核心：16；逻辑处理器：24；
- 内存：31.73 GB；检查时可用约4.9 GB；
- MATLAB稳定配置：8个 thread workers，batch size 8；
- R45实测：600行用时86.6109分钟，即6.9275行/分钟；
- 线性投影到1400行：`3.3682 h`；
- 加上池启动、检查点、20,000次bootstrap、CSV/MAT保存和波动，建议预留
  **3.5--4.0小时**。

不建议最终试验临时改为 process pool 或16/24 workers。process pool 会复制较大的 MATLAB
状态并增加内存压力；过多并发还会与EVD/BLAS内部线程争用并触发移动工作站持续功耗限制。
8-thread配置已经由R45完整验证，改变并发不会改变算法，但会增加一次性最终执行的工程风险。

每8行保存一次检查点。按R45吞吐，每批约1.15分钟；意外中断后最多损失当前批次，使用
`Resume=true` 从完全相同的身份和设计继续。

## 3. 已生成代码

核心包：`matlab/+r46/`

- `config.m`：冻结方法、设计、统计、时间和一次性规则；
- `design.m` / `designHash.m`：生成并哈希1400行新设计；
- `clusterBootstrap.m`：七SNR log-MSE-ratio 97.5% simultaneous max上界；
- `summarize.m`：主终点、次要比较和身份审计；
- `finalTrial.m`：同观测 P_FA/P_A/G/C 精度输出；
- `sourceManifest.m` / `validateProtocolPackage.m`：源码漂移保护；
- `assertAuthorized.m`：严格授权身份验证。

执行入口：

- `prepare_round46_pfa_final.m`：已执行；
- `preflight_round46_pfa_final.m`：已执行并通过；
- `authorize_round46_pfa_final.m`：尚未执行；
- `run_round46_pfa_final.m`：尚未执行；
- `round46PfaFinalProtocolTest.m`：6 passed，0 failed。

锁定包摘要：

- source digest：`b945e33ceecdc1540a37425995f2ae1cf5b12c43c2fe4aedfff3eaee6e8c9982`；
- design hash：`73fc6c06e86e2043f029a390fdfe2288f812f30a14c25c6d3b8b451ab6799259`；
- statistics hash：`fda707b5cb698b30200104ebbc22b3a6c1dd6d1ec5800c4438f1ca8e79f00453`。

## 4. 正式运行命令

授权必须在确认电脑可连续运行约4小时后单独执行：

```matlab
addpath(fullfile(pwd,"experiments"));
authorize_round46_pfa_final( ...
    "I_EXPLICITLY_AUTHORIZE_R46_PFA_FINAL_1400");
```

随后启动：

```matlab
run_round46_pfa_final( ...
    NumWorkers=8, BatchSize=8, PoolType="Threads", Resume=false);
```

若 MATLAB 或系统中断，保持所有源码和协议文件不变，执行：

```matlab
run_round46_pfa_final( ...
    NumWorkers=8, BatchSize=8, PoolType="Threads", Resume=true);
```

完成标志为输出目录中的 `COMPLETE.mat`，以及命令行
`ROUND46_FINAL_COMPLETE rows=1400 failures=0 pass=...`。不得删除既有执行目录后重新生成一套
结果；失败或不通过必须保留原始证据。

