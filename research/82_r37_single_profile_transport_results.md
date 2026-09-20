# R37 单-profile 隐式迁移 Scheme E 结果

日期：2026-09-13  
协议：`research/81_r37_single_profile_transport_protocol.md`  
实现：`R37-schemeE-single-profile-implicit-transport-v1`  
证据属性：复用既有 calibration-600 的回顾性工程证据，不是 independent final validation  
结论：**all-600 与固定 holdout-540 全部门槛 PASS；单-profile 版本可替代当前双-profile Scheme E 作为下一阶段工程候选。**

## 1. 实验范围与身份

本轮没有重新运行 P_A、C_enhanced 或完整 Scheme E，也没有生成新用户。
输入仅为冻结的 R36 calibration-600 结果及同一批观测的确定性 replay：

- 既有用户：600，其中 -10/0/20 dB 各 200；
- 固定 development overlap：60；
- 固定 holdout：540，其中每个 SNR 各 180；
- 成功行：600/600；
- 新用户：0；
- R34 final 读取或执行：0；
- Scheme B/D 执行：0；
- 第二次完整 conditional profile：0；
- 冻结 Scheme E 角度与 R37 角度最大差：0 deg。

冻结输入：

- R36 result SHA-256：`f998fc2258210c13ef98345ea04b4637c7d93b762795fc575c8da92a200bb446`；
- R36 Scheme E digest：`27879e532e1ffefa1223a7a2ed56a6845ade09ed97e98f58ed56851436ba5908`；
- calibration data digest：`39538d66a6724e198d9c569c2f9e24b9185c4d3d979bc4f224724fbf5d50dcc0`；
- R37 algorithm digest：`29c0880f2fa15ae9c9c04108c137b044faa6891660a417d0ca1c1f9da834a7eb`。

## 2. 方法

原完整 Scheme E 的在线顺序为：

1. P_A angle search；
2. 在 `theta_A` 运行第一次冻结 `+/-2 m` range profile，得到 `r_P`；
3. 在 `(theta_A,r_P)` 做冻结的 range-orthogonal Schur angle one-step，得到 `theta_E`；
4. 在 `theta_E` 再运行一次完整 range profile，得到 `r_E`。

R37 保留步骤 1 至 3，但将步骤 4 替换为 profile 最优点的隐式迁移：

`delta_r = -(J_r + J_rtheta*delta_theta)/J_rr`。

这里 `J` 是完全相同的 exact q-only log profile statistic。导数在
`(theta_A,r_P)` 解析计算，theta 使用 radian，range 使用 meter。最终只在
`theta_E` 评价两个 range 候选：原 `r_P` 与隐式迁移点，保留得分更高者。
因此这不是新的联合二维搜索，也不是第二次 profile；它仍是“先冻结角度
更新，再条件更新距离”，但用局部最优流形传递代替全区间重搜。

## 3. 角度性能

R37 使用冻结的 `theta_E`，所以角度结果与完整 Scheme E 逐行完全相同。

### All 600

| SNR | P_A angle RMSE | E single-profile RMSE | RMSE 改善 | MSE ratio | win/tie/loss |
|---:|---:|---:|---:|---:|---:|
| -10 dB | 0.001366591 deg | 0.001305112 deg | 4.4987% | 0.912049 | 120/0/80 |
| 0 dB | 0.000436379 deg | 0.000397737 deg | 8.8551% | 0.830739 | 104/0/96 |
| 20 dB | 0.000092094 deg | 0.000041325 deg | 55.1272% | 0.201357 | 157/0/43 |
| equal-SNR | 0.000829956 deg | 0.000788082 deg | 5.0453% | 0.901640 | 381/0/219 |

Equal-SNR aggregate angle MSE 改善 `9.8360%`。

### Holdout 540

每个 SNR 的 angle MSE ratio 分别为
`0.907421 / 0.838713 / 0.204874`，equal-SNR ratio 为 `0.898649`；
aggregate angle RMSE 改善 `5.2029%`。全部继承冻结 Scheme E 的 PASS。

## 4. 距离与位置性能

### All 600

| SNR | P_A range RMSE | E single-profile range RMSE | range MSE ratio | position RMSE 变化 |
|---:|---:|---:|---:|---:|
| -10 dB | 0.223611865 m | 0.223604234 m | 0.999932 | -0.00347% |
| 0 dB | 0.014713131 m | 0.014710719 m | 0.999672 | -0.01930% |
| 20 dB | 0.001222014 m | 0.001219398 m | 0.995723 | -0.29341% |

Pooled range RMSE 从 `0.129383455 m` 变为 `0.129378960 m`
（`-0.00347%`）；pooled position RMSE 从 `0.129384349 m` 变为
`0.129379756 m`（`-0.00355%`）。因此单-profile 版本没有用距离性能交换
角度性能。

Holdout-540 的每-SNR range MSE ratio 为
`0.999939 / 0.999649 / 0.995748`，同样全部通过 1.02 门槛。

相对完整 Scheme E，单-profile range MSE ratio 为
`0.998488 / 1.000001 / 0.999983`。0 和 20 dB 实质等价；-10 dB 略优，
原因是完整第二 profile 的一个旁峰切换。

## 5. 隐式迁移诊断

- 有效负曲率：600/600；
- 选择迁移点：576/600；
- 保留 `r_P`：24/600；
- profile 边界裁剪：0；
- endpoint fallback：0；
- 平均绝对迁移：`3.3862e-5 m`；
- 最大绝对迁移：`4.4441e-4 m`；
- 相对完整第二 profile 的全体 P95 绝对差：`3.8370e-7 m`。

存在一个 -10 dB 离群差异 `0.129769 m`。该行真值距离约 `18.169 m`，
P_A 与单-profile 结果约 `18.176 m`，完整第二 profile 切换到约
`18.046 m`。因此这个离群点不是隐式迁移漏掉正确修正，而是局部连续
迁移避免了第二次全局 profile 的错误模态跳变。除该行外，完整 profile
与隐式迁移达到亚微米级一致性。

## 6. 复杂度

采用纠正后的 standalone 口径：完整 Scheme E 必须包含 P_A 的第一次
profile、Schur angle step 和第二次完整 profile。

| 方法 | runtime | response count | MUSIC/subspace count | EVD | profile passes | profile evaluations |
|:--|--:|--:|--:|--:|--:|--:|
| P_A | 24.383511 s/user | 2055.512 | 93 | 2047 | 1 | 142.997 |
| Scheme E full | 26.156332 s/user | 2198.532 | 95 | 2047 | 2 | 286.017 |
| E single-profile | 24.581465 s/user | 2058.512 | 95 | 2047 | 1 | 142.997 |

单-profile Scheme E 相对 P_A：

- runtime `+0.8118%`，即 `+0.1980 s/user`；
- response count `+0.1459%`，固定只增加 3 次；
- profile pass 与 profile evaluations 均保持 P_A 的一次/约 143 次。

相对完整 Scheme E：

- runtime 降低 `6.0210%`；
- response count 降低 `6.3688%`；
- 完整 profile 从 2 次降至 1 次；
- 第二 profile 的约 143 次评价被 3 次局部评价替代，减少 `97.90%`；
- range 刷新部分的计时从平均 `1.6834 s` 降至 `0.1086 s`，减少
  `93.55%`。

## 7. Gate 决定

All-600 和 holdout-540 均通过：

- 每-SNR angle MSE `<=1.01 x P_A`；
- equal-SNR angle MSE `<=0.98 x P_A`；
- 每-SNR range MSE `<=1.02 x P_A`；
- runtime `<= C_enhanced`；
- runtime `<=1.02 x P_A`；
- runtime 严格低于完整 Scheme E；
- angle identity 为 0 deg；
- 完整 profile 数严格为 1；
- final/new/B/D 执行数均为 0。

工程结论是 **PASS**。R37 支持将 Scheme E 的实现解释为：一次 P_A
conditional range profile，加一次 range-orthogonal angle correction，再沿
profile 最优流形做常数次局部 range transport。它不需要第二次完整
profile，也不改变角度性能。

## 8. 限制与停止规则

本轮方案是在观察 R36 复杂度和第二 profile 位移后设计，并复用了同一批
calibration-600 数据。因此它只能支持工程兼容性和复杂度结论，不能支持
independent final validation 或新的无偏泛化声明。

本轮按协议停止。不运行 R34 final，不追加参数，不扩大 range bracket，
不执行 Scheme B/D，也不把该 PASS 自动升级为论文最终验证。

## 9. 产物

结果目录：

`matlab/results/full_spectrum/round37_schemeE_single_profile_transport_v1/`

主要文件：

- `result.mat` SHA-256：`400443c8131c41a235233efd8d393e55bf3fc9097e138883f1cfb4e0299fe70d`；
- `per_user_outputs.csv` SHA-256：`d0b02583f74df5c9c692354820791f8d489108db8a25561feacb546317fc105c`；
- `engineering_gate.csv` SHA-256：`87fed93e3222c9e5c913e37f6738d362cb2e88a7a934615e1d86336348579758`；
- `engineering_decision.csv` SHA-256：`f5168997d7ef1157c722df510089d9c25dc8a91e0e9b47ce5def51f975836bed`；
- all-600、holdout-540、development-overlap-60 的方法、配对比较和迁移诊断 CSV；
- 4 张 angle/range/complexity/range-difference 图；
- checkpoint、算法源文件 hash 和冻结只读源文件 hash 清单。
