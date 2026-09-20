# R47：P_FA 角度边缘化距离 Profile 新开发协议

日期：2026-09-17  
版本：`R47-PFA-angle-marginal-profile-pilot60-v1`  
证据角色：R46之后的全新开发，不是最终证据

## 方法

保持 P_FA 的 L06 前端和 N256 全孔径角度不变。通过原始阵列集中残差的局部曲率估计
`sigma_theta^2 = E0/(K(N-1)E_theta_theta)`，随后使用三点和五点 Gauss-Hermite 将 q 的
未知噪声集中似然

`ell_z(theta,r)=-(M-1)log ||z-beta_hat q(theta,r)||^2`

对角度后验边缘化。候选为 `P_FAM3/P_FAM5`，均不执行 P_A、MUSIC 或 EVD。

## 新数据

- 20个全新位置，`-10/0/20 dB`，共60行；
- position seed `62000000`，trial seed root `62100000`；
- 禁止读取 R34/R41/R46 final estimate rows；
- 同观测比较 P_FA、P_FAM3、P_FAM5、P_A、G_schur、C_enhanced。

## 选择规则

在P_FAM3/P_FAM5中，先最小化相对P_A的最大逐SNR距离MSE比，再比较equal-SNR比。入选候选
必须满足最大逐SNR比不超过1.05、聚合比不超过1.00、角度与P_FA完全相同、60行零失败。
失败则停止，不进入600行校准；不能使用R46调整节点、权重或门槛。

