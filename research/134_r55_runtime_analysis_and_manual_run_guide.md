# R55：P_FALF Final-1400运行时间分析与手动运行指南

日期：2026-09-18  
状态：**协议包已锁定；preflight通过；authorization不存在；final trial=0**

## 1. 当前电脑

- CPU：Intel Core i7-14650HX；
- 物理核心：16；逻辑处理器：24；
- 内存：31.73 GB；
- 2026-09-18 18:21检查时可用内存约4.36 GB；
- 已验证配置：8个MATLAB thread workers，batch size 8。

不建议使用process pool或16/24 workers。process pool会复制大型阵列状态，额外占用内存；过多
worker还会与EVD、BLAS和复数矩阵运算的内部线程竞争。

## 2. 实测基准

精简finalTrial删除了Y-only、重复q-profile和曲率诊断，但保留P_A、P_FA、P_FALF、G与C输出。
使用24条既有R54校准设计行、8线程、2次重复得到：

| 指标 | 数值 |
|---|---:|
| 每次24行平均墙钟时间 | 225.632 s |
| 有效时间/行 | 9.4013 s |
| 1400行纯计算线性投影 | 3.6561 h |
| bootstrap、保存和检查预算 | 0.1667 h |
| 加15%波动后的建议上界 | 4.3712 h |
| 由R54完整600行直接线性投影 | 4.5340 h |

由于建议上界和R54保守投影都超过4小时，Codex没有创建授权，也没有启动final。

建议实际预留 **4.5至5.0小时**。移动工作站温度、后台程序、剩余内存和持续功耗限制可能使运行
进一步变慢。开始前建议释放至少8 GB可用内存并接通电源。

## 3. 锁定身份

- source digest：fc7f8e0504681e5667f389451d8b63433da0d234c82f4ddf5f8c5a59df9ae8f8；
- design hash：f363b0efb0b85c157305dd2a27835e5de1114e4d49cce08d46fd8b1348c07b24；
- statistics hash：c9ab003c1bb8cc1ba7a870d09e2e6abf61546ad23769aed34d23749443d4029d；
- 1400行、200位置、七档SNR设计已锁定；
- authorizationExists=false；executionExists=false；observations=0；trials=0。

## 4. 手动运行

在MATLAB中进入工程的 matlab 目录，然后执行：

    addpath(fullfile(pwd,"experiments"));
    authorize_round55_p_falf_final( ...
        "I_EXPLICITLY_AUTHORIZE_R55_PFALF_FINAL_1400_MANUAL_RUN");

随后启动：

    run_round55_p_falf_final( ...
        NumWorkers=8, BatchSize=8, PoolType="Threads", Resume=false);

若MATLAB或系统中断，保持全部源码、协议和设计不变，执行：

    run_round55_p_falf_final( ...
        NumWorkers=8, BatchSize=8, PoolType="Threads", Resume=true);

每8行保存一次checkpoint。不要删除既有执行目录后从新seed重跑，也不要在运行过程中修改任何
R53、R54或R55文件。

## 5. 完成判据

完成后应出现：

- results/full_spectrum/round55_p_falf_independent_final_v1/COMPLETE.mat；
- result.mat、decision.csv、range_primary_family.csv；
- 命令行输出 ROUND55_FINAL_COMPLETE rows=1400 failures=0 pass=...。

在用户完成手动运行前，不生成任何final结论。

