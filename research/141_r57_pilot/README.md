# R57 理论验证 pilot 脚本

本目录中的 Python 脚本**不是 R57 结果**，也不属于任何已冻结的 MATLAB 管线。
它们的唯一用途是：在投入 `+r57/` MATLAB 实现之前，独立验证
`research/141_r57_coherent_range_theory_and_protocol.md` 中定理1~4的推导。

观测模型严格复刻当前冻结源码的公式（`+jad/defaultConfig.m`、`+jad/trajectory.m`、
`+jad/steeringVector.m`、`+jad/simulateSnapshots.m`、`+fsjad/prepareScan.m`、
`+fsjad/exactSpectralResponse.m`、`+fsjad/replayRound27Data.m`、
`+r38/schemeF/r38RawArrayVpmlScore.m`、`+r53/likelihoodState.m`）。
随机数发生器与 MATLAB 不同，因此不是逐行可重放，只做统计层面的对照。

| 文件 | 作用 | 对应文档章节 |
|---|---|---|
| `model.py` | 参数、trajectory、TTD 扫描、精确/Fresnel 导向矢量 | 第1节 |
| `crlb.py` | 各 nuisance 模型下的有效 Fisher 信息与 CRLB | 定理1、定理2 |
| `joint.py` | `(theta, r)` 联合 FIM、ridge 系数 `kappa` | 5.3 节 |
| `orders.py` | 相位多项式阶次与自由实幅度的信息代价 | 定理3 |
| `final.py` | 正交化基、时延先验混合 CRLB、方向B上界 | 3.5/3.6/定理4 |
| `llr.py` | 盆地判决偏移量与贝叶斯错误率下界 | 2.1 节 |
| `gains.py` | 增益闭式 `G` 与精确 FIM 的比对、全范围增益表 | 定理2 |
| `mc.py` | 72 行 Monte-Carlo pilot（z-only / P_FALF / P_FACR 等） | 第8节 |
| `sumr.py` | pilot 汇总 | 第8节 |
| `mc.log`, `mc_out.json`, `mc_summary.txt` | pilot 原始逐行输出与汇总 | 第8节 |

依赖：`numpy`、`scipy`。

复现：

```
python3 gains.py      # 增益闭式 vs 精确 FIM
python3 orders.py     # 相位阶次表
python3 final.py      # 正交基 / 时延先验 / 方向B上界
python3 llr.py        # 盆地判决下界
python3 mc.py 24 -10,0,20 20260920 mc_out.json | tee mc.log
python3 sumr.py
```
