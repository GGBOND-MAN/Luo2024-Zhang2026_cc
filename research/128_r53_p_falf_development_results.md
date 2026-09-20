# R53：P_FALF 独立Development结果

日期：2026-09-18  
协议：R53-PFALF-development-v1  
状态：**预声明Development Gate全部通过；冻结为development candidate；不自动进入calibration**

## 1. 实验身份

- 30个全新位置乘 -10/0/20 dB，共90行；
- 90/90行成功，0失败；
- source digest：c1476d3b75078a841286bebf6e67812217dd689952b291b4a3213cd915018c5c；
- frozen P_FA digest：f1483ec49bb59907a9b5b2f70aa95459f11277450a0bbcf715a43b3324439868；
- design hash：8c0e5c0227b4017a6884d28073397203c1453c71fcc61214cecbb87381d2f740；
- 未读取final、calibration、R51或R52逐行结果；未调权、未扩展支持、未修改P_FA；
- 8个thread workers，完成时间为2026-09-18 15:32:27（Asia/Shanghai）。

## 2. 预声明Gate

| Gate | 结果 | 门槛 | 判定 |
|---|---:|---:|---|
| statistical model | 1 | 必须通过 | PASS |
| 最大角度恒等差 | 0 deg | <=1e-12 deg | PASS |
| equal-SNR距离MSE/P_A | 0.652928 | <=0.98 | PASS |
| 最大逐SNR距离MSE/P_A | 0.948552 | <=1.05 | PASS |
| 大于1 m失捕率差 | 0 | <=0 | PASS |
| 完整运行时间/C_enhanced | 0.394580 | <1 | PASS |

因此按运行前冻结的规则，R53正式Development PASS。bootstrap不用于反向修改Gate。

## 3. 距离性能

| SNR | P_FA/P_A MSE | P_FALF/P_A MSE | P_FALF/P_FA MSE | 相对P_A RMSE差 |
|---:|---:|---:|---:|---:|
| -10 dB | 0.999818 | 0.648270 | 0.648388 | -28.247 mm |
| 0 dB | 1.000485 | 0.948552 | 0.948092 | -0.473 mm |
| 20 dB | 1.001035 | 0.857720 | 0.856833 | -0.097 mm |
| equal-SNR | 0.999828 | 0.652928 | 0.653040 | -16.193 mm |

P_FALF最终角度逐行严格等于P_FA，因此角度性能完全继承P_FA，没有角度代价。

P_FALF对P_A距离逐行W/T/L为43/0/47。胜率并不高于50%，聚合MSE改善来自少数幅度较大的
低SNR纠错，而不是大多数行一致的小幅改善。

## 4. Y-only消融

Y-only相对P_A的距离MSE比：

- -10 dB：7.97598；
- 0 dB：100.15683；
- 20 dB：125.10166；
- equal-SNR：9.41013。

因此不能写成“Y本身是更准确的距离观测”。正确解释是：每载波自由复增益消元后的Y距离
曲率很弱且单独不可靠，但作为独立似然块可能改变q竞争峰排序。

## 5. 统计不确定性

位置簇bootstrap结果：

| 比较 | 点估计 | 95%区间 | 单侧U95 |
|---|---:|---:|---:|
| P_FALF/P_A | 0.652928 | [0.102978, 3.449985] | 2.577189 |
| P_FALF/P_FA | 0.653040 | [0.097119, 3.374602] | 2.550766 |

区间很宽，不能据此声称已建立总体优效。leave-one-position-out比值范围为
0.25906到1.13272；移除position 15后比值为1.13272。这说明30位置development对低SNR
换峰重尾的统计稳定性不足。

## 6. 复杂度

独立完整计时：

- P_FALF：平均8.0974 s/user，中位7.7757 s/user；
- C_enhanced：平均20.5216 s/user，中位20.5484 s/user；
- 平均时间比：0.39458，即P_FALF约快60.5%。

该计时包含完整前端、冻结P_FA过程和联合距离profile，不包含只用于报告的Y-only诊断profile。

## 7. 正式结论

R53在全新90行数据上满足全部预声明开发Gate，证明在当前仿真条件独立模型下，固定P_FA角度后
对z与Y作无调权集中似然融合，存在恢复P_A级距离并取得正向点估计的可能。因此P_FALF冻结为
development candidate。

但收益由极少数低SNR换峰事件主导，bootstrap和leave-one-position-out均显示高不确定性。
本轮不能写成已建立距离优效，也不能自动进入600行calibration。下一步只能由新的、预授权的
独立calibration检验换峰收益是否稳定；不得修改权重、模型、支持或Gate。

