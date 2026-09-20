# R38 Scheme F 冻结 calibration-600 结果

日期：2026-09-13  
协议：`research/85_r38_schemeF_calibration600_protocol.md`  
实现：`R38-schemeF-raw-array-conditional-vpml-v1`  
证据属性：pre-final calibration evidence，不是 independent final validation  
决定：**all-600、固定 holdout-540 和 development overlap 复现全部 PASS；按协议停止。**

## 1. 执行身份

Scheme F 在通过 60-user development Gate 后保持完全冻结。本轮仅使用既有
calibration-600：

- 600 个既有用户，-10/0/20 dB 各 200；
- 固定 development overlap：60；
- 固定非开发 holdout：540，每个 SNR 各 180；
- 成功执行：600/600；
- 新用户：0；
- R34 final 读取或执行：0；
- P_A、C_enhanced、E full 和 E single-profile 重新估计：0；
- 仅 Scheme F 被执行。

冻结身份：

- Scheme F algorithm digest：`67bc633f6d58b2fc410bd47dbd304e915d40a8999b682bc3339ca5f03db1b38d`；
- development result SHA-256：`935e9bea7bad14fb66986871d6e344eb777b309b8d9b103da6ebfd4260053d89`；
- calibration data digest：`39538d66a6724e198d9c569c2f9e24b9185c4d3d979bc4f224724fbf5d50dcc0`；
- R36 calibration result SHA-256：`f998fc2258210c13ef98345ea04b4637c7d93b762795fc575c8da92a200bb446`；
- R37 E single-profile result SHA-256：`400443c8131c41a235233efd8d393e55bf3fc9097e138883f1cfb4e0299fe70d`。

60 个重叠用户的 angle、range、VPML score、function count 和 selected source
均与冻结 development 结果逐行完全相同，最大差值为 0。

## 2. 角度性能

### All 600

| SNR | P_A RMSE | E single-profile RMSE | F raw VPML RMSE | F/P_A MSE ratio | F 对 P_A RMSE 改善 |
|---:|---:|---:|---:|---:|---:|
| -10 dB | 0.001366591 deg | 0.001305112 deg | 0.001224413 deg | 0.802747 | 10.4038% |
| 0 dB | 0.000436379 deg | 0.000397737 deg | 0.000329167 deg | 0.568989 | 24.5686% |
| 20 dB | 0.000092094 deg | 0.000041325 deg | 0.000030797 deg | 0.111830 | 66.5590% |

Equal-SNR aggregate：

- F/P_A angle MSE ratio：`0.778371`；
- angle MSE 改善：`22.1629%`；
- angle RMSE 改善：`11.7747%`；
- F 对 P_A win/tie/loss：`449/0/151`。

相对 E single-profile：

- -10/0/20 dB angle MSE ratio：`0.880158 / 0.684919 / 0.555384`；
- equal-SNR angle MSE ratio：`0.863284`；
- angle MSE 改善：`13.6716%`；
- angle RMSE 改善：`7.0869%`；
- F 对 E single win/tie/loss：`316/129/155`。

### Fixed holdout 540

| SNR | F/P_A angle MSE ratio | F 对 P_A RMSE 改善 | F/E single angle MSE ratio |
|---:|---:|---:|---:|
| -10 dB | 0.800199 | 10.5461% | 0.881839 |
| 0 dB | 0.563975 | 24.9017% | 0.672429 |
| 20 dB | 0.115524 | 66.0112% | 0.563877 |
| equal-SNR | 0.776890 | 11.8586% | 0.864509 |

Holdout equal-SNR angle MSE 相对 P_A 改善 `22.3110%`，相对 E single
改善 `13.5491%`。数值与 all-600 一致且略强，因此校准 PASS 并非由 60 个
development overlap 单独驱动。

## 3. 距离与位置

Scheme F 的新角度逐行重新运行冻结 `+/-2 m` q-only range profile。

### All 600

| SNR | F/P_A range MSE ratio | F range RMSE | F position RMSE |
|---:|---:|---:|---:|
| -10 dB | 0.999972 | 0.223608752 m | 0.223609881 m |
| 0 dB | 0.999291 | 0.014707917 m | 0.014709226 m |
| 20 dB | 0.993805 | 0.001218223 m | 0.001218376 m |

Pooled 指标：

- P_A range RMSE：`0.129383455 m`；
- E single range RMSE：`0.129378960 m`；
- F range RMSE：`0.129381452 m`；
- F 相对 P_A range RMSE：`-0.00155%`；
- F 相对 E single range RMSE：`+0.00193%`。

Pooled position RMSE 为 P_A `0.129384349 m`、E single
`0.129379756 m`、F `0.129382153 m`。F 相对 P_A 变化 `-0.00170%`，
相对 E single 变化 `+0.00185%`。

### Holdout 540

F/P_A range MSE ratio 为
`0.999964 / 0.999208 / 0.994079`。Pooled F range RMSE 为
`0.134149056 m`，介于 P_A 的 `0.134151689 m` 和 E single 的
`0.134147481 m` 之间。

因此 Scheme F 的显著角度提升没有造成可测的距离或位置损失。更准确的
结论是距离/位置保持，而不是 F 在所有条件下都优于 E single。

## 4. VPML 与 bracket 诊断

### All 600

- optimizer converged：600/600；
- VPML score 增加：600/600；
- truth angle 改善：449/600；
- truth angle 变差：151/600；
- bracket endpoint selected：232/600；
- 平均函数评价：12.46 次/user；
- 平均绝对角度移动：`1.66947e-4 deg`；
- 最大角度移动：冻结边界 `2.66667e-4 deg`；
- score gain 与 truth squared-error gain 相关系数：`0.4214`。

Endpoint saturation：

- -10 dB：162/200，`81.0%`；
- 0 dB：70/200，`35.0%`；
- 20 dB：0/200。

Holdout-540 对应为 146/180、63/180 和 0/180，与 all-600 基本一致。
这确认低 SNR 下 objective 存在明显向 bracket 外增长的趋势，但协议禁止
扩大 bracket。当前结论只适用于冻结的局部搜索范围。

所有用户 likelihood 均提高，但约四分之一用户 truth error 变差。因此
raw-array VPML score 仍不是逐用户正确性证书，不支持后验 selector 或 gating。

## 5. 复杂度

All-600 corrected standalone 口径：

| 方法 | runtime | response-equivalent count | MUSIC count | EVD | complete profiles |
|:--|--:|--:|--:|--:|--:|
| P_A | 24.3835 s/user | 2055.51 | 93 | 2047 | 1 |
| E single-profile | 24.5815 s/user | 2058.51 | 95 | 2047 | 1 |
| E full | 26.1563 s/user | 2198.53 | 95 | 2047 | 2 |
| F raw VPML | 27.1478 s/user | 2210.94 | 93 | 2047 | 2 |
| C_enhanced | 51.2508 s/user | 1912.52 | 3083 | 2047 | n/a |

Scheme F：

- runtime 相对 P_A：`+11.3369%`；
- runtime 相对 E single-profile：`+10.4403%`；
- runtime 相对 E full：`+3.7907%`；
- runtime/C_enhanced：`0.529705`；
- response-equivalent count 相对 P_A：`+7.5617%`；
- response-equivalent count 相对 E single：`+7.4049%`；
- VPML 本身平均 `0.2480 s/user`；
- 第二次刷新 profile 平均 `2.5163 s/user`。

运行时间来自不同已冻结批话的 standalone 重构，微小差异可能包含并行负载
变化；profile pass 和 evaluation/response count 更稳定。无论按时间还是计数，
F 当前都明显高于 E single-profile，主要原因是第二次完整 range profile。

## 6. Calibration Gate

All-600 与 holdout-540 均通过：

- 每-SNR F/P_A angle MSE `<=1.01`；
- equal-SNR F/P_A angle MSE `<=0.98`；
- 每-SNR F/P_A range MSE `<=1.02`；
- F runtime/C_enhanced `<=1.00`；
- development overlap identity 全部精确复现。

因此 `calibrationReady=true`。这表示 Scheme F 是一个通过开发和校准工程
门槛的固定候选，不等于已经完成独立最终验证。

## 7. 工程判断

当前形成两个不同取向的候选：

1. **角度性能优先：Scheme F**。相对 P E single，calibration equal-SNR
   angle RMSE 再改善约 `7.09%`，holdout 约 `7.02%`。
2. **复杂度优先：E single-profile**。角度增益低于 F，但只需一次完整 range
   profile，runtime 比 F 低约 `9.45%`（等价于 F/E runtime ratio 1.1044）。

本轮尚不能判断 F 的角度增益有多少来自完整 N=256 孔径、有多少来自
variable-projection likelihood。本轮也未组合 F 与 R37 隐式 range transport。

若继续研究，优先级应为冻结机制消融：`N=256 raw VPML` 对比
`L=160 raw VPML` 和 `N=256 normalized uniform projection`。只有机制归因
清楚后，再单独建立 F single-profile 兼容性协议。不能从本结果直接把
R37 range transport 接到 F。

## 8. 停止规则

按协议在 calibration-600 决策后停止：

- 不运行 R34 final；
- 不扩大低 SNR bracket；
- 不修改 gain model、likelihood 或 optimizer；
- 不执行 F 与 E/R37 组合；
- 不以 calibration 结果调参。

## 9. 产物

结果目录：

`matlab/results/full_spectrum/round38_schemeF_raw_array_vpml_calibration600_v1/`

主要文件：

- `result.mat` SHA-256：`20df32a5b235f293e284745bfa6c9ca757dcad13012cb621d7ba17c2c33a5ad3`；
- `per_user_outputs.csv` SHA-256：`8dc5ea0e200caf180820e8f6fa3f16472ca8396faccb62c9fd87cca438ecd079`；
- `engineering_gate.csv` SHA-256：`a2ddac43a7055ffde82412e6dedb35903574d9dce98787f39549b0e39d6b1aad`；
- `calibration_decision.csv` SHA-256：`b5547cbbaad608b16fd98c10473c5f0366b07921735d93316c013bf7310c8149`；
- `development_reproduction.csv` SHA-256：`ea0e964e775c5d862af44feef3830351615391b2a286e323b8b14349ffeed5cd`；
- all-600、holdout-540 和 overlap-60 的方法、配对、F/E tradeoff 和 VPML
  diagnostics CSV；
- 5 张角度、距离、复杂度和 endpoint saturation 图；
- checkpoint、算法/报告源文件 hash 与冻结只读源文件 hash 清单。
