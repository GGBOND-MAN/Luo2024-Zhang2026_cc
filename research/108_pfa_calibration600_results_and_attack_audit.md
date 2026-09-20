# P_FA R45 Calibration-600 结果、计时与攻击审计

日期：2026-09-17  
方法版本：`PFA-full-aperture-sequential-v1`  
实验版本：`R45-PFA-calibration600-v1`  
状态：**校准通过；允许冻结新的独立最终协议；尚不是 independent final evidence**

## 1. 身份与完整性

- 200 个全新位置，`-10/0/20 dB`，共600个配对 trial；600/600成功。
- diagnostic-60 与 holdout-540 均在执行前固定，二者均未用于调参。
- 未读取或执行 R34/R41 final rows，未读取 R42--R44 estimate rows，未执行 final trial。
- 参数、门槛、bootstrap 和停止规则均在结果生成前冻结。
- protocol hash：`003a29a7912dddf206f82b8ed05a8bbe7bd242c657c0d210c16c7fd1725430d5`。
- design hash：`91f880e94ba0ce45d13bcbbd9b9771125d1a319f72a625503a6d163c79181039`。
- source digest：`f1483ec49bb59907a9b5b2f70aa95459f11277450a0bbcf715a43b3324439868`。
- 7项 MATLAB 单元测试全部通过；新增源码 Code Analyzer 无问题。
- 600行中 profile endpoint/near-boundary 命中均为0；候选保留最小 margin 为
  `8.80e-12`；Gram和fallback均为0。

## 2. P_FA 相对 P_A

| SNR | angle MSE ratio | angle RMSE改善 | range MSE ratio | range RMSE变化 |
|---:|---:|---:|---:|---:|
| -10 dB | 0.416419 | +35.47% | 0.997520 | +0.124% |
| 0 dB | 0.470712 | +31.39% | 1.001042 | -0.052% |
| 20 dB | 0.104462 | +67.68% | 1.001082 | -0.054% |
| equal-SNR | **0.420608** | **+35.15%** | **0.997546** | **+0.123%** |

equal-SNR 角度 RMSE 为 `0.00058638 deg`，P_A 为 `0.00090415 deg`；距离 RMSE
为 `0.0789386 m`，P_A 为 `0.0790356 m`。逐样本角度 W/T/L 为426/0/174，距离为
311/0/289。

位置聚类10,000次 bootstrap：

- angle MSE ratio `U95=0.490750 < 1`，建立校准级角度优效；
- range MSE ratio `U95=1.000074 < 1.02`，建立校准级距离非劣。

因此当前增强的本质是：**显著改善角度，同时保持原 q-only 距离后端的性能**。它没有提出
新的距离统计，距离的0.123%聚合改善应视为有限样本波动/轻微角度传递，而不是新的距离优势。

## 3. Holdout-540

所有预声明 holdout 门槛独立通过：

- aggregate angle MSE ratio P_FA/P_A：`0.437149`；
- per-SNR 最大 angle ratio：`0.480512`；
- angle `U95=0.515426 < 1`；
- aggregate range MSE ratio：`0.997097`；
- per-SNR 最大 range ratio：`1.000747`；
- range `U95=1.000010 < 1.02`。

diagnostic-60 与 holdout-540 的方向一致，说明结论不是由最初20个位置单独驱动。

## 4. 相对 G 与 C_enhanced

| 比较 | angle MSE ratio | angle RMSE改善 | range MSE ratio | range RMSE改善 |
|:--|---:|---:|---:|---:|
| P_FA / G_schur | 0.530712 | 27.15% | 0.997574 | 0.121% |
| P_FA / C_enhanced | 0.420608 | 35.15% | 0.694505 | 16.66% |

20 dB 时 P_FA 与 G 的角度几乎相同，P_FA/G angle MSE ratio 为 `1.000753`；主要增益来自
-10和0 dB。这说明 P_FA 的全孔径条件投影不仅复现 G 的高 SNR结果，还在噪声较强时避免了
“先做L160 MUSIC、再做局部修正”带来的信息和起点限制。

## 5. 同机完整入口计时

计时使用前5个0 dB校准位置，每方法1次预热、3次正式重复，循环变换顺序；每方法15条记录。

| 方法 | mean wall time | median | MUSIC eval | direct EVD | full-array eval | profile pass |
|:--|---:|---:|---:|---:|---:|---:|
| P_FA | **5.278 s** | 5.082 s | 0 | 0 | 47 | 1 |
| P_A | 9.853 s | 9.846 s | 93 | 2047 | 0 | 1 |
| G_schur | 9.984 s | 9.831 s | 93 | 2047 | 2 | 1 |
| C_enhanced | 20.590 s | 20.541 s | 3083 | 2047 | 0 | 0 |

P_FA 平均时间相对 P_A/G/C 分别降低 `46.43%/47.13%/74.36%`。这是真正的完整独立入口
时间，不是服务器吞吐，也没有把共享精度核的工作省略后冒充在线时间。

## 6. P_A、G 与 P_FA 总表

| 维度 | P_A | G_schur | P_FA |
|:--|:--|:--|:--|
| 计算图 | L06 -> L160一维MUSIC -> q profile | 完整P_A -> N256局部Schur角修正 ->隐式距离传递 | L06 -> N256条件投影角度 -> q profile |
| 是否执行P_A | 自身 | 是，完整执行一次 | 否 |
| MUSIC/EVD | 有 | 有，继承P_A | 无 |
| angle vs P_A | 基准 | final1400 MSE约0.7746，RMSE改善约11.99% | calibration600 MSE 0.4206，RMSE改善35.15% |
| range vs P_A | 基准 | final1400 MSE约1.00014，实质相同 | calibration600 MSE 0.99755，实质相同 |
| 本轮完整时间 | 9.853 s | 9.984 s | 5.278 s |
| 证据等级 | R34独立最终1400，主攻击证据 | R41独立最终1400，P_A后处理机制 | R45校准600，待独立最终 |
| 最强攻击作用 | 二维MUSIC距离维非必要；完整q频谱条件距离有效 | P_A结果可低成本做全孔径角修正 | spatial smoothing孔径损失；MUSIC/EVD并非必要 |

## 7. Zhang2026 攻击解释力

P_FA 与 P_A 具有相同的两条核心解释：都保留 L06 的有限支持边界，都使用完整 q 频谱而不是
峰值索引估计距离；都说明局部二维 MUSIC 不是高精度角距的必要结构。

P_FA 新增的解释力是：

1. 直接使用 N256，能够把 L160 空间平滑的孔径损失做成配对机制消融；
2. 在逐载波复增益 nuisance 消元后，不需要 covariance、MUSIC 或 EVD 仍能显著改善角度；
3. 其速度优势来自计算图删除，而不是仅减少二维网格点。

P_FA 不具有与 P_A 完全相同的证据成熟度。P_A 已有七SNR、1400行 independent final；P_FA
目前是三SNR、600行 calibration。故论文当前仍应以 P_A 作为主方法和主攻击依据，以 P_FA
作为已经通过大样本校准的孔径/nuisance机制增强。只有新的独立最终试验通过，才能把 P_FA
升为并列主方法或替代实现。

## 8. 结论与下一步

R45 的 all-600、holdout-540、bootstrap、身份和计时检查全部通过。当前方法定义、局部理论和
校准证据已经足以进入一次新的独立最终对比实验。下一步不再修改方法，只冻结新位置、新seed、
七SNR、同时统计上界和一次性执行规则；最终数据不得反向调节角窗、K、网格、profile或门槛。

