# R54：P_FALF 独立Calibration-600协议

日期：2026-09-18  
状态：**协议、实现、设计与Gate已冻结；尚未读取R54性能结果**

## 1. 目标

R53在90行development中通过预声明Gate，但收益由6个低SNR换峰样本主导，位置簇bootstrap
不确定性很高。R54只回答一个问题：在完全冻结R53的前提下，该距离改善能否在新的600行中
同时满足点估计非劣和统计非劣。

## 2. 冻结身份

- R53 expected source digest：c1476d3b75078a841286bebf6e67812217dd689952b291b4a3213cd915018c5c；
- P_FA expected source digest：f1483ec49bb59907a9b5b2f70aa95459f11277450a0bbcf715a43b3324439868；
- 不修改R53公式、似然观测数、局部窗口、峰保留、容差、数值floor或角度输出；
- 不加入权重、selector、换峰安全规则、支持扩展或fallback；
- 不读取R46 final、既有calibration逐行结果、R51/R52结果作方法选择。

## 3. 新数据

- 200个全新位置，SNR为 -10/0/20 dB，共600行；
- position seed：69000000；trial seed root：69100000；
- positions 1至20为预声明diagnostic-60；
- positions 21至200为holdout-540；
- diagnostic不用于调参，all-600与holdout-540必须同时通过。

## 4. Primary Gate

对all-600和holdout-540分别要求：

1. P_FALF角度逐行等于P_FA，最大差不超过1e-12 deg；
2. equal-SNR距离MSE/P_A <=1.00；
3. 任一SNR距离MSE/P_A <=1.05；
4. 位置簇bootstrap单侧U95 <1.02；
5. 大于1 m失捕率不高于P_A。

全部Gate通过才有 calibrationReady=true。bootstrap次数为10000，seed为69200000，按位置聚类
并在三个SNR间共享抽样索引。

## 5. 报告与停止规则

必须报告P_A、P_FA、Y-only和P_FALF的逐SNR指标、配对W/T/L、bootstrap、换峰率、换峰与
非换峰平方误差贡献、曲率比和尾部失捕率。

若任一Gate失败，R54正式Calibration FAIL，停止P_FALF路线，不修改方法后重跑，不增加样本，
不进入final。若全部通过，也只冻结为calibration-ready candidate，final必须另行预授权和使用
全新设计。

