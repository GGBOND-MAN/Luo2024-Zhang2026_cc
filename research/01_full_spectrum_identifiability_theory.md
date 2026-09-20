# 单扫描完整频谱联合角距估计：理论推导 v0.1

## 1. 研究目标

Zhang2026 将全部宽带观测压缩为峰值子载波索引

\[
m^\star=\arg\max_m |z_m|^2,
\]

再用预设轨迹上的焦点 \((\tilde\theta_{m^\star},\tilde r_{m^\star})\) 作为二维粗估计。本研究保留单次宽带扫描，但不做该信息压缩，而是使用完整复数频谱

\[
\mathbf z=[z_0,\ldots,z_{M-1}]^T
\]

直接联合估计 \(\boldsymbol\eta=[\theta,r]^T\)。理论阶段需要回答四个问题：

1. 为什么单个峰值索引不能在二维区域内提供一致的粗定位保证？
2. 完整复频谱在什么条件下能够局部辨识角度和距离？
3. 如何消除未知复路径增益，而不把公共相位错误地计入距离信息？
4. 如何由信息矩阵构造自适应搜索区域，避免固定 \(\pm1^\circ/\pm1\,\mathrm m\) 窗口造成漏捕？

本文先处理单用户、LoS、已知波束和白噪声情形。多用户、多径、硬件误差和跨频增益模型作为后续扩展。

## 2. 物理观测模型

### 2.1 精确球面波阵列响应

设 ULA 第 \(n\) 个阵元坐标为 \(x_n\)，用户位置为 \(\boldsymbol\eta=[\theta,r]^T\)。阵元到用户的精确距离为

\[
\rho_n(\theta,r)
=\sqrt{r^2+x_n^2-2rx_n\sin\theta}.
\]

在第 \(m\) 个子载波 \(f_m\) 上，归一化阵列响应为

\[
[\mathbf a_m(\boldsymbol\eta)]_n
=\frac{1}{\sqrt N}\exp[-j k_m\rho_n(\boldsymbol\eta)],
\qquad k_m=\frac{2\pi f_m}{c}.
\]

TTD/PS 在第 \(m\) 个子载波形成已知焦点
\(\tilde{\boldsymbol\eta}_m=[\tilde\theta_m,\tilde r_m]^T\)，相应已知波束记为

\[
\mathbf b_m=\mathbf a_m(\tilde{\boldsymbol\eta}_m).
\]

与当前 MATLAB 复现的粗定位模型一致，定义标量复响应

\[
q_m(\boldsymbol\eta)
=\mathbf b_m^H\mathbf a_m(\boldsymbol\eta).
\]

若采用单站往返回波或不同模拟合并器，只需将 \(q_m\) 替换为相应的已知可微复响应；后面的集中似然和投影 EFIM 形式不变。

### 2.2 未知复增益

经过已知导频、接收机频响及已知载频权重校准后，采用

\[
z_m=\beta q_m(\boldsymbol\eta)+n_m,
\qquad n_m\sim\mathcal{CN}(0,\sigma^2),
\]

或向量形式

\[
\mathbf z=\beta\mathbf q(\boldsymbol\eta)+\mathbf n.
\]

其中 \(\beta\in\mathbb C\) 是未知的跨频公共复增益，吸收未知路径增益、目标反射系数和公共初相。

这一假设是可辨识性的必要建模边界：

- 若 \(\beta\) 在带内近似为一个公共复数，下面的完整频谱估计成立。
- 若增益属于已知的低维频率基 \(\beta(f)=\sum_{\ell=1}^L\gamma_\ell\psi_\ell(f)\)，可将一个 nuisance 方向推广为 \(L\) 维 nuisance 子空间。
- 若每个子载波都有任意独立的未知 \(\beta_m\)，则 \(\beta_m\) 可以吸收任意 \(q_m(\theta,r)\)，标量完整频谱也不可辨识。此时必须增加阵列观测、结构化信道先验或多次独立探测。

## 3. 峰值索引方法的不可辨识性

### 命题 1：有限峰值索引不能唯一表示连续二维位置

令感知区域 \(\Omega\subset\mathbb R^2\) 含有非空内部，峰值统计为

\[
T(\boldsymbol\eta)
=\arg\max_{m\in\{0,\ldots,M-1\}}|q_m(\boldsymbol\eta)|^2.
\]

则 \(T:\Omega\rightarrow\{0,\ldots,M-1\}\) 不可能是单射。

**证明。** \(\Omega\) 包含不可数个位置，而 \(T\) 的值域只有 \(M\) 个元素。根据抽屉原理，必然存在不同位置 \(\boldsymbol\eta_1\ne\boldsymbol\eta_2\) 满足
\(T(\boldsymbol\eta_1)=T(\boldsymbol\eta_2)\)。证毕。

这一结论并不依赖噪声、网格精度或 MUSIC 实现。

### 命题 2：平滑一维焦点轨迹不能覆盖二维矩形

Zhang2026 的粗估计输出被限制为

\[
\mathcal C
=\{\tilde{\boldsymbol\eta}(u):u\in[0,1]\},
\]

其中 \(u\) 是归一化子载波索引，\(\tilde{\boldsymbol\eta}(u)\) 由式 (19)-(20) 给出。该映射是分段光滑的一维曲线，因此 \(\mathcal C\) 在二维平面中的面积为零，不可能等于具有正面积的感知矩形 \(\Omega\)。

定义带尺度的覆盖误差

\[
\epsilon_{\mathrm{cov}}
=\sup_{\boldsymbol\eta\in\Omega}
\inf_{\mathbf c\in\mathcal C}
\left\|\mathbf W(\boldsymbol\eta-\mathbf c)\right\|_2,
\]

其中 \(\mathbf W=\operatorname{diag}(1/s_\theta,1/s_r)\) 用于统一角度和距离量纲。对于非退化二维区域，\(\epsilon_{\mathrm{cov}}>0\)。

因此，固定局部窗口能够无漏捕地工作，至少需要证明

\[
\forall\boldsymbol\eta\in\Omega:\quad
|\theta-\tilde\theta_{T(\boldsymbol\eta)}|\le\Delta\theta,
\quad
|r-\tilde r_{T(\boldsymbol\eta)}|\le\Delta r.
\]

轨迹单调性只保证“一个子载波对应一个轨迹点”，不能推出上述二维覆盖条件。

### 高 SNR 结论

当 SNR \(\rightarrow\infty\) 时，峰值索引估计仍然只能输出 \(\mathcal C\) 上的点。对不在轨迹上的用户，其误差包含确定性模型偏差，不会随噪声消失。后续局部 MUSIC 若使用固定窗口，则存在门限型失败：一旦真实位置位于窗口外，增加 SNR 也无法恢复。

## 4. 完整复频谱的集中最大似然估计

在给定候选位置 \(\boldsymbol\eta\) 时，未知复增益的最小二乘/最大似然估计为

\[
\hat\beta(\boldsymbol\eta)
=\frac{\mathbf q(\boldsymbol\eta)^H\mathbf z}
{\mathbf q(\boldsymbol\eta)^H\mathbf q(\boldsymbol\eta)}.
\]

代回似然函数，位置估计可写为

\[
\hat{\boldsymbol\eta}_{\mathrm{FS}}
=\arg\min_{\boldsymbol\eta\in\Omega}
\mathbf z^H\mathbf\Pi_{\mathbf q(\boldsymbol\eta)}^\perp\mathbf z,
\]

其中

\[
\mathbf\Pi_{\mathbf q}^\perp
=\mathbf I-\frac{\mathbf q\mathbf q^H}{\mathbf q^H\mathbf q}.
\]

等价的最大化形式为

\[
\hat{\boldsymbol\eta}_{\mathrm{FS}}
=\arg\max_{\boldsymbol\eta\in\Omega}
\frac{|\mathbf q(\boldsymbol\eta)^H\mathbf z|^2}
{\mathbf q(\boldsymbol\eta)^H\mathbf q(\boldsymbol\eta)}.
\]

该目标保留了所有子载波之间的幅度形状和相对相位，而峰值方法只保留一个离散索引。它是后续实验中的主要 proposed estimator，也可作为 MUSIC 的信息保持型粗估计器。

## 5. 精确导数

精确球面距离的导数为

\[
\frac{\partial\rho_n}{\partial\theta}
=-\frac{rx_n\cos\theta}{\rho_n},
\qquad
\frac{\partial\rho_n}{\partial r}
=\frac{r-x_n\sin\theta}{\rho_n}.
\]

因此

\[
\frac{\partial\mathbf a_m}{\partial\eta_i}
=-jk_m
\left(\frac{\partial\boldsymbol\rho}{\partial\eta_i}
\odot\mathbf a_m\right),
\]

以及

\[
\frac{\partial q_m}{\partial\eta_i}
=\mathbf b_m^H
\frac{\partial\mathbf a_m}{\partial\eta_i}.
\]

记

\[
\mathbf Q(\boldsymbol\eta)
=\left[
\frac{\partial\mathbf q}{\partial\theta},
\frac{\partial\mathbf q}{\partial r}
\right]\in\mathbb C^{M\times2}.
\]

### Fresnel 导数的符号核对

若

\[
\rho_n\approx r-x_n\sin\theta
+\frac{x_n^2\cos^2\theta}{2r},
\]

则

\[
\frac{\partial\rho_n}{\partial\theta}
=-x_n\cos\theta-\frac{x_n^2\sin(2\theta)}{2r},
\]

从而对相位 \(\Phi_n=-k\rho_n\)，正确结果是

\[
\frac{\partial\Phi_n}{\partial\theta}
=k\left[x_n\cos\theta
+\frac{x_n^2\sin(2\theta)}{2r}\right].
\]

Zhang2026 附录式 (62) 将二次项写成负号；按其式 (58) 直接求导时应为正号。这会进一步影响其角距 FIM 的交叉项和 CRLB。

## 6. 未知复增益下的 EFIM

完整实参数向量为

\[
\boldsymbol\xi
=[\theta,r,\operatorname{Re}\beta,\operatorname{Im}\beta]^T.
\]

对复高斯均值模型 \(\boldsymbol\mu=\beta\mathbf q(\boldsymbol\eta)\)，消去 \(\beta\) 后，角距参数的等效 Fisher 信息矩阵为

\[
\boxed{
\mathbf J_{\mathrm e}(\boldsymbol\eta)
=\frac{2|\beta|^2}{\sigma^2}
\operatorname{Re}
\left\{
\mathbf Q^H
\mathbf\Pi_{\mathbf q}^\perp
\mathbf Q
\right\}.
}
\]

具体地，复均值对四个实参数的导数矩阵为

\[
\mathbf G
=\left[
\beta\mathbf Q,\;\mathbf q,\;j\mathbf q
\right],
\]

完整实参数 FIM 为

\[
\mathbf J_{\boldsymbol\xi}
=\frac{2}{\sigma^2}\operatorname{Re}\{\mathbf G^H\mathbf G\}.
\]

对最后两个复增益参数组成的 nuisance block 做 Schur 补，等价于从 \(\beta\mathbf Q\) 中删除复子空间
\(\operatorname{span}_{\mathbb C}\{\mathbf q\}\) 上的分量，因此得到上述
\(\mathbf\Pi_{\mathbf q}^{\perp}\) 投影形式。

对应的无偏估计协方差下界为

\[
\operatorname{Cov}(\hat{\boldsymbol\eta})
\succeq\mathbf J_{\mathrm e}^{-1}.
\]

投影矩阵删除了与 \(\mathbf q\) 共线的变化，因为这部分变化可以由未知复增益 \(\beta\) 吸收。没有该投影，就会把不可区分的公共复幅度/相位变化错误计入定位信息。

该 EFIM 必须基于实际使用的标量全频谱观测 \(\mathbf z\) 计算，不能直接拿阵列级 \(N\) 维快拍模型的 CRLB 与之比较。

## 7. 完整频谱的一阶正则局部可辨识条件

### 定理 1

在公共未知复增益模型下，位置 \(\boldsymbol\eta_0\) 一阶正则局部可辨识，当且仅当

\[
\operatorname{rank}_{\mathbb R}
\left(
\mathbf\Pi_{\mathbf q}^\perp
\mathbf Q
\right)=2,
\]

等价地，

\[
\det\mathbf J_{\mathrm e}(\boldsymbol\eta_0)>0.
\]

这里的实秩表示两个实参数方向不存在非零实组合
\(\mathbf Q\mathbf h\) 落入 \(\operatorname{span}_{\mathbb C}\{\mathbf q\}\)。

**解释。** 未知 \(\beta\) 使 \(\mathbf q\) 与任意非零复数倍 \(c\mathbf q\) 观测等价。投影后的两个导数分别描述角度和距离在排除该等价方向后的可观测变化。若两者实线性独立，则角度和距离在一阶局部近似中产生两个独立的频谱变化方向；若行列式为零，则至少存在一个角距组合在一阶上只能改变未知复增益。该条件不排除高阶导数在奇异点仍提供辨识信息，也不证明全局唯一性。

### 可辨识性指标

由于角度和距离具有不同量纲，直接对
\([\theta\ ({\rm rad}),r\ ({\rm m})]\) 的 FIM 求特征值或条件数会依赖单位选择。
定义无量纲局部坐标

\[
\delta\boldsymbol\eta
=\mathbf S\delta\mathbf u,
\qquad
\mathbf S=\operatorname{diag}(s_\theta,s_r),
\]

其中实验取 \(s_\theta=1^\circ=\pi/180\ {\rm rad}\)、
\(s_r=1\ {\rm m}\)。相应尺度归一化 EFIM 为

\[
\mathbf J_{\mathbf u}=\mathbf S^T\mathbf J_{\mathrm e}\mathbf S.
\]

后续实验对 \(\mathbf J_{\mathbf u}\) 采用三个互补指标：

\[
I_{\det}=\det\mathbf J_{\mathbf u},
\qquad
I_{\min}=\lambda_{\min}(\mathbf J_{\mathbf u}),
\qquad
\kappa=\frac{\lambda_{\max}(\mathbf J_{\mathbf u})}
{\lambda_{\min}(\mathbf J_{\mathbf u})}.
\]

- \(I_{\det}=0\)：局部不可辨识。
- \(I_{\min}\) 很小：存在一个弱可观测角距方向。
- \(\kappa\) 很大：归一化参数方向的信息强度不均衡，不必然意味着角距强耦合。
  耦合需另看交叉项除以两个对角项几何平均的归一化指标。

## 8. 从固定窗口改为信息驱动窗口

在正则条件和中高 SNR 下，完整频谱估计近似满足

\[
\hat{\boldsymbol\eta}_{\mathrm{FS}}
\overset{a}{\sim}
\mathcal N(\boldsymbol\eta,\mathbf J_{\mathrm e}^{-1}).
\]

因此可构造置信椭圆

\[
\mathcal E_{1-\alpha}
=\left\{
\boldsymbol\eta:
(\boldsymbol\eta-\hat{\boldsymbol\eta}_{\mathrm{FS}})^T
\hat{\mathbf J}_{\mathrm e}
(\boldsymbol\eta-\hat{\boldsymbol\eta}_{\mathrm{FS}})
\le\chi^2_{2,1-\alpha}
\right\}.
\]

后续 MUSIC 只需在该椭圆或其最小外接矩形中搜索。与固定窗口相比：

- 高信息区域自动缩小搜索范围；
- 低 SNR、远距离或强耦合区域自动扩大范围；
- 多峰时保留完整频谱目标函数的 top-\(L\) 个局部极值，并为每个候选建立独立椭圆，避免单一错误粗点造成不可恢复的漏捕。

低 SNR 下渐近椭圆可能欠覆盖，因此实验必须同时报告实际 capture probability，而不能只报告最终 RMSE。

## 9. 可证伪的理论预测

以下命题必须由下一阶段实验逐项检验，任何一项不成立都需要修改理论或适用边界。

### H1：峰值压缩存在高 SNR 误差地板

在整个二维感知矩形均匀取点时，峰值轨迹估计的最坏误差和区域平均误差在无噪声下仍非零；完整频谱估计在局部可辨识区域中不应出现同类轨迹投影误差地板。

### H2：EFIM 退化能够预测困难位置

\(\lambda_{\min}(\mathbf J_{\mathrm e})\) 较小或 \(\kappa\) 较大的位置，应对应更高的 Monte Carlo RMSE、更长的误差椭圆主轴和更高的优化失败率。

### H3：信息驱动窗口改善捕获概率

在相同平均搜索网格数下，EFIM/Hessian 椭圆加 top-\(L\) 候选的真实位置捕获率应高于固定 \(\pm1^\circ/\pm1\,\mathrm m\) 窗口，尤其是在轨迹外位置和低 SNR 区域。

### H4：正确 EFIM 与完整频谱 ML 的高 SNR 误差一致

在模型匹配、细网格或连续优化且估计近似无偏时，完整频谱 ML 的经验协方差应趋近 \(\mathbf J_{\mathrm e}^{-1}\)。若出现明显低于下界的 RMSE，必须检查偏差、先验/窗口约束、SNR 定义和 nuisance 参数是否一致。

### H5：完整复频谱优于功率谱和峰值索引

在相同单次扫描、发射能量和标量复采样数下，三者形成确定性数据处理链

\[
\mathbf z\longrightarrow |\mathbf z|^2
\longrightarrow\arg\max_m |z_m|^2.
\]

因此在模型正确并使用各自最优估计器时，信息含量预期满足

\[
\text{完整复频谱}
\;\succeq\;
\text{完整功率谱}
\;\succeq\;
\text{单峰索引},
\]

但第一项依赖载波间相位同步。实际数值优化器可能因多峰或初始化失败而不遵循该性能排序；加入载波相位噪声后也必须重新评估该优势。

## 10. 下一阶段实验边界

下一阶段先做最小实验闭环，不立即加入 MUSIC、多用户或深度学习：

1. 无噪声二维覆盖图：比较轨迹峰值估计与完整频谱集中似然。
2. 全区域 EFIM 图：绘制 \(\lambda_{\min}\)、\(\det\) 和条件数。
3. 单用户 Monte Carlo：验证 H1、H2、H4、H5。
4. 捕获率实验：比较固定窗口与信息驱动窗口，验证 H3。
5. 上述四项通过后，再把完整频谱估计接入 geometry-compensated local MUSIC。

公平比较时统一记录：OFDM 符号数、模拟合并次数、复采样数、总发射能量、RF 链数、反馈量、网格评估次数和处理时延。

## 11. 当前结论

目前可严格成立的主张是：

1. 单次无噪声峰值索引无法与连续二维位置建立一一对应；这不等于带噪重复观测的类别概率模型必然统计不可辨识。
2. 一维光滑焦点轨迹不能覆盖二维感知矩形。
3. 完整复频谱在投影导数实秩为 2 时具有一阶正则局部可辨识性。
4. 未知公共复增益必须通过投影或 Schur 补从 FIM 中消除。
5. Zhang2026 的 Fresnel 角度相位导数二次项存在符号问题。

尚未验证的部分包括完整频谱估计的全局唯一性、低 SNR 门限、多峰优化稳定性、跨频增益模型适用性以及相位同步要求。这些问题留给下一阶段数值实验和后续理论扩展。
