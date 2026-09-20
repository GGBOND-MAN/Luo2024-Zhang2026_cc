# R55：P_FALF 独立Final-1400预声明协议

日期：2026-09-18  
状态：**代码已建立；等待运行时间基准、锁包和手动授权；final trial=0**

## 1. 冻结方法

Primary为冻结P_FALF，最终角度逐行等于P_FA。最终比较方法包括P_FALF、P_FA、P_A、
G_schur和C_enhanced。

冻结摘要：

- R53：c1476d3b75078a841286bebf6e67812217dd689952b291b4a3213cd915018c5c；
- R54：77c571f9547be5b4b14d4ebbd4c58bb7f5ba8c1fb6311af95fb986ffab0472b2；
- P_FA：f1483ec49bb59907a9b5b2f70aa95459f11277450a0bbcf715a43b3324439868。

final逐行实现删除Y-only、重复q-profile和曲率诊断，只保留产生P_FA、P_FALF及对比基线所需的
计算。删除项不参与P_FALF输出，因此这是等价的精简执行，不是方法修改。

## 2. Final设计

- 200个全新位置；
- SNR为 -10、-5、0、5、10、15、20 dB；
- 共1400行；
- position seed：70000000；trial seed root：70100000；
- 每个位置在七个SNR复用，按位置聚类bootstrap；
- 禁止读取R46 final逐行结果作规则、阈值或模型选择。

## 3. Primary统计

P_FALF相对P_A距离终点同时要求：

1. 七个SNR的MSE比97.5% simultaneous上界全部小于1.02；
2. equal-SNR聚合MSE比的cluster-bootstrap单侧U95小于1.0；
3. P_FALF角度逐行严格等于P_FA；
4. 大于1 m失捕率不高于P_A；
5. 冻结P_A实现继续使用direct EVD，Gram和fallback均为0。

bootstrap为20000次，seed为70200000。聚合指标不能挽救任一逐SNR simultaneous失败。

## 4. 一次性规则

- final只允许一次；
- 不允许显著性提前停止；
- 不追加用户、不删除尾部、不换seed重跑；
- 失败结论永久保留；
- 必须先完成运行时间基准和preflight；
- 由于R54原始线性投影超过4小时，Codex不得自动运行；只能由用户手动授权和启动。

手动授权短语：

I_EXPLICITLY_AUTHORIZE_R55_PFALF_FINAL_1400_MANUAL_RUN

