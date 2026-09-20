# R35 Scheme A/B/D angle-improvement summary

日期：2026-09-12  
公共协议：`research/69_angle_improvement_common_protocol.md`  
证据角色：已有 60 个 development users；不是 independent final validation  
总判定：**Scheme A、Scheme B、Scheme D 全部 FAIL；不进入 600 calibration，不运行 R34 final，不组合方案。**

> Development study – not R34 final confirmation

## 1. 统一冻结条件

三轮均继承冻结 `P_A`：`N=256`、`M=2048`、`K=2047`、`L=160`、`P=97`、L06 front、q-only、direct EVD、`UseGram=false`、当前 angle window、`41/31/21` angle grid、冻结 `+/-2 m` conditional range profile、`lambda=1`。

共同数据为同一组 60 个旧 development users，`-10/0/20 dB` 各 20 个。R34 final 1400 trial、已有 600 calibration、新用户和新 seed 均未使用。

## 2. 结果总表

| 方案 | 核心变化 | angle MSE ratio -10/0/20 | equal-SNR ratio | range Gate | runtime Gate | 结论 |
|:---|:---|:---|---:|:---|:---|:---|
| A continuous MUSIC | 最终 grid 邻域 bounded continuous refinement | 1.019719 / 1.131462 / 0.188218 | 1.032759 | PASS | PASS | FAIL |
| B coherent spectrum | 固定 `r_P` 的 conditional full-spectrum continuous refinement | 1.104551 / 1.310588 / 8.344410 | 1.182968 | 未获准 refresh | PASS | FAIL |
| D1 gap | all-carrier eigengap weights | 1.118494 / 1.000000 / 1.000000 | 1.098467 | PASS | PASS | FAIL |
| D2 information | all-carrier local angle-information weights | 0.992549 / 1.067166 / 1.000000 | 1.004744 | PASS | PASS | FAIL |
| D3 mix | `sqrt(gap*information)` weights | 1.014748 / 1.043995 / 1.000000 | 1.019419 | PASS | PASS | FAIL |

没有一个方案同时满足：每 SNR angle MSE ratio `<=1.01`、equal-SNR ratio `<=0.98`、每 SNR range ratio `<=1.02` 和 runtime/C `<=1`。

## 3. Scheme A 冻结结论

Scheme A 证明当前 P_A 的误差不能统一归因于最终离散网格量化：

- 20 dB continuous angle RMSE 改善 `56.616%`，支持高 SNR grid quantization 存在；
- -10/0 dB RMSE 分别恶化 `0.981%/6.370%`，表现为 noise-following；
- 60/60 MUSIC score 上升，但 truth squared error 只有 32 improve、28 worse；
- A_cont 与 C_cont 几乎完全相同，说明是双方共有的 grid correction，不是 P_A 特有修复；
- equal-SNR angle MSE 增加 `3.276%`，最终 FAIL。

冻结报告：`research/70_schemeA_continuous_music_angle.md`。

## 4. Scheme B 冻结结论

Scheme B 改变了信息源，但没有提供有益的稳健 complementary angle information：

- 三档 MSE 全部恶化，高 SNR ratio 达 `8.344410`；
- 60/60 coherent spectral score 上升，但 truth 只有 20 improve、40 worse；
- 20/60 输出接近微 bracket 边缘，显示 conditional spectrum 经常持续向局部区间边缘推动 angle；
- B displacement 与 A 基本不相关，说明 B 不是重复 A，但“不同”并不等于“有益”；
- primary angle Gate 全面失败，因此按预声明流程没有执行 range refresh。

冻结报告：`research/71_schemeB_spectral_angle_refinement.md`。

## 5. Scheme D 冻结结论

Scheme D 的 D0 uniform fusion 通过严格 identity：60/60 grid、index、angle 一致，最大 stage score 差 `2.8066e-13`。

D1-D3 均保持全部 carriers：

- D1 的全局最小 `K_eff=1945.17`，约为 K 的 95.0%；
- D2 `K_eff` 约 `2045.30`；
- D3 全局最小 `K_eff=2010.22`；
- 没有方案成为隐式 few-carrier estimator。

但近均匀权重只在少数离散 argmax 临界用户上改变最终 grid point，truth 方向不一致：

- D1 在 -10 dB 改变 16/20，W/T/L=`6/4/10`，MSE 恶化 11.849%；
- D2 在 -10 dB 小幅改善 0.745% MSE，却在 0 dB 恶化 6.717%；
- D3 在 -10/0 dB 分别恶化 1.475%/4.400%；
- 20 dB 三种权重都未改变任何角度，因此不能替代 Scheme A 的 continuous high-SNR grid correction；
- 三者 range/runtime Gate 全通过，但 aggregate angle Gate 全失败。

冻结报告：`research/72_schemeD_weighted_multicarrier_music.md`。

## 6. 跨方案解释

三轮 development evidence 排除了三个直接假设：

1. **“主要只是最终 grid quantization”不成立为跨 SNR 解释。** A 只在高 SNR 明显成功，低/中 SNR 追随样本谱峰而恶化。
2. **“coherent full-spectrum conditional score 可补充 angle”未得到支持。** B 的 score 虽稳定上升，truth error 却系统性恶化。
3. **“简单 parameter-free carrier reliability/information weighting 可稳健改善”未得到支持。** D 权重没有过度稀疏，但仍不能在三个 SNR 形成统一的 truth-aligned argmax 改变。

共同现象是：优化观测 objective、改变局部 score 或温和重排 carrier 权重，都不能保证 truth angle error 改善。少量离散选点变化对当前 60 用户的 MSE 很敏感，但没有可预先冻结、无真值、跨 SNR 一致的选择规则。

## 7. 工程停止点

R35 angle-improvement development 到当前候选集合的正确停止结论为：

> Simple parameter-free reliability/information weighting did not provide a robust cross-SNR angular improvement over uniform all-carrier MUSIC fusion.

并保留 A/B 的对应失败结论。根据公共协议：

- 不进入已有 600 calibration；
- 不运行、复用或查看 R34 final 1400 trial 做开发判断；
- 不组合 A/B/D；
- 不创建 SNR-adaptive selector；
- 不搜索 exponent、temperature、top-K、threshold、angle shrinkage、扩大 bracket、加密 grid、coordinate ascent 或 D4；
- 不后验放宽任何 Gate。

当前证据只能称为 development evidence，不能称为 independent final validation。P_A 和 C_enhanced 继续保持冻结。
