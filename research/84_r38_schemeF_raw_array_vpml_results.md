# R38 Scheme F raw-array variable-projection ML 结果

日期：2026-09-13  
协议：`research/83_r38_schemeF_raw_array_vpml_protocol.md`  
实现：`R38-schemeF-raw-array-conditional-vpml-v1`  
证据属性：既有 60-user development evidence，不是 independent final validation  
决定：**PASS 60-user 公共工程 Gate；按协议停止，不读取 calibration-600。**

## 1. 执行身份

- 固定 development users：60，-10/0/20 dB 各 20；
- 成功：60/60；
- 新用户：0；
- calibration 用户读取或执行：0；
- R34 final 读取或执行：0；
- P_A/C_enhanced 重新估计：0，直接使用冻结配对输出；
- R32 至 R37 源码和既有结果未修改。

冻结输入：

- R36 development result SHA-256：`3533cf2a643b8297f90cbeac6ef4cda0d28235d7734251870a0fcb34eb264b22`；
- pilot hash：`869ae1c79e1989d9bdc8f5715e107fcdcf9bda14ecc1e02d9c0ca9887dbd82a4`；
- R38 algorithm digest：`67bc633f6d58b2fc410bd47dbd304e915d40a8999b682bc3339ca5f03db1b38d`。

## 2. 冻结方法

Scheme F 的执行顺序为：

1. 读取冻结 P_A 的 `theta_A` 和第一次 profile 距离 `r_P`；
2. 使用 P_A 完全相同的 K=2047 载波，但读取每载波完整 N=256 原始阵列
   快照 `y_m`；
3. 在 `(theta_A,r_P)` 周围最终实际 P_A 网格的左右相邻点 bracket 内，
   固定 `r_P`，做一次 bounded continuous raw-array VPML angle search；
4. 每载波独立复增益 `alpha_m` 解析消去，不执行增益参数搜索；
5. 保留左右网格点、P_A 网格点和收敛连续点，选择 likelihood score 最大者；
6. 用新角度重新运行完全冻结的 `+/-2 m`、`lambda=1` q-only range profile。

集中目标为：

`S(theta) = sum_m |a_m(theta,r_P)^H y_m|^2 / sum_m ||y_m||^2`。

它是等方差高斯噪声、每载波独立确定性复增益模型下的 variable-projection
conditional ML。由于每载波只有一个原始快照，该目标也严格等价于按
`||y_m||^2` 加权的 rank-one projection residual。这里的权重由原始似然
代数产生，不是学习或调节所得；结果不能描述成 uniform MUSIC。

## 3. 角度结果

| SNR | P_A RMSE | Scheme E RMSE | Scheme F RMSE | F/P_A MSE ratio | F 相对 P_A RMSE 改善 |
|---:|---:|---:|---:|---:|---:|
| -10 dB | 0.001059967 deg | 0.001051641 deg | 0.000972951 deg | 0.842554 | 8.2092% |
| 0 dB | 0.000469182 deg | 0.000411634 deg | 0.000365647 deg | 0.607352 | 22.0672% |
| 20 dB | 0.000091540 deg | 0.000037662 deg | 0.000025588 deg | 0.078139 | 72.0466% |

Equal-SNR aggregate：

- F/P_A angle MSE ratio：`0.799522`；
- angle MSE 改善：`20.0478%`；
- angle RMSE 改善：`10.5840%`；
- F 对 P_A win/tie/loss：`43/0/17`。

相对冻结 Scheme E reference：

- equal-SNR angle MSE ratio：`0.846630`；
- angle MSE 改善：`15.3370%`；
- angle RMSE 改善：`7.9875%`；
- F 对 E win/tie/loss：`30/14/16`。

因此 Scheme F 在这 60 个 development users 上不仅超过 P_A，也超过当前
Scheme E 的角度结果。但它不是逐用户支配，仍有 17/60 用户相对 P_A 变差，
16/60 用户相对 Scheme E 变差。

## 4. Likelihood 与 bracket 诊断

- optimizer converged：60/60；
- VPML score 正增益：60/60；
- truth angle 改善：43/60；
- bracket endpoint selected：23/60；
- 平均函数评价：12.3 次/user；
- 平均绝对角度移动：`1.6697e-4 deg`；
- 最大移动：冻结 bracket 边界 `2.6667e-4 deg`；
- score gain 与 truth squared-error gain 相关系数：`0.4065`。

边界压力集中在低信噪比：

- -10 dB：16/20 落在 bracket endpoint；
- 0 dB：7/20；
- 20 dB：0/20。

这说明 raw-array objective 在低 SNR 下经常仍沿 bracket 外方向增加。不过
协议禁止扩大 bracket；当前 PASS 只能针对被冻结局部范围内的 Scheme F。

所有用户的 likelihood score 都提高，但只有 43 个用户 truth error 提高，
所以 concentrated likelihood 不是单用户正确性证书，也不支持后验 gating。

## 5. 距离与位置

| SNR | F/P_A range MSE ratio | range RMSE 变化 | position RMSE 变化 |
|---:|---:|---:|---:|
| -10 dB | 1.000212 | +0.01060% | +0.01042% |
| 0 dB | 1.001014 | +0.05068% | +0.03889% |
| 20 dB | 0.991869 | -0.40739% | -0.46431% |

三个 SNR 均远低于 1.02 Gate。Pooled position RMSE 从 P_A 的
`0.0736944 m` 变为 Scheme F 的 `0.0737021 m`，变化约 `+0.0105%`。
结论是距离和位置基本保持，而不是全面改善。

## 6. 复杂度

| 方法 | standalone runtime | response-equivalent evaluations | MUSIC evaluations | EVD |
|:--|--:|--:|--:|--:|
| P_A | 18.13398 s/user | 2056.12 | 93 | 2047 |
| Scheme E full reference | 19.30068 s/user | 2200.63 | 95 | 2047 |
| Scheme F raw VPML | 19.97586 s/user | 2212.82 | 93 | 2047 |
| C_enhanced | 35.08912 s/user | 1911.80 | 3083 | 2047 |

Scheme F：

- runtime 相对 P_A：`+10.1571%`；
- runtime 相对完整 Scheme E：`+3.4982%`；
- runtime/C_enhanced：`0.569289`，通过 Gate；
- response-equivalent count 相对 P_A：`+7.6212%`；
- VPML 自身平均耗时：`0.15783 s/user`；
- 新角度后的第二次完整 profile：`1.68405 s/user`；
- 每用户平均执行约 `6.45e6` 个 full-array element-carrier steering products。

因此新增 raw-array VPML 本身不昂贵，主要增量仍来自第二次完整 range
profile。Scheme F 的角度性能优于 Scheme E，但复杂度不优于已经完成的
E single-profile。R38 没有组合 Scheme F 与 R37 的隐式 range transport。

## 7. Gate

| Gate | observed | limit | decision |
|:--|---:|---:|:--|
| -10 dB angle MSE ratio | 0.842554 | 1.01 | PASS |
| 0 dB angle MSE ratio | 0.607352 | 1.01 | PASS |
| 20 dB angle MSE ratio | 0.078139 | 1.01 | PASS |
| equal-SNR angle MSE ratio | 0.799522 | 0.98 | PASS |
| -10/0/20 dB range MSE ratio | 1.000212 / 1.001014 / 0.991869 | 1.02 | PASS |
| runtime/C_enhanced | 0.569289 | 1.00 | PASS |

Scheme F 通过全部预冻结 60-user 工程门槛。

## 8. 原理解释和限制

Scheme F 仍然是条件顺序估计，不是联合 angle-range ML：

`P_A theta/range -> fixed-r raw-array angle VPML -> refreshed range profile`。

其角度优势可能同时来自两部分：

1. 使用 N=256 完整阵列孔径，而 P_A 的 MUSIC 子空间使用 L=160 子阵；
2. 直接优化 raw-array likelihood，而不是先压缩为每载波子空间向量后再做
   uniform MUSIC 融合。

当前实验没有把这两个因素拆开，因此不能声称增益完全来自
variable-projection objective。进一步说，仿真快照由匹配的 Fresnel steering
model 生成，而 Scheme F 允许每载波独立未知复增益；相对仿真生成模型，
这是一个更宽松的 nuisance model，可称为 relaxed/conditional ML，不应夸大
为完整物理模型的全局 ML 最优性。

## 9. 决定和停止

Scheme F 是一个明确的角度性能 PASS 候选，并提供了比 Scheme E 更强的
60-user development angle evidence。但由于：

- 23/60 bracket endpoint saturation；
- 仍有 17/60 相对 P_A truth loss；
- 使用完整阵列孔径，改变了 P_A 的信息利用方式；
- 复杂度高于完整 Scheme E，更高于 E single-profile；
- 当前仅有 60-user development evidence；

本轮不能称为最终替代方案或 independent validation。按协议停止，不扩大
bracket，不组合 R37，不读取 calibration-600，不运行 R34 final。

## 10. 产物

结果目录：

`matlab/results/full_spectrum/round38_schemeF_raw_array_vpml_development_v1/`

主要文件：

- `result.mat` SHA-256：`935e9bea7bad14fb66986871d6e344eb777b309b8d9b103da6ebfd4260053d89`；
- `per_user_outputs.csv` SHA-256：`60675b64a643e5132ffd493ba865740c51d6b1ada0c47d3d501eb3f27be3c1f2`；
- `engineering_gate.csv` SHA-256：`e9bc986a9c15df07713d71da9f554065536b3fec1ec0877fc068ee715b2f1cdd`；
- `paired_comparisons.csv` SHA-256：`e240418bcbc4bfd2a7115a532ffcf2abbebf35ae22e5edc55a0e64577d0c3d02`；
- `vpml_diagnostics.csv` SHA-256：`7c6b56facb8b97bd01a10be343e95ac99406a87a007aa01134733a663103ef9c`；
- 5 张 angle、paired gain、score diagnostic、displacement 和 complexity 图；
- checkpoint、算法/报告源文件 hash 及冻结只读源文件 hash 清单。
