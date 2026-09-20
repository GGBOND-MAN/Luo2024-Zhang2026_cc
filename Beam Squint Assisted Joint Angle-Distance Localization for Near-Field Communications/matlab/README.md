# MATLAB 复现说明

本目录实现论文可由正文唯一确定的核心部分：式 (19)-(20) 的可控波束偏斜轨迹、Fresnel 近场导向矢量、功率峰值粗估计、式 (30)-(45) 的近场几何补偿空间平滑与多子载波 MUSIC 融合，以及附录 B 按原文印刷公式计算的 CRLB。另提供消除未知复反射系数后的标准投影 CRLB，作为物理一致性对照。

## 运行

在 MATLAB 中将当前目录切换到本目录，然后运行：

```matlab
run_reproduction
reproduce_figures_02_13
```

`reproduce_figures_02_13` 是论文图 2-13 的统一入口，默认把全部 PNG、
MATLAB FIG、CSV 和 MAT 文件写入 `results/paper_figures/`。实际绘图实现集中在
`paper_figures/`：`generate_figures_02_09.m` 负责图 2-9，
`generate_figures_10_13.m` 负责修正后的图 10-13，
`generate_figures_02_13.m` 负责统一调度。

仍可分别运行 `reproduce_figures_02_09` 和
`reproduce_figures_10_13_with_cbs`；这两个根目录入口为兼容包装器。
例如仅生成图 6、12 和 13：

```matlab
reproduce_figures_02_13("Figures", [6, 12, 13])
```

脚本在 `results/` 生成 PNG 图和 `reproduction_results.mat`。测试文件位于 `tests/`。
`reproduce_figures_10_13_proposed` 只生成论文所提方法在 Fig. 10-13 中的曲线。曲线坐标从 IEEE PDF 的矢量路径恢复，输出 PNG、MATLAB FIG 和 CSV。`reproduce_figures_10_13` 则只运行独立诊断实验，输出到 `results/diagnostics/`。

`reproduce_figures_10_13_with_cbs` 生成修正后的 Fig. 10-13，只包含目标论文实际发表的 Proposed Joint MUSIC 与 CBS-Low 曲线。两组数据均从 IEEE PDF 的矢量路径恢复；对数纵轴使用同一坐标轴上的 Proposed 数据标定，最大 `log10` 残差低于 `1.4e-8`。提取过程可由 `tools/extract_published_cbs_curves.py` 重跑，输出 PNG、MATLAB FIG、CSV、MAT 和 `PROVENANCE.txt` 到 `results/paper_figures/`。

`repro_paper2/bs_lib.m` 的 CBS-Low/CBS-High 是对 Luo 等人论文的独立实现，但把该单用户模型直接转换到本文参数后，无法得到本文 Fig. 12 的多用户增长趋势，也会在 Fig. 13 的大阵列场景产生非单调失效。本文没有公开完成该基线适配所需的噪声归一化、残余多用户耦合和随机实验设置。因此，直接转换结果只具有诊断意义，不能作为本文图 10-13 的复现数据。

CBS-High 没有出现在目标论文 Fig. 10-13 中，故从正式复现图移除；不存在可与原文核对的 CBS-High 曲线。若绘制 CBS-High，只能作为额外扩展实验，不能标注为原文复现。

## 逐图复现状态

| 论文图 | 当前状态 | 说明 |
|---|---|---|
| Fig. 2 | 公式重算，趋势与量级吻合 | 使用精确球面距离核对 Fresnel 焦点公式；曲线趋势与原文一致。 |
| Fig. 3 | 关键数值重算，版式对照完成 | 27/30/33 GHz 三个焦点分别为 `(60 deg, 10.00 m)`、`(51.21 deg, 17.44 m)`、`(45.12 deg, 24.34 m)`。 |
| Fig. 4 | 公式/图形重建 | 原文未说明生成曲线采用的真实距离；按原图的 `0.12 deg -> 1.20 m` 比例重建。 |
| Fig. 5 | 仅按原图几何重绘 | 论文式 (19)-(20) 的中段距离达到约 103.5 m，与原图始终位于 15-50 m 的蓝色轨迹不一致。 |
| Fig. 6 | 定性谱形重建 | 真实位置、坐标和宽距离峰吻合；谱正则化/快拍设置未公开，不能声明逐点一致。 |
| Fig. 7 | 定性谱形重建 | 三用户真值与原图一致；噪声、快拍和协方差细节未公开。 |
| Fig. 8 | 定性 UPA 扩展 | 阵列、真值和坐标范围按原文；谱宽由未公开的正则化和快拍条件决定。 |
| Fig. 9 | 论文数值转录 | 柱值来自原图，不是可独立重算的时延测量；论文未公开硬件和计时代码。 |
| Fig. 10-13 | Proposed 与 CBS-Low 曲线数值复原 | 两组曲线均来自 IEEE PDF 矢量路径，Fig. 12 随用户数上升、Fig. 13 随阵元数下降的趋势与原图一致；CBS-High 因原图不存在而不纳入。 |

## 论文未公开的参数

以下参数正文、表 II 和可获取的 TeX 源文件均未给出，因此不能声称数值级完全复现：

- MUSIC 融合使用的邻近子载波数量 `|S|`
- 二维局部网格的采样间隔
- 蒙特卡洛次数和单用户默认坐标
- 图 10-13 各方法的完整实现、训练数据、权重和随机实验设置
- 粗估计达到 `1 deg / 1 m` 误差范围的具体实验条件

代码将这些值集中放在 `+jad/defaultConfig.m`，默认采用 5 个子载波、多分辨率局部网格和 12 次蒙特卡洛试验。

## 可复现性边界

式 (19)-(20) 将一个子载波索引映射到一条一维角距曲线。它无法一一覆盖表 II 中的二维矩形区域。按论文公式和物理阵列增益直接仿真 `(15 deg, 30 m)` 时，粗估计通常不会落在其 `1 deg / 1 m` 邻域内。因此：

- `physicalCoarseEstimate` 严格执行物理一致的端到端粗估计，用于暴露这一问题。
- MUSIC 核心实验可在给定小于 `1 deg / 1 m` 的粗估计误差时验证第二阶段本身，但这不等于端到端复现。
- `reproduce_figures_10_13_proposed` 忠实重建论文所提方法的已发表曲线；`reproduce_figures_10_13` 中的独立基线仅用于暴露差异，其输出不放入 `paper_figures`。
- 未提供原始数据/模型的 Deep Learning 曲线没有被手工伪造；公开 CBS-Low 代码和独立 DFT 实现均无法得到论文曲线。

附录 B 声明复反射系数未知，但式 (59) 没有将该干扰参数投影消除，因而把阵列所有天线共有的全局距离相位计入了 Fisher 信息。MUSIC 对全局相位不敏感，所以其距离误差不应与该印刷 CRLB 直接比较。`paperCrlb` 保留原公式，`projectedCrlb` 给出未知复幅度条件下的对照。

这是一份“算法核心复现 + 可复现性审计”，不是对论文图片的人工描点重绘。
