# Round34：我方方法与 Zhang-style 复现的完整对比图及基线身份

日期：2026-09-11

## 1. 正式性能比较使用的 Zhang 复现

Round34 的正式主比较不是从 Zhang2026 论文曲线读取数值，也不是作者未公开程序，而是本项目
在同一观测、同一位置和同一噪声条件下运行的可执行增强 Zhang-style 基线：

- 输出名称：`C_enhanced`；
- 配置标签：`same-L06-front-Zhang-R26-enhanced-C`；
- 联合搜索实现：`R31-constrained-staged-joint-MUSIC-v1`；
- 参数来源：`Zhang-EF-JointMC-R26-locked`；
- Round34 入口：`r34.sharedPerformanceSet`；
- 实际计算体：`r33.sharedRegressionSet`；
- `UseFastResponse=true`，`UseGram=false`，直接协方差 EVD。

冻结参数为：

- 与 P_A 共用同一个 L06 复谱前端；
- MUSIC 载波数 `K=2047`；
- 子阵长度 `L=160`；
- 空间平滑子阵数 `P=97`；
- 初始角度半窗 `±0.2 deg`；
- 初始距离半窗 `±0.0025 m`；
- 三级二维联合 MUSIC 网格 `41×41`、`31×31`、`21×21`；
- 每级围绕上一级离散最佳点收缩，并受初始硬窗口约束。

其 R26 未公开参数寻优使用：18,144 组完整离散空间、覆盖各参数维度抽取 136 个联合候选、
successive halving `136→32→8`、每个 SNR 累计 `67→333→1000` 个校准样本，三档 SNR 合计
68,880 次样本－配置评估；随后每个 SNR 使用 200 个独立验证样本。它是对作者未知参数的本地
最优逼近，不代表恢复了作者真实参数。

## 2. 第二个 Zhang-style 参照

`C_public` 是透明公开假设基线：`K=5`、`L=128`、`±1 deg`、`±1 m`、三级 `41/31/21`
二维网格。它用于说明低成本公开假设配置的精度—复杂度位置，没有经过与 `C_enhanced` 相同的
大规模 R26 联合 MC 寻优，也不是作者完整 Zhang2026 实现，因此不是正式主统计比较对象。

## 3. 我方输出身份

- `P_A`：L06 复谱前端 + 固定前端距离的一维 MUSIC 角度 + `±2 m` 条件全复谱距离 profile；
- `H_A`：同一一维 MUSIC 角度，但保留 L06 前端距离，不运行 profile；
- `F_L06`：L06 前端原始输出，只作前端诊断，不是最终部署主方法。

正式预声明统计只检验 `P_A vs C_enhanced`。`H_A` 和 `F_L06` 属于消融/诊断，不应与主方法
统计结论混写。

## 4. 图形目录

完整图形位于：

`server_packages/round34_final_authorized_full_project_upload_20260911_115954/matlab/results/full_spectrum/round34_final_test_v1/posthoc_analysis_v1/zhang_comparison_figures_v1`

包含：

1. `01_formal_angle_rmse`：P_A 与 C_enhanced 角度 RMSE；
2. `02_formal_range_rmse`：P_A 与 C_enhanced 距离 RMSE；
3. `03_formal_position_rmse`：P_A 与 C_enhanced 位置 RMSE；
4. `04_all_methods_angle_rmse`：全部冻结输出角度 RMSE；
5. `05_all_methods_range_rmse`：全部冻结输出距离 RMSE；
6. `06_all_methods_position_rmse`：全部冻结输出位置 RMSE；
7. `07_all_methods_angle_p95`：角度 P95；
8. `08_all_methods_range_p95`：距离 P95；
9. `09_all_methods_position_p95`：位置 P95；
10. `10_all_methods_range_failure_rate`：大于 1 m 的距离失捕率；
11. `11_all_methods_maximum_range_error`：最大距离误差；
12. `12_pa_range_rmse_reduction_and_inference`：RMSE 降低及统计优效标记；
13. `13_our_methods_range_win_rate_vs_c_enhanced`：配对距离严格胜率；
14. `14_formal_range_error_cdf_representative_snr`：-10/0/20 dB 距离误差 CDF；
15. `15_accuracy_complexity_all_frozen_methods`：冻结精度—完整在线时间对比。

每张图均提供 PNG 和 MATLAB FIG，配套数据为
`formal_pa_vs_c_enhanced_metrics.csv`、`our_methods_vs_c_enhanced_paired_rates.csv` 和
`comparison_figure_data.mat`。

## 5. 论文图注建议

主图中建议写：

> `C_enhanced` denotes our strengthened executable Zhang-style baseline using the R26-locked
> joint-MUSIC configuration and the same L06 front end as P_A. It is not the authors' unavailable
> implementation. `C_public` is a transparent-assumption low-cost reference and is not used as
> the primary inferential baseline.

