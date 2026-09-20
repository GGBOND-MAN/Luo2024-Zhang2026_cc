# R35 角度改进公共协议

日期：2026-09-12  
协议版本：`R35-angle-improvement-common-protocol-v1`  
状态：仅建立协议、目录和 identity 门禁；本轮不授权、不执行任何新估计实验

## 1. 研究分支与边界

本研究分支以 R34 冻结工程为唯一基线，在主工程的 `matlab/+r35/` 下隔离开发：

- `common/`：公共协议配置与冻结身份检查；
- `schemeA/`、`schemeB/`、`schemeD/`：三个候选方案的保留目录；
- R34、R33、R32 源码保持只读，不覆盖、不重写、不回填；
- `P_A` 和 `C_enhanced` 的实现、参数、输出定义与历史结果全部冻结。

R34 最终 1400 trial 是已经使用过的最终独立测试。它们绝对禁止用于 R35 的选参、方案开发、工程门槛判断、校准、淘汰、组合或参数放宽，也不得以事后误差诊断的形式影响候选设计。

## 2. 数据使用顺序

1. 开发阶段优先且仅使用已有 60 个 pre-final users，不生成新开发用户。
2. 每个方案必须先在这 60 个用户上独立通过全部工程门槛。
3. 只有单个方案通过工程门槛后，才允许该方案复用已有 pre-final calibration 数据。
4. calibration 最多使用已有 600 个用户，可以少于 600 个，但不得生成新用户或补充新 seed。
5. development 和 calibration 都只能称为开发/校准证据，不能称为 `independent final validation`。

不同方案不能通过共享失败后的调参、跨方案拼接、按 SNR 选择输出或观察 calibration 结果后放宽门槛取得资格。

## 3. 冻结系统、算法和基线

所有方案必须继承当前 `P_A` 系统与算法身份：

- 系统：`N=256`、`M=2048`、`K=2047`、`L=160`、`P=97`；
- 前端：当前冻结 `L06 front`；
- 响应：`q-only`；
- 子空间：直接协方差 EVD，`UseGram=false`；
- 角度搜索：当前角窗 `+/-0.2 deg`，三级网格 `41/31/21`；
- 距离：当前冻结的条件 range profile，以冻结 front range 为中心，物理范围内 `+/-2 m`；
- profile：`lambda=1`；
- `P_A` 与 `C_enhanced`：冻结参照，禁止修改、替换或针对 R35 结果重新解释其配置。

R34 冻结源码摘要为：

`2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`

R34 最终设计哈希为：

`e1f6cc945644e88806432a52d2b6e18d0df026024c279790c9bf26edb9792cd6`

公共 identity 检查必须在任何未来开发入口之前通过。源码摘要或上述身份发生漂移时，R35 入口必须拒绝执行。

## 4. 新角度后的距离重算

任何候选输出的新 angle 都必须重新运行冻结的 conditional range profile，再由该新 angle 和重算 range 计算 range/position 指标。禁止沿用 `P_A` 的旧 range、只替换 angle，或用旧 range 指标代表新 angle 的完整结果。

## 5. 统一输出合同

每个方案、`P_A` 和 `C_enhanced` 必须在相同用户及相同 SNR 上按统一格式输出：

- angle RMSE、MSE、绝对误差 median、绝对误差 P95；
- 相对 `P_A` 的逐用户配对 angle squared-error difference，定义为 `candidate - P_A`；
- angle win/tie/loss：差值 `<0`、`=0`、`>0`；
- 新 angle 经过冻结 profile 重算后的 range RMSE；
- 新 angle/range 对应的 position RMSE；
- 完整独立在线 runtime；
- response evaluation count 和 MUSIC evaluation count。

汇总必须逐 SNR 报告，并额外给出 equal-SNR aggregate。equal-SNR aggregate 对每个 SNR 的 angle MSE 使用相同权重，不得按观察到的样本难度、方差或结果重新加权。

## 6. 统一工程门槛

一个方案只有同时满足以下全部条件，才算通过 60-user 工程门槛：

1. 每个 SNR 的 angle MSE 均不超过 `1.01 * P_A angle MSE`；
2. equal-SNR aggregate angle MSE 不超过 `0.98 * P_A aggregate angle MSE`，即至少改善 2%；
3. 使用新 angle 重跑冻结 profile 后，每个 SNR 的 range MSE 均不超过 `1.02 * P_A range MSE`；
4. 完整独立在线 runtime 不超过冻结 `C_enhanced`。

门槛是预先冻结的工程判断，不是统计优效声明。失败后禁止后验放宽比值、删除不利 SNR、改变 aggregate 权重、换用部分 runtime、追加用户或改写 tie 定义。

## 7. 明确禁止项

R35 角度主线禁止引入或恢复：

- `alpha`；
- Gram 子空间路径或 `UseGram=true`；
- 少载波主线；
- H/P gating 或按 SNR/用户切换 H/P；
- ML weighting；
- 新用户或新 seed；
- R34 final 1400 trial 的任何开发复用；
- 观察结果后的参数、窗口、门槛或声明边界放宽。

## 8. 当前停止点

本轮只交付公共协议、`+r35/common|schemeA|schemeB|schemeD` 目录、公共配置检查和 identity test。不得创建候选估计器、运行 development/calibration、读取 R34 final 结果做方案判断或生成任何新性能表。
