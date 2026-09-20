# R35 五方向研究：范围、保护与证据身份

日期：2026-09-11。用户明确授权继续展开上一轮提出的五个问题，并要求完整保存现有方法。

本轮为R35探索研究；六个固定几何/SNR工况不构成总体性能或独立优效证据。原P_A、原R34结果及research/01–68均保留。

## 已完成的实质工作

1. 支持域：重算已见R34的42组几何覆盖/不可避免误差下界，新增固定预算候选并集profile原型并在6工况比较。
2. 角度不确定性：30组条件profile灵敏度探针、隐函数局部传播分析；保留模式切换与边界限制。
3. 统一物理模型：54组球面/平面、scan/array/hybrid局部信息分析，45组等能量且等时长的采集分配诊断，18项能量/导数检查。
4. 计算：18个真实aligned矩阵的direct EVD与matrix-free eigs微基准、108次正式求解计时，前端等5模块的Amdahl情景。
5. 公平性：24组同输入窗口控制，第一级共同离散网格的评分间隔证书与反例分析。

## 原研究完整保留

工作区不是Git仓库，因此没有伪称创建Git分支。采用独立目录与可恢复快照：

- [原始文件清单](../research_extensions/r35_five_directions/baseline/original_inventory.csv)：2207文件，8,761,930,754字节，SHA256逐文件记录；覆盖主工程、冻结上传包、旧研究、图表、脚本和结果。
- [源码及材料归档](../research_extensions/r35_five_directions/baseline/pre_extension_sources_and_materials.zip)：全部纳入清单的源码/配置/文本/CSV/论文图表等，45,669,453字节；大型MAT结果原位保留并完整登记哈希。
- [冻结实现副本](../research_extensions/r35_five_directions/baseline/frozen_matlab)：包含原算法包、实验入口、测试及配置；研究脚本只调用，不修改；显式禁用Gram。
- [快照身份](../research_extensions/r35_five_directions/baseline/snapshot.json)；交付前核对[保护检查](../research_extensions/r35_five_directions/baseline/preservation_check.csv)。原R34源码摘要仍为`2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`。

## 新数据身份与运行规则

[执行前协议](../research_extensions/r35_five_directions/PROTOCOL.md)和[物理模型尺度](../research_extensions/r35_five_directions/MODEL_SPEC.md)保留。三个预先固定几何点(−40°,17m)、(0°,32m)、(40°,48m)，每点−10/20dB，共6工况、独立噪声seed63500001–63500006。几何不是随机总体抽样；同一位置跨SNR不能当作两个独立位置。

实际z/Y已一次生成并保存到inputs/case_XX_input.mat，包含RNG、原始观测和哈希。后续读取输入文件；没有重建失败的服务器R34案例。每个case_XX.mat保存前端全部候选、冻结子空间、profile、灵敏度、每种窗的实际评分面与微基准aligned矩阵。

| caseId | seed | success | seconds |
| --- | --- | --- | --- |
| 1 | 63500001 | 1 | 80.6441 |
| 2 | 63500002 | 1 | 79.7209 |
| 3 | 63500003 | 1 | 78.7294 |
| 4 | 63500004 | 1 | 76.6768 |
| 5 | 63500005 | 1 | 78.9444 |
| 6 | 63500006 | 1 | 77.7952 |

新输入沿用原条件z/Y模型以隔离算法因素；统一物理模型信息计算是另一条证据链，没有把它冒充同一批输入的定位测试。新工况结果只属于开发数据。

## 文档索引

- [70：有限支持与多峰](70_r35_support_and_multimode.md)
- [71：角度不确定性](71_r35_angle_uncertainty.md)
- [72：统一采集与时延信息](72_r35_unified_acquisition_and_clock.md)
- [73：剩余计算瓶颈](73_r35_cost_and_subspace.md)
- [74：角度条件与公平窗口](74_r35_window_fairness_and_certificate.md)
- [75：结论与审查](75_r35_results_and_claims_audit.md)
