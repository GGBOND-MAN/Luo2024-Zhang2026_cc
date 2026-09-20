# Round34：A-only 最终工程接入、统计实现修正与门禁验收

日期：2026-09-10  
统计方法：`R32-PA-finite-closeout-v1`（目标量、门槛、家族和置信水平不变）  
估计器实现：`R33-A-q-only-invariants-direct-EVD-v1`  
编排版本：`R34-final-orchestration-v1`  
最终试验状态：**已准备、未授权、0 个最终 trial**

## 1. 本轮边界与结论

本轮结束算法优化。没有尝试 Gram/B/AB、eigs、幂迭代、载波、子阵、网格、窗口、迭代数、
H/P 门控或旧 alpha，也没有新增开发用户。R33 的 B/AB 数值门禁失败和 A-only 仅在 9 个
既有用户、36 条方法输出上通过的历史结论保持不变；没有将其扩大写成 60 用户重新验证。

本轮只完成三件事：

1. 为已接受的 A-only 实现建立无 Gram 选项的正式入口；
2. 修正最终统计代码中的 bootstrap 索引实现，并保持 R32 的统计目标不变；
3. 建立与新源码、继承设计和统计实现共同绑定的授权、分片、聚合和门禁。

历史 `+r32`、`+r33` 及其结果未修改。当前 `r33.manifest` 的摘要仍为
`ab98e12fc7f495dbd15be6ba48b454f4d3c2993f6f09c07b3005bf071fb24e2b`，与 R33 已接受身份
完全一致。R34 全依赖摘要为
`2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`，清单含 165 个实际
执行文件。

## 2. A-only 正式入口

`r33.estimate` 和 `r33.sharedRegressionSet` 的历史默认值仍是 `UseGram=true`。为避免误用，
R34 没有修改历史签名，而是新增：

- `r34.estimate`：独立在线方法入口；公共参数中没有 Gram 开关，内部固定
  `UseFastResponse=true, UseGram=false`；
- `r34.sharedPerformanceSet`：最终性能比较的共享计算体，同样显式固定 A-only；
- `r34.assertAOnlyCost`：逐次检查 carrier 数、direct EVD 数、Gram 数、回退数和实际 solver
  字符串。任何 Gram、回退或非 direct solver 都直接报错。

共享计算只用于避免四个性能方法重复计算完全相同的前端和子空间，不用于推断独立部署时延。
正式 trial 只保存必要估计、边界/候选诊断、调用计数和聚合 solver 记录，不保存巨大的
`signalVectors` 状态。

## 3. bootstrap 索引问题与修正

继承的 `+r32/summarizeFinal.m` 使用：

```matlab
rangeBootstrap(:,s)=squeeze(mean(rangeDelta(indices,s),1));
```

在 MATLAB R2024b 的最小反例中，`indices` 为 `3×4` 时，二下标调用把选取结果展平成
`12×1`，最终只产生一个均值，而不是四个 bootstrap 均值。实际保存结果为：

- 旧输出尺寸：`1×1`；
- 修正输出尺寸：`4×1`；
- 旧结果与逐列显式循环不相等；
- 修正结果与逐列显式循环逐位相等。

R34 新统计器使用冻结的显式结构：

```matlab
sampled = reshape(rangeDelta(indices(:),s), n, B);
rangeBootstrap(:,s) = mean(sampled,1).';
```

角度和距离均复用同一 `n×B` 位置簇索引，各 SNR 不独立重采样。目标量仍是 P_A-C 的配对
距离平方误差差，以及 P_A/C 的角度 MSE 比；仍使用 20000 次确定性位置簇 bootstrap、两个
独立的七 SNR max-statistic 家族、单侧 95% 同时上界和 1.21 角度 MSE 非劣界。

基线角度 MSE 为 0 时，比例目标不可定义；新统计器明确标记整个角度主家族未定义并拒绝
非劣声明，不通过除零或 NaN 静默制造结论。缺失、重复、失败、身份错位和非有限行均拒绝。

该实现问题没有污染任何既有定位精度或计时结果，因为最终 1400 行从未运行，R32 的
`summarizeFinal` 也从未用于最终数据。旧文件保留作为修正依据。

## 4. Threads 与观测哈希

实际 Threads 测试确认，`r31.arrayHash` 在 thread worker 上因 `javaMethod` 不受支持而报错。
R34 将 SHA-256 输入哈希移到 MATLAB 主线程，在每批估计前由相同 seed 和冻结生成器重放
`z/Y`、完成哈希并写入 checkpoint；随后 worker 只运行估计器，不调用 Java。哈希预重放
单独标为编排开销，不能算作 P_A 部署时间。

这样可在昂贵定位前发现主线程哈希错误，并避免定位完成后因 worker Java 失败使整批作废。
seed、生成器源码、设计哈希和输入 SHA-256 共同记录；线程 worker 的旧 Java 失败也单独保留。

## 5. 三个既有开发输入的有限工程测试

仅使用 `36200001`、`36300001`、`36400001`，对应 -10/0/20 dB 各一个既有开发输入。
它们不进入未来最终结果，也不形成新的性能统计。

- Threads：2 个本地 thread worker，3/3 trial 成功；
- 每个共享 trial：2047 个增强子空间 direct EVD + 5 个公开基线 direct EVD，合计 2052；
- Gram 次数：0；回退次数：0；
- 独立 P_A 对共享 P_A：角度差 `7.1054e-15 deg`，距离差 `1.0523e-9 m`；
- checkpoint 中断/恢复：通过；
- 两个迷你分片恢复原行序：通过；
- 最终 trial 行数：0。

该结果只证明新入口、共享体、Threads、哈希移动、断点和合并的有限软件正确性，不是 60
用户等价回归，也不是独立性能验证。

## 6. 测试和失败记录

最终状态：

- R34 专项测试：14 passed，0 failed，0 incomplete；
- 全项目回归：174 passed，0 failed，0 incomplete；
- R34 Code Analyzer：0 项；
- 执行门禁：6/6 通过；
- 正式入口未授权负向测试：在观测生成前以 `r34:FinalTestNotAuthorized` 拒绝，未创建最终
  结果目录。

开发中保留三类失败日志：表变量下标的 R2024b 兼容错误、输入重排后约 `5.6e-17` 的求和
顺序差，以及测试夹具 `2.25` 比值的 `1.82e-14` 浮点差。前两项通过固定 `cellstr` 选择和
按 `positionId` 排序修正；第三项只改为同量级相对浮点容差，没有修改 R33 数值门槛或最终
统计规则。

## 7. 最终设计和停止点

继承设计仍为 200 个新位置 × 7 个 SNR，共 1400 行；角度/距离区域为 [-60,60] 度和
[15,50] m；设计哈希仍为
`e1f6cc945644e88806432a52d2b6e18d0df026024c279790c9bf26edb9792cd6`。

两个 shard 按 `positionId` 整簇分配：每台服务器 100 个位置、700 行、每档 SNR 100 行。
比较 P_A、C_enhanced、H_A、C_public，F_L06 只作诊断。当前没有
`FINAL_TEST_AUTHORIZATION.mat`，没有 `round34_final_test_v1` 结果目录。到此停止。

