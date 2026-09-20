# R54：P_FALF 独立Calibration-600结果

日期：2026-09-18  
协议：R54-PFALF-calibration600-v1  
状态：**all-600与holdout-540全部通过；calibrationReady=true；未进入final**

## 1. 实验身份

- 200个全新位置乘 -10/0/20 dB，共600行；
- diagnostic-60为positions 1至20，holdout-540为positions 21至200；
- 600/600行成功，0失败；
- R54 source digest：77c571f9547be5b4b14d4ebbd4c58bb7f5ba8c1fb6311af95fb986ffab0472b2；
- frozen R53 digest：c1476d3b75078a841286bebf6e67812217dd689952b291b4a3213cd915018c5c；
- frozen P_FA digest：f1483ec49bb59907a9b5b2f70aa95459f11277450a0bbcf715a43b3324439868；
- design hash：70ef66dc1acbffb339ae66cced397fe67bfb969960d63d87f2ea4b11574e4944；
- 未读取final、既有calibration逐行结果或R51/R52结果；未执行参数调整；
- 完成时间：2026-09-18 17:36:49，8个thread workers。

## 2. 正式Gate

| Population | Gate | 结果 | 门槛 | 判定 |
|---|---|---:|---:|---|
| all-600 | 角度最大恒等差 | 0 deg | <=1e-12 | PASS |
| all-600 | 聚合距离MSE/P_A | 0.610136 | <=1.00 | PASS |
| all-600 | 最大逐SNR距离比 | 0.914457 | <=1.05 | PASS |
| all-600 | cluster单侧U95 | 0.834588 | <1.02 | PASS |
| all-600 | 大于1 m失捕率差 | -0.001667 | <=0 | PASS |
| holdout-540 | 角度最大恒等差 | 0 deg | <=1e-12 | PASS |
| holdout-540 | 聚合距离MSE/P_A | 0.596329 | <=1.00 | PASS |
| holdout-540 | 最大逐SNR距离比 | 0.921283 | <=1.05 | PASS |
| holdout-540 | cluster单侧U95 | 0.870943 | <1.02 | PASS |
| holdout-540 | 大于1 m失捕率差 | -0.001852 | <=0 | PASS |

all-600与holdout-540同时通过，正式结论为 calibrationReady=true。

## 3. 距离性能

### All-600

| SNR | P_FA/P_A | P_FALF/P_A | P_FALF/P_FA | 相对P_A RMSE差 |
|---:|---:|---:|---:|---:|
| -10 dB | 1.000338 | 0.607809 | 0.607603 | -33.987 mm |
| 0 dB | 0.999996 | 0.914457 | 0.914461 | -0.588 mm |
| 20 dB | 1.001091 | 0.902197 | 0.901214 | -0.055 mm |
| equal-SNR | 1.000336 | 0.610136 | 0.609932 | -19.564 mm |

P_FALF/P_A逐行W/T/L为337/1/262。P_FA仍复现“角度明显改善、距离近似不变”的既有结论，
而P_FALF在不改变P_FA角度的情况下改善三个SNR的距离点估计。

### Holdout-540

| SNR | P_FALF/P_A | 相对P_A RMSE差 |
|---:|---:|---:|
| -10 dB | 0.593431 | -33.539 mm |
| 0 dB | 0.921283 | -0.552 mm |
| 20 dB | 0.905201 | -0.055 mm |
| equal-SNR | 0.596329 | -19.291 mm |

holdout结果与all-600一致，没有只在diagnostic-60出现的选择性收益。

## 4. Bootstrap与重尾稳健性

| Population | 点估计 | 95%区间 | 单侧U95 |
|---|---:|---:|---:|
| all-600 | 0.610136 | [0.375908, 0.858699] | 0.834588 |
| holdout-540 | 0.596329 | [0.343617, 0.891664] | 0.870943 |
| diagnostic-60 | 0.668272 | [0.110387, 0.945186] | 0.905156 |

leave-one-position-out的MSE比范围为0.576298至0.772623，中位数0.610081；200次删一位置中
没有一次超过1。R53 development中单个有利位置可改变结论的问题，在R54中没有复现。

P_A和P_FA各有1个大于1 m失捕，P_FALF为0。该行为position 186、-10 dB：P_A误差约
-1.010 m，P_FALF误差约+0.0966 m。

## 5. Y-only消融

Y-only/P_A聚合距离MSE比为6.53830；逐SNR为5.91286、88.32541和83.27726。Y-only仍然不是
可用距离估计器。P_FALF的收益来自z主导条件下的Y残余证据，而不是用Y替换q距离profile。

## 6. 正式结论

R54在冻结R53实现、全新600行和独立holdout-540上同时建立：

1. P_FA角度逐行完全保持；
2. P_FALF相对P_A距离MSE具有正向点估计；
3. 2% margin下的位置簇bootstrap非劣通过；
4. 三个SNR均无工程性退化；
5. 尾部失捕率没有增加；
6. development中观察到的距离改善得到独立复现。

因此P_FALF冻结为 calibration-ready candidate。按照协议，本轮不能自动运行final；最终确认必须
使用新的七SNR设计、新seed、冻结统计规则和单独授权。

